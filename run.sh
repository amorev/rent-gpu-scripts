#!/usr/bin/env bash
set -Eeuo pipefail

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker_cmd() {
    docker "$@"
  }
else
  docker_cmd() {
    sudo docker "$@"
  }
fi

IMAGE_TAG="${IMAGE_TAG:-llama-server:local}"
ROOT_DIR="${ROOT_DIR:-$HOME/llama-runtime}"

MODEL_FILE="${MODEL_FILE:-Qwen3.6-27B-Q4_K_M.gguf}"
MODEL_ALIAS="${MODEL_ALIAS:-${MODEL_FILE%.gguf}}"
MODEL_DIR_NAME="${MODEL_DIR_NAME:-${MODEL_FILE%.gguf}}"
MODEL_DIR="${MODEL_DIR:-${ROOT_DIR}/models/${MODEL_DIR_NAME}}"
MODEL_PATH="${MODEL_PATH:-/models/${MODEL_FILE}}"
LLAMA_CACHE_DIR="${LLAMA_CACHE_DIR:-${ROOT_DIR}/llama-cache}"

CONTAINER_NAME="${CONTAINER_NAME:-llama-server}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
GPU_VISIBLE_DEVICES="${GPU_VISIBLE_DEVICES:-all}"

CTX_SIZE="${CTX_SIZE:-100000}"
PARALLEL="${PARALLEL:-1}"
BATCH_SIZE="${BATCH_SIZE:-2048}"
UBATCH_SIZE="${UBATCH_SIZE:-512}"
THREADS="${THREADS:-12}"
THREADS_BATCH="${THREADS_BATCH:-$THREADS}"
N_GPU_LAYERS="${N_GPU_LAYERS:-999}"
SPLIT_MODE="${SPLIT_MODE:-none}"
MAIN_GPU="${MAIN_GPU:-0}"
TENSOR_SPLIT="${TENSOR_SPLIT:-}"
FLASH_ATTN="${FLASH_ATTN:-on}"
USE_MLOCK="${USE_MLOCK:-1}"
ENABLE_METRICS="${ENABLE_METRICS:-1}"
ENABLE_JINJA="${ENABLE_JINJA:-1}"
POLL="${POLL:-1}"
POLL_BATCH="${POLL_BATCH:-1}"
PRIO="${PRIO:-2}"
PRIO_BATCH="${PRIO_BATCH:-2}"
API_KEY="${API_KEY:-}"

if [[ ! -f "${MODEL_DIR}/${MODEL_FILE}" ]]; then
  echo "Model file not found: ${MODEL_DIR}/${MODEL_FILE}" >&2
  exit 1
fi

mkdir -p "${LLAMA_CACHE_DIR}"

if [[ "${GPU_VISIBLE_DEVICES}" == "all" ]]; then
  GPU_ARGS=(--gpus all)
else
  GPU_ARGS=(--gpus "device=${GPU_VISIBLE_DEVICES}")
fi

LLAMA_ARGS=(
  --host "${HOST}"
  --port "${PORT}"
  --model "${MODEL_PATH}"
  --alias "${MODEL_ALIAS}"
  --ctx-size "${CTX_SIZE}"
  --parallel "${PARALLEL}"
  --batch-size "${BATCH_SIZE}"
  --ubatch-size "${UBATCH_SIZE}"
  --threads "${THREADS}"
  --threads-batch "${THREADS_BATCH}"
  --split-mode "${SPLIT_MODE}"
  --main-gpu "${MAIN_GPU}"
  --n-gpu-layers "${N_GPU_LAYERS}"
  --flash-attn "${FLASH_ATTN}"
  --poll "${POLL}"
  --poll-batch "${POLL_BATCH}"
  --prio "${PRIO}"
  --prio-batch "${PRIO_BATCH}"
)

if [[ -n "${TENSOR_SPLIT}" ]]; then
  LLAMA_ARGS+=(--tensor-split "${TENSOR_SPLIT}")
fi

if [[ "${USE_MLOCK}" == "1" ]]; then
  LLAMA_ARGS+=(--mlock)
fi

if [[ "${ENABLE_METRICS}" == "1" ]]; then
  LLAMA_ARGS+=(--metrics)
fi

if [[ "${ENABLE_JINJA}" == "1" ]]; then
  LLAMA_ARGS+=(--jinja)
fi

DOCKER_ENV_ARGS=(
  -e LLAMA_CACHE=/data/llama-cache
)

if [[ -n "${API_KEY}" ]]; then
  DOCKER_ENV_ARGS+=(
    -e "API_KEY=${API_KEY}"
  )
fi

docker_cmd run --rm -it \
  --name "${CONTAINER_NAME}" \
  "${GPU_ARGS[@]}" \
  --ipc=host \
  -p "${PORT}:${PORT}" \
  "${DOCKER_ENV_ARGS[@]}" \
  -v "${MODEL_DIR}:/models:ro" \
  -v "${LLAMA_CACHE_DIR}:/data/llama-cache" \
  "${IMAGE_TAG}" \
  "${LLAMA_ARGS[@]}"
