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

: "${HF_TOKEN:?HF_TOKEN is not set}"

ROOT_DIR="${ROOT_DIR:-$HOME/llama-runtime}"
MODEL_REPO="${MODEL_REPO:-lmstudio-community/Qwen3.6-27B-GGUF}"
MODEL_FILE="${MODEL_FILE:-Qwen3.6-27B-Q4_K_M.gguf}"
MODEL_DIR_NAME="${MODEL_DIR_NAME:-${MODEL_FILE%.gguf}}"
MODEL_DIR="${MODEL_DIR:-${ROOT_DIR}/models/${MODEL_DIR_NAME}}"
HF_HOME_DIR="${HF_HOME_DIR:-${ROOT_DIR}/hf-home}"
DOWNLOAD_IMAGE="${DOWNLOAD_IMAGE:-python:3.12-slim}"

mkdir -p "${MODEL_DIR}" "${HF_HOME_DIR}"

echo "Downloading ${MODEL_FILE} from ${MODEL_REPO}"
echo "Target directory: ${MODEL_DIR}"

docker_cmd run --rm \
  -e HF_TOKEN="${HF_TOKEN}" \
  -e HF_HOME=/data/hf-home \
  -v "${MODEL_DIR}:/data/models" \
  -v "${HF_HOME_DIR}:/data/hf-home" \
  "${DOWNLOAD_IMAGE}" bash -lc "
    set -Eeuo pipefail
    python -m pip install --no-cache-dir -U 'huggingface_hub[cli]>=0.32'
    hf download '${MODEL_REPO}' \
      '${MODEL_FILE}' \
      --local-dir /data/models
  "

echo "Done"
