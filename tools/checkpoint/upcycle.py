import torch
import argparse
import glob
import os
import re
import megatron
from einops import rearrange, reduce, repeat
import shutil

def get_layer_num(local_num, partition, PP):
    """
    Takes the local layer number from state_dict key
    (which always starts with 0 for each partition)
    And the partition number to get layer number)
    """
    m = re.match('.*\/mp_rank_(\d\d)$', partition)
    if m:
        # No Pipeline Parallel
        return local_num
        
    m = re.match('.*\/mp_rank_(\d\d)_(\d\d\d)$', partition)
    if m:
        return 1000*int(m.group(2))+local_num

def get_TP_PP(partitions):
    """
    Looks at names of model partitions and determines
    How much Tensor Parallelism (TP) and Pipline Parallelism (PP)
    there is
    """
    TP_ranks = set()
    PP_ranks = set()
    for partition in partitions:
        m = re.match('.*\/mp_rank_(\d\d)$', partition)
        if m:
            TP_ranks.add(int(m.group(1)))
            PP_ranks.add(0)
            continue
            
        m = re.match('.*\/mp_rank_(\d\d)_(\d\d\d)$', partition)
        if m:
            TP_ranks.add(int(m.group(1)))
            PP_ranks.add(int(m.group(2)))
            continue

    # A bunch checks to make sure partitions number like we expect
    assert(len(TP_ranks)*len(PP_ranks) == len(partitions))
    assert(min(list(TP_ranks)) == 0)
    assert(max(list(TP_ranks)) == len(TP_ranks)-1)
    if len(PP_ranks) > 0:
        assert(min(list(PP_ranks)) == 0)
        assert(max(list(PP_ranks)) == len(PP_ranks)-1)
    
    return len(TP_ranks), len(PP_ranks)

#NO ROUTER BIAS AND HAS "EXTRA_STATE"
if __name__ == '__main__':
    parser = argparse.ArgumentParser(
    prog='convert_to_switch',
    description='Converts a checkpoint to Switch style MoE')

    parser.add_argument('--input_dir', type=str, required=True)
    parser.add_argument('--output_dir', type=str, required=True)
    parser.add_argument('--num_experts', type=int, required=True)
    parser.add_argument('--input_expert_format', type=str, default='none', choices=['none', 'local', 'grouped_gemm', 'scattermoe'])
    parser.add_argument('--transformer_impl', type=str, default='local', choices=['local', 'grouped_gemm', 'scattermoe'])
    parser.add_argument('--router_std', type=float, default=0)
    parser.add_argument('--expert_std', type=float, default=0)
    parser.add_argument('--expert_uniform', type=float, default=0)
    parser.add_argument('--scale_st_w1', type=float, default=1.)
    parser.add_argument('--scale_st', type=float, default=1.)
    parser.add_argument('--granularity', type=int, default=1)

    args = parser.parse_args()

    latest_checkpointed_iteration_file = os.path.join(args.input_dir, 'latest_checkpointed_iteration.txt')
    assert os.path.exists(latest_checkpointed_iteration_file)
    with open(latest_checkpointed_iteration_file) as f:
        latest_checkpointed_iteration = f.read().strip()

    os.makedirs(args.output_dir, exist_ok=True)
    shutil.copy(latest_checkpointed_iteration_file, os.path.join(args.output_dir, 'latest_checkpointed_iteration.txt'))

    partitions = [name for name in glob.glob(args.input_dir + f'/iter_{latest_checkpointed_iteration}/mp_rank_*')]
    print("Found "+str(len(partitions))+" partitions")
    TP, PP = get_TP_PP(partitions)
    print("Tensor Parallel= "+str(TP))
    print("Pipeline Parallel= "+str(PP))

    if args.input_expert_format != 'none':
        assert args.input_expert_format == 'grouped_gemm'
        assert args.transformer_impl == 'scattermoe'

        print('converting', args.input_expert_format, '->', args.transformer_impl)

        for partition in partitions:
            print("Converting partition "+partition)
            partition_path = partition+'/model_optim_rng.pt'
            state_dict = torch.load(partition_path)
            for k, v in state_dict['model'].items():
                if 'experts' in k:
                    if 'weight1' in k:
                        h, ef = v.shape
                        f = ef // args.num_experts
                        state_dict['model'][k] = rearrange(v.view(args.num_experts, h, f), 'e h f -> e f h').contiguous()
                        print(k, h, ef, '->', state_dict['model'][k].shape)
                        
                    else:
                        ef, h = v.shape
                        f = ef // args.num_experts
                        state_dict['model'][k] = rearrange(v.view(args.num_experts, f, h), 'e f h -> e h f').contiguous()
                        print(k, ef, h, '->', state_dict['model'][k].shape)
            path = partition_path.replace(args.input_dir, args.output_dir)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            torch.save(state_dict, path)
        exit()
                    

    # Make routers to share weight values across partitions
    routers = {}
    
    for partition in partitions:
        print("Converting partition "+partition)
        state_dict = torch.load(partition+'/model_optim_rng.pt')
        router_key_values = []
        new_key_values = []
        old_keys = []

        for k, v in state_dict['model'].items():
            # Turn layer_norm_weight into pre_mlp_layernorm
            m = re.match('^decoder\.layers\.(\d+)\.mlp\.linear_fc1\.layer_norm_weight', k)
            if m:
                new_key = 'decoder.layers.'+m.group(1)+'.pre_mlp_layernorm.weight'
                new_key_values.append((new_key, v.detach().clone()))
                old_keys.append(k)
                continue
            
            # Turn layer_norm_bias into pre_mlp_layernorm bias
            m = re.match('^decoder\.layers\.(\d+)\.mlp\.linear_fc1\.layer_norm_bias', k)
            if m:
                new_key = 'decoder.layers.'+m.group(1)+'.pre_mlp_layernorm.bias'
                new_key_values.append((new_key, v.detach().clone()))
                old_keys.append(k)
                continue

            # Turn linear_fc1.weight into local_experts.?.linear_fc1.weight
            m = re.match('^decoder\.layers\.(\d+)\.mlp\.linear_fc1.weight', k)
            if m:
                new_key = 'decoder.layers.'+m.group(1)+'.mlp.router.weight'
                # Create a router for each fc1
                layer_num = get_layer_num(int(m.group(1)), partition, PP)
                if not (layer_num in routers):
                    print('creating new router', new_key, 'layer', layer_num)
                    router = torch.nn.Linear(v.size(1), args.num_experts)
                    # low init value helps upcycling
                    if args.router_std > 0:
                        torch.nn.init.normal_(router.weight, mean=0.0, std=args.router_std)
                    # same router weights across virtual groups
                    if args.granularity > 1:
                        router = repeat(router.weight[:args.num_experts // args.granularity], 'e h -> (e g) h', g=args.granularity)
                    else:
                        router = router.weight
                    routers[layer_num] = router
                else:
                    print('using existing router', layer_num)
                    router = routers[layer_num]
                    
                router_weight = router.to(v)

                
                router_key_values.append((new_key, router_weight))
                
                if args.transformer_impl == 'local':
                    for i in range(args.num_experts):
                        #new_key = 'decoder.layers.'+m.group(1)+'.mlp.local_experts.'+str(i)+'.linear_fc1.weight'  #works for TE
                        new_key = 'decoder.layers.'+m.group(1)+'.mlp.experts.local_experts.'+str(i)+'.linear_fc1.weight'  #works with local
                        if args.expert_uniform != 0:
                            t = v.detach().clone()
                            t += args.expert_uniform * (torch.rand(t) * 2 - 1)
                            new_key_values.append((new_key, args.scale_st_w1 * t))
                        elif args.expert_std != 0:
                            t = v.detach().clone()
                            t += args.expert_std * torch.randn_like(t)
                            new_key_values.append((new_key, args.scale_st_w1 * t))
                        else:
                            new_key_values.append((new_key, args.scale_st_w1 * v.detach().clone()))
                else:
                    new_key = 'decoder.layers.'+m.group(1)+'.mlp.experts.weight1'
                    if args.transformer_impl == 'scattermoe':
                        w1 = v.detach().clone()
                        print(w1.shape)
                        w1 = repeat(w1, 'f h -> e f h', e=args.num_experts // args.granularity)
                        w1 = rearrange(w1, 'e (f g) h -> (e g) f h', g=args.granularity).contiguous()
                        print(w1.shape)
                        new_key_values.append((new_key, args.scale_st_w1 * w1))
                    else:
                        w1 = v.detach().clone().t()
                        # print('w1 shape', w1.shape) #torch.Size([6144, 3072])
                        w1 = repeat(w1, 'h f -> e h f', e=args.num_experts // args.granularity)
                        w1 = rearrange(w1, 'e h (f g) -> (e g) h f', g=args.granularity).contiguous()
                        new_key_values.append((new_key, args.scale_st_w1 * w1.reshape(v.shape[1], -1).contiguous()))
                old_keys.append(k)
                continue
            
            # Turn linear_fc2.weight into local_experts.?.linear_fc2.weight
            m = re.match('^decoder\.layers\.(\d+)\.mlp\.linear_fc2.weight', k)
            if m:
                if args.transformer_impl == 'local':
                    for i in range(args.num_experts):
                        #new_key = 'decoder.layers.'+m.group(1)+'.mlp.local_experts.'+str(i)+'.linear_fc2.weight'  #works for TE
                        new_key = 'decoder.layers.'+m.group(1)+'.mlp.experts.local_experts.'+str(i)+'.linear_fc2.weight'  #works with local
                        if args.expert_uniform != 0:
                            t = v.detach().clone()
                            t += args.expert_uniform * (torch.rand(t) * 2 - 1)
                            new_key_values.append((new_key, t))
                        elif args.expert_std != 0:
                            t = v.detach().clone()
                            t += args.expert_std * torch.randn_like(t)
                            new_key_values.append((new_key, t))
                        else:
                            new_key_values.append((new_key, v.detach().clone()))
                else:
                    new_key = 'decoder.layers.'+m.group(1)+'.mlp.experts.weight2' 
                    if args.transformer_impl == 'scattermoe':
                        w2 =  args.scale_st * v.detach().clone()
                        print(w2.shape)
                        w2 = repeat(w2, 'h f -> e h f', e=args.num_experts // args.granularity)
                        w2 = rearrange(w2, 'e h (f g) -> (e g) h f', g=args.granularity).contiguous()
                        print(w2.shape)
                        new_key_values.append((new_key, w2))
                    else:
                        w2 =  args.scale_st * v.detach().clone().t()
                        # print('w2 shape', w2.shape) # torch.Size([3072, 6144])
                        w2 = repeat(w2, 'f h -> e f h', e=args.num_experts // args.granularity)
                        w2 = rearrange(w2, 'e (f g) h -> (e g) f h', g=args.granularity).contiguous()
                        new_key_values.append((new_key, w2.reshape(-1, v.shape[0]).contiguous()))

                old_keys.append(k)
                continue
        
            # Remove the "_extra_state"
            m = re.match('^decoder\.layers\.(\d+)\.mlp\.linear_fc\d._extra_state', k)
            if m:
                old_keys.append(k)
                continue
        for new_key, value in new_key_values:
            # print('adding '+new_key)
            state_dict['model'][new_key] = value
        for new_key, value in router_key_values:
            # print('adding '+new_key)
            state_dict['model'][new_key] = value
        for old_key in old_keys:
            # print('removing '+old_key)
            del state_dict['model'][old_key]
        
        m = re.match('.*\/(mp_rank_.*)$', partition)
        if m:
            path = args.output_dir+f'/iter_{latest_checkpointed_iteration}/'+m.group(1)
            os.makedirs(path, exist_ok=True)
            torch.save(state_dict, path+'/model_optim_rng.pt')
        else:
            assert(False)  # Names of partitions are not expected