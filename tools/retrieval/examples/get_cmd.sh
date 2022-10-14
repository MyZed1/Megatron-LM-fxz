#!/bin/bash

set -u

# echo "SLURM_TASKS_PER_NODE = $SLURM_TASKS_PER_NODE"
# NPROCS=$SLURM_TASKS_PER_NODE
# >>>
NPROCS=1
# NPROCS=2
# NPROCS=4
# NPROCS=8
# NPROCS=16
# NPROCS=128
# >>>

PYTHONPATH=$PYTHONPATH:${SHARE_SOURCE}/megatrons/megatron-lm-retrieval-preprocess

# Data blend.
# . /gpfs/fs1/projects/gpu_adlr/datasets/boxinw/pretrained_data/gpt3_blend.sh
. /gpfs/fs1/projects/gpu_adlr/datasets/lmcafee/retrieval/preprocess/gpt3_blend.sh

# >>>>>>>>>>>>>>>>>>>>>>>
# PROFILE_STAGE_STOP="preprocess"
# PROFILE_STAGE_STOP="cluster"

# TASKS="chunks-preprocess"
# TASKS="embed-chunks"
# TASKS="index-train"
# TASKS="index-add"
# TASKS="index-build"
# TASKS="index-remove-train-outputs,train"
# TASKS="index-remove-add-outputs,add"
# TASKS="index-remove-add-outputs"
# TASKS="index-remove-add-outputs,verify" # "verify-index"
# TASKS="index-verify-codes"
# TASKS="index-verify-nbrs"
TASKS="nn-build"
# TASKS="nn-plot-acc"
# TASKS="misc-time-hnsw"
# TASKS="misc-time-query"
# TASKS="misc-time-merge-partials"
# TASKS="misc-copy-corpus-dirty"
# TASKS="misc-nan-stats"
# TASKS="misc-bert-nan-analysis"

# NTRAIN=2048 NCLUSTER=64 HNSW_M=4
# NTRAIN=131072 NCLUSTER=128 HNSW_M=32
# NTRAIN=5000000 NCLUSTER=100000 HNSW_M=32
# NTRAIN=15000000 NCLUSTER=500000 HNSW_M=32
# NTRAIN=20000000 NCLUSTER=4194304 HNSW_M=32
# NTRAIN=50000000 NADD=200000000 NCLUSTER=4194304 HNSW_M=32
# NTRAIN=300000000 NCLUSTER=4194304 HNSW_M=32
# NTRAIN=50000 NADD=20000000 NCLUSTER=16384 HNSW_M=32
# NTRAIN=50000 NADD=8000000 NCLUSTER=16384 HNSW_M=32
# NTRAIN=2500000 NADD=20000000 NCLUSTER=262144 HNSW_M=32
# NTRAIN=2500000 NADD=100000000 NCLUSTER=262144 HNSW_M=32
# NTRAIN=2500000 NADD=20000000 NCLUSTER=262144 HNSW_M=32
# NTRAIN=2500000 NADD=$(($NPROCS*1000000)) NCLUSTER=262144 HNSW_M=32
# NTRAIN=2500000 NADD=4000000 NCLUSTER=262144 HNSW_M=32
# NTRAIN=500000 NADD=10000000 NCLUSTER=262144 HNSW_M=32
# NTRAIN=10000000 NADD=20000000 NCLUSTER=1048576 HNSW_M=32
# NTRAIN=3000000 NADD=100000000 NCLUSTER=1048576 HNSW_M=32
# NTRAIN=3000000 NADD=$(($NPROCS*1000000)) NCLUSTER=1048576 HNSW_M=32
# NTRAIN=100000000 NADD=$(($NPROCS*1000000)) NCLUSTER=4194304 HNSW_M=32
# NTRAIN=100000000 NADD=$((1*$NPROCS*1000000)) NCLUSTER=4194304 HNSW_M=32

# NCLUSTER=4194304
NCLUSTER=32768 # for 169320 training samples
HNSW_M=32
PQ_M=32
IVF_DIM=256

INDEX_TY=faiss-base
# INDEX_TY=faiss-par-add
# INDEX_TY=faiss-decomp

DATA_PATH=${DATA_BLEND}
VOCAB_FILE=/gpfs/fs1/projects/gpu_adlr/datasets/nlp/gpt3/bpe/gpt2-vocab.json
MERGE_FILE=/gpfs/fs1/projects/gpu_adlr/datasets/nlp/gpt3/bpe/gpt2-merges.txt
TOKENIZER_TYPE=GPT2BPETokenizer

RETRO_WORKDIR=/gpfs/fs1/projects/gpu_adlr/datasets/lmcafee/retrieval/workdirs/1

RETRO_SEQ_LENGTH=2048
RETRO_CHUNK_LENGTH=64
# RETRO_NCHUNKS_SAMPLED=300000000
RETRO_NCHUNKS_SAMPLED=3000000
SEED=1001
RETRO_BLOCK_SIZE=100000 # 10000, *100000, 1000000
# NEIGHBOR_PATH=/gpfs/fs1/projects/gpu_adlr/datasets/lmcafee/retrieval/preprocess/neighbors.hdf5
# OFFSET_DICT_PATH=/gpfs/fs1/projects/gpu_adlr/datasets/lmcafee/retrieval/preprocess/offset_dict.pkl

# if [[ "$TASKS" == *"embed-chunks"* ]]; then
# if [[ "0" == "0" ]]; then

#     # BERT_LOAD_PATH=/home/universal-lm-data-netapp/chkpts/bert/345m_cased
#     BERT_LOAD_PATH=/home/universal-lm-data-netapp/chkpts/bert/345M_no_rng
#     # DATA_PATH=/gpfs/fs1/projects/gpu_adlr/datasets/nlp/roberta_mmap/bc_rn_owt_sto_wiki_dedup_shuf_cleaned_0.7_mmap
#     VOCAB_FILE=/gpfs/fs1/projects/gpu_adlr/datasets/nlp/roberta_mmap/vocab.txt
#     # TOKENIZER_TYPE=BertWordPieceCase
#     TOKENIZER_TYPE=BertWordPieceLowerCase

#     # NUM_WORKERS=1

#     # MICRO_BATCH_SIZE=1024 # oom
#     MICRO_BATCH_SIZE=512
#     # MICRO_BATCH_SIZE=16 # good

#     # --save ${BERT_LOAD_PATH} \
#     # --merge-file ${MERGE_FILE} \
#     # --num-workers ${NUM_WORKERS} \
#     # --micro-batch-size 2 \
#     # --global-batch-size 16 \
#     # --use-checkpoint-args \
#     MEGATRON_ARGS=" \
#         --seed ${SEED} \
#         --tokenizer-type ${TOKENIZER_TYPE} \
#         --tensor-model-parallel-size 1 \
#         --pipeline-model-parallel-size 1 \
#         --num-layers 24 \
#         --hidden-size 1024 \
#         --num-attention-heads 16 \
#         --micro-batch-size ${MICRO_BATCH_SIZE} \
#         --seq-length 512 \
#         --max-position-embeddings 512 \
#         --train-iters 1000000 \
#         --load ${BERT_LOAD_PATH} \
#         --data-path ${DATA_PATH} \
#         --vocab-file ${VOCAB_FILE} \
#         --data-impl mmap \
#         --split 949,50,1 \
#         --distributed-backend nccl \
#         --lr 0.0001 \
#         --lr-decay-style linear \
#         --min-lr 1.0e-5 \
#         --lr-decay-iters 990000 \
#         --weight-decay 1e-2 \
#         --clip-grad 1.0 \
#         --lr-warmup-fraction .01 \
#         --log-interval 100 \
#         --save-interval 10000 \
#         --eval-interval 1000 \
#         --eval-iters 10 \
#         --fp16 \
#         "

# else

#     #     --save $FINETUNED_PATH \
#     #     --load $CHECKPOINT_PATH \
#     #     --log-validation-ppl-to-tensorboard \
#     #     --tensorboard-dir ${TENSORBOARD_DIR} \
#     #     --eval-iters 25600 \
#     MEGATRON_ARGS=" \
#         --seed ${SEED} \
#         --tokenizer-type ${TOKENIZER_TYPE} \
#         --num-layers 24 \
#         --hidden-size 1024 \
#         --num-attention-heads 16 \
#         --micro-batch-size 1 \
#         --global-batch-size 1 \
#         --seq-length 2048 \
#         --max-position-embeddings 2048 \
#         --train-samples 192000000 \
#         --lr-decay-samples 166400000 \
#         --lr-warmup-samples 162761 \
#         --data-path ${DATA_PATH} \
#         --vocab-file ${VOCAB_FILE} \
#         --merge-file ${MERGE_FILE} \
#         --data-impl mmap \
#         --split 98,2,0 \
#         --distributed-backend nccl \
#         --lr-warmup-samples 162761 \
#         --lr-decay-style cosine \
#         --lr 3.0e-4 \
#         --min-lr 3.0e-5 \
#         --clip-grad 1.0 \
#         --weight-decay 0.1 \
#         --adam-beta1 0.9 \
#         --adam-beta2 0.95 \
#         --init-method-std 0.02 \
#         --log-params-norm \
#         --log-num-zeros-in-grad \
#         --checkpoint-activations \
#         --log-interval 100 \
#         --eval-iters 50 \
#         --eval-interval 2000 \
#         --save-interval 10000 \
#         --fp16 \
#         --DDP-impl local \
#         --finetune \
#         --no-load-optim \
#     "

# fi

BERT_LOAD_PATH=/home/universal-lm-data-netapp/chkpts/bert/345M_no_rng
VOCAB_FILE=/gpfs/fs1/projects/gpu_adlr/datasets/nlp/roberta_mmap/vocab.txt
TOKENIZER_TYPE=BertWordPieceLowerCase

# MICRO_BATCH_SIZE=1024 # oom
MICRO_BATCH_SIZE=512
# MICRO_BATCH_SIZE=16 # good

#     --train-iters 1000000 \
#     --split 949,50,1 \
#     --lr-decay-iters 990000 \
#     --lr-warmup-fraction .01 \
MEGATRON_ARGS=" \
    --seed ${SEED} \
    --tokenizer-type ${TOKENIZER_TYPE} \
    --tensor-model-parallel-size 1 \
    --pipeline-model-parallel-size 1 \
    --num-layers 24 \
    --hidden-size 1024 \
    --num-attention-heads 16 \
    --micro-batch-size ${MICRO_BATCH_SIZE} \
    --seq-length 512 \
    --max-position-embeddings 512 \
    --train-samples 192000000 \
    --load ${BERT_LOAD_PATH} \
    --data-path ${DATA_PATH} \
    --vocab-file ${VOCAB_FILE} \
    --data-impl mmap \
    --split 98,2,0 \
    --distributed-backend nccl \
    --lr 0.0001 \
    --lr-decay-style linear \
    --min-lr 1.0e-5 \
    --lr-decay-samples 166400000 \
    --lr-warmup-samples 162761 \
    --weight-decay 1e-2 \
    --clip-grad 1.0 \
    --log-interval 100 \
    --save-interval 10000 \
    --eval-interval 1000 \
    --eval-iters 10 \
    --fp16 \
"

#     --bert-load-path ${bert_load_path} \
#     --data-ty ${data_ty} \
#     --data-dir ${data_dir} \
#     --profile-stage-stop ${PROFILE_STAGE_STOP} \
#     --add-offset-doc-ids \
#     --offset-dict-path ${OFFSET_DICT_PATH} \
#     --index-dir ${INDEX_DIR} \
#     --retro-max-embed-chunk-len ${RETRO_MAX_EMBED_CHUNK_LEN} \
#     --embed-start-index ${EMBED_START_INDEX} \
#     --embed-end-index ${EMBED_END_INDEX} \
#     --ntrain ${NTRAIN} \
#     --nadd ${NADD} \
#     --return-doc-ids \
#     --neighbors-path ${NEIGHBOR_PATH} \
#     --weight 0 \
RETRO_ARGS=" \
    --tasks ${TASKS} \
    --ncluster ${NCLUSTER} \
    --ivf-dim ${IVF_DIM} \
    --hnsw-m ${HNSW_M} \
    --pq-m ${PQ_M} \
    --index-ty ${INDEX_TY} \

    --retro-workdir ${RETRO_WORKDIR} \
    --retro-seq-length ${RETRO_SEQ_LENGTH} \
    --retro-chunk-length ${RETRO_CHUNK_LENGTH} \
    --retro-nchunks-sampled ${RETRO_NCHUNKS_SAMPLED} \
    --retro-block-size ${RETRO_BLOCK_SIZE} \
"

RETRO_PREPROCESS_CMD=" \
    python -m torch.distributed.launch \
    --nproc_per_node ${NPROCS} \
    --nnodes 1 \
    --node_rank ${NODE_RANK} \
    --master_addr ${MASTER_ADDR} \
    --master_port 6000 \
    ./tools/retrieval/main.py \
    ${MEGATRON_ARGS} \
    ${RETRO_ARGS} \
"

# eof
