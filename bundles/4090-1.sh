#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREPARE_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

source "${PREPARE_DIR}/profiles.sh" 4090

export ROOT_DIR="${ROOT_DIR:-$HOME/llama-runtime}"
export IMAGE_TAG="${IMAGE_TAG:-llama-server:4090-1}"
export CONTAINER_NAME="${CONTAINER_NAME:-llama-server-4090-1}"
export GPU_VISIBLE_DEVICES="${GPU_VISIBLE_DEVICES:-0}"

export MODEL_REPO="${MODEL_REPO:-lmstudio-community/Qwen3.6-27B-GGUF}"
export MODEL_FILE="${MODEL_FILE:-Qwen3.6-27B-Q4_K_M.gguf}"
export MODEL_DIR_NAME="${MODEL_DIR_NAME:-${MODEL_FILE%.gguf}}"
export MODEL_DIR="${MODEL_DIR:-${ROOT_DIR}/models/${MODEL_DIR_NAME}}"
export HF_HOME_DIR="${HF_HOME_DIR:-${ROOT_DIR}/hf-home}"
export LLAMA_CACHE_DIR="${LLAMA_CACHE_DIR:-${ROOT_DIR}/llama-cache}"

echo "Preparing single RTX 4090 environment"
echo "  ROOT_DIR=${ROOT_DIR}"
echo "  IMAGE_TAG=${IMAGE_TAG}"
echo "  GPU_VISIBLE_DEVICES=${GPU_VISIBLE_DEVICES}"
echo "  MODEL_FILE=${MODEL_FILE}"
echo

bash "${PREPARE_DIR}/setup.sh"
bash "${PREPARE_DIR}/download.sh"

echo
echo "Environment is ready. Run the model with:"
echo "  ROOT_DIR=${ROOT_DIR} IMAGE_TAG=${IMAGE_TAG} CONTAINER_NAME=${CONTAINER_NAME} GPU_VISIBLE_DEVICES=${GPU_VISIBLE_DEVICES} MODEL_REPO=${MODEL_REPO} MODEL_FILE=${MODEL_FILE} MODEL_DIR_NAME=${MODEL_DIR_NAME} MODEL_DIR=${MODEL_DIR} HF_HOME_DIR=${HF_HOME_DIR} LLAMA_CACHE_DIR=${LLAMA_CACHE_DIR} bash ${PREPARE_DIR}/run.sh"
