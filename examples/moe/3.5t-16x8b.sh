#!/bin/bash

##SBATCH -p batch_block1 -A llmservice_nlp_fm -t 4:00:00 --nodes=16 --exclusive --mem=0 --overcommit --ntasks-per-node=8 --gres=gpu:8 --dependency=singleton --job-name=llmservice_nlp_fm:3.5t-16x8b --array=1-30%1
#SBATCH -p batch -A llmservice_nlp_fm -t 4:00:00 --nodes=16 --exclusive --mem=0 --overcommit --ntasks-per-node=8 --dependency=singleton --job-name=llmservice_nlp_fm-yh:3.5t-16x8b --array=1-30%1

export ADLR_SHARING=/lustre/fsw/portfolios/adlr/projects/adlr_nlp_arch/adlr_nlp_sharing

export OUTPUT=/home/yihuih/llmservice/moe

export SQSH=/lustre/fsw/portfolios/adlr/users/rprenger/sqsh

export NCCL_IB_TIMEOUT=19
export NCCL_IB_SL=1
export CUDA_DEVICE_MAX_CONNECTIONS=1
export WANDB_API_KEY=b1d8825af2c256485e86683005098aaea7a6157b

NAME="3.5t-16x8b"

DIR=/home/yihuih/llmservice/moe-mlm
DATETIME=`date +'date_%y-%m-%d_time_%H-%M-%S'`

CHECKPOINT_DIR="${OUTPUT}/${NAME}"

LOG_DIR="${OUTPUT}/${NAME}/logs"
mkdir -p ${LOG_DIR}
TENSORBOARD_DIR="${OUTPUT}/${NAME}/tensorboard"
mkdir -p ${TENSORBOARD_DIR}

DATA_CACHE="${OUTPUT}/data_cache-3.5t"
mkdir -p ${DATA_CACHE}

# Get the data blend
. /home/yihuih/llmservice/data/nvllm-3.5t-eng-v0.2-mul-a1.3-code-a1.3-wdata-nojsp-blend-v0.701515.sh

options=" \
    --global-batch-size 1024 \
    --transformer-impl transformer_engine \
    --use-mcore-models \
    --moe-grouped-gemm \
    --num-experts 16 \
    --moe-z-loss-coeff 1e-3 \
    --moe-aux-loss-coeff 1e-2 \
    --use-distributed-optimizer \
    --apply-layernorm-1p \
    --use-flash-attn \
    --untie-embeddings-and-output-weights \
    --disable-bias-linear \
    --no-position-embedding \
    --use-rotary-position-embeddings \
    --rotary-percent 0.5 \
    --squared-relu \
    --attention-dropout 0.0 \
    --hidden-dropout 0.0 \
    --exit-duration-in-mins 230 \
    --tensor-model-parallel-size 4 \
    --pipeline-model-parallel-size 8 \
    --sequence-parallel \
    --num-layers 32 \
    --hidden-size 4096 \
    --num-attention-heads 32 \
    --seq-length 4096 \
    --max-position-embeddings 4096 \
    --micro-batch-size 1 \
    --train-samples 854492188 \
    --lr-decay-samples 811767576 \
    --lr-warmup-samples 122071 \
    --lr 3.0e-4 \
    --min-lr 3.0e-5 \
    --lr-decay-style cosine \
    --log-interval 1 \
    --eval-iters 32 \
    --eval-interval 1000 \
    --tokenizer-type GPTSentencePieceTokenizer \
    --tokenizer-model /home/yihuih/llmservice/data/mt_nlg_plus_multilingual_ja_zh_the_stack_frac_015_256k.model \
    --data-path ${DATA_BLEND} \
    --data-cache-path ${DATA_CACHE} \
    --save-interval 500000 \
    --save ${OUTPUT}/${NAME} \
    --load ${CHECKPOINT_DIR} \
    --split 99,1,0 \
    --clip-grad 1.0 \
    --weight-decay 0.1 \
    --adam-beta1 0.9 \
    --adam-beta2 0.95 \
    --init-method-std 0.010 \
    --log-params-norm \
    --log-num-zeros-in-grad \
    --log-throughput \
    --bf16 \
    --tensorboard-dir ${TENSORBOARD_DIR} \
    --wandb-project upcycling \
    --wandb-exp-name $NAME
"

run_cmd="
cd $DIR && python -u pretrain_gpt.py ${options}"


# --jobid=451511 -N1 --gpus-per-node=8
srun -l \
     --container-image /home/yihuih/llmservice/images/24.01.sqsh \
     --container-mounts "/lustre:/lustre/,/home:/home" \
      bash -c "${run_cmd}"

set +x
