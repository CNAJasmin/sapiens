cd ../../../..

###--------------------------------------------------------------
## set gpu ids to use.
DEVICES=0,
# DEVICES=0,1,2,3,4,5,6,7,

RUN_FILE='./tools/dist_train.sh'
PORT=$(( ((RANDOM<<15)|RANDOM) % 63001 + 2000 ))

##--------------------------------------------------------
####-----------------MODEL_CARD----------------------------
DATASET='cihp'
MODEL="sapiens_0.6b_${DATASET}-1024x768"

JOB_NAME="$MODEL"

## Default train batch size per GPU (used for multi-gpu by default)
TRAIN_BATCH_SIZE_PER_GPU=2

## Debug-specific knobs: you can bump these without touching multi-gpu setup
DEBUG_TRAIN_BATCH_SIZE_PER_GPU=1        # larger batch size in debug
DEBUG_NUM_WORKERS=10                     # more dataloader workers in debug

## resume_from: to resume a checkpoint from. Starts from the last epoch.
## load_from: to load a checkpoint from. not resume. Starts from epoch 0, just loads the weights.
RESUME_FROM=''
LOAD_FROM=''

##-------------------train mode-----------------------------------
## debug mode is 1 gpu and allows to insert ipdb.set_trace.
## multi-gpu mode is N gpus. Parallel dataloaders turned on.

mode='debug'
# mode='multi-gpu'

###--------------------------------------------------------------
CONFIG_FILE=configs/sapiens_seg/${DATASET}/${MODEL}.py
OUTPUT_DIR="Outputs/train/${DATASET}/${MODEL}/node" ## output directory for training
OUTPUT_DIR="$(echo "${OUTPUT_DIR}/$(date +"%m-%d-%Y_%H:%M:%S")")"

###--------------------------------------------------------------
## Base OPTIONS used in multi-gpu mode; debug will override this below.
if [ -n "$LOAD_FROM" ]; then
    OPTIONS="train_dataloader.batch_size=${TRAIN_BATCH_SIZE_PER_GPU} load_from=${LOAD_FROM}"
else
    OPTIONS="train_dataloader.batch_size=${TRAIN_BATCH_SIZE_PER_GPU}"
fi

if [ -n "$RESUME_FROM" ]; then
    CMD_RESUME="--resume ${RESUME_FROM}"
else
    CMD_RESUME=""
fi

export TF_CPP_MIN_LOG_LEVEL=2

##--------------------------------------------------------------
if [ "$mode" = "debug" ]; then
    ## Debug mode: single GPU, but allow larger batch size and parallel dataloaders.
    ## ipdb will still work in the main training process, but not inside dataloader workers.

    TRAIN_BATCH_SIZE_PER_GPU=${DEBUG_TRAIN_BATCH_SIZE_PER_GPU}

    ## Build OPTIONS specifically for debug mode.
    ## Note: we set num_workers > 0 for faster loading and persistent_workers=True to reuse workers.
    OPTIONS="train_dataloader.batch_size=${TRAIN_BATCH_SIZE_PER_GPU} \
train_dataloader.num_workers=${DEBUG_NUM_WORKERS} \
train_dataloader.persistent_workers=True"

    ## If you also want LOAD_FROM honored in debug, append it here.
    if [ -n "$LOAD_FROM" ]; then
        OPTIONS="${OPTIONS} load_from=${LOAD_FROM}"
    fi

    CUDA_VISIBLE_DEVICES=${DEVICES} \
        python tools/train.py ${CONFIG_FILE} \
        --work-dir ${OUTPUT_DIR} \
        --cfg-options ${OPTIONS}

elif [ "$mode" = "multi-gpu" ]; then
    ## Multi-gpu mode: keep original behavior and use the base OPTIONS above.

    NUM_GPUS_STRING_LEN=${#DEVICES}
    NUM_GPUS=$((NUM_GPUS_STRING_LEN/2))

    LOG_FILE="$(echo "${OUTPUT_DIR}/log.txt")"
    mkdir -p ${OUTPUT_DIR}; touch ${LOG_FILE}

    CUDA_VISIBLE_DEVICES=${DEVICES} PORT=${PORT} ${RUN_FILE} ${CONFIG_FILE} \
            ${NUM_GPUS} \
            --work-dir ${OUTPUT_DIR} \
            --cfg-options ${OPTIONS} \
            ${CMD_RESUME} \
            | tee ${LOG_FILE}

fi
