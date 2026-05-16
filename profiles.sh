#!/usr/bin/env bash

expand_home_path() {
  local path="$1"

  case "$path" in
    '~')
      printf '%s\n' "$HOME"
      ;;
    '~'/*)
      printf '%s\n' "$HOME/${path#~/}"
      ;;
    '$HOME')
      printf '%s\n' "$HOME"
      ;;
    '$HOME'/*)
      printf '%s\n' "$HOME/${path#\$HOME/}"
      ;;
    '${HOME}')
      printf '%s\n' "$HOME"
      ;;
    '${HOME}'/*)
      printf '%s\n' "$HOME/${path#\$\{HOME\}/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

normalize_cuda_version() {
  local version="$1"

  case "$version" in
    *.*.*)
      printf '%s\n' "$version"
      ;;
    *.*)
      printf '%s.0\n' "$version"
      ;;
    *)
      printf '%s.0.0\n' "$version"
      ;;
  esac
}

detect_cuda_version() {
  local version=""

  if command -v nvidia-smi >/dev/null 2>&1; then
    version="$(nvidia-smi | sed -n 's/.*CUDA Version: \([0-9][0-9.]*\).*/\1/p' | head -n 1)"
  fi

  if [[ -z "$version" ]] && command -v nvcc >/dev/null 2>&1; then
    version="$(nvcc --version | sed -n 's/.*release \([0-9][0-9.]*\),.*/\1/p' | head -n 1)"
  fi

  if [[ -n "$version" ]]; then
    normalize_cuda_version "$version"
  fi
}

default_cuda_image() {
  local flavor="$1"
  local fallback_version="12.4.0"
  local cuda_version
  local cuda_architectures="${CUDA_ARCHITECTURES:-}"

  cuda_version="$(detect_cuda_version)"

  # CUDA 13 drops support for older architectures like sm_70 (V100).
  if [[ -n "$cuda_architectures" ]] && [[ "$cuda_architectures" -le 70 ]]; then
    cuda_version="$fallback_version"
  fi

  cuda_version="${cuda_version:-$fallback_version}"

  printf 'nvidia/cuda:%s-%s-ubuntu22.04\n' "$cuda_version" "$flavor"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Use this script via: source ./4090prepare/profiles.sh <profile>" >&2
  exit 1
fi

set -Eeuo pipefail

PROFILE_NAME="${1:-}"

if command -v nproc >/dev/null 2>&1; then
  DEFAULT_THREADS="$(nproc)"
else
  DEFAULT_THREADS="12"
fi

if [[ -z "${PROFILE_NAME}" ]]; then
  echo "Specify GPU profile: 3090, v100, 4090, h100, h200, h100nvl" >&2
  return 1
fi

export ROOT_DIR="${ROOT_DIR:-$HOME/llama-runtime}"
export ROOT_DIR="$(expand_home_path "${ROOT_DIR}")"
export IMAGE_TAG="${IMAGE_TAG:-llama-server:${PROFILE_NAME}}"
export INSTALL_NVIDIA_TOOLKIT="${INSTALL_NVIDIA_TOOLKIT:-1}"
export DOWNLOAD_IMAGE="${DOWNLOAD_IMAGE:-python:3.12-slim}"

export MODEL_REPO="${MODEL_REPO:-lmstudio-community/Qwen3.6-27B-GGUF}"
export MODEL_FILE="${MODEL_FILE:-Qwen3.6-27B-Q4_K_M.gguf}"
export MODEL_DIR_NAME="${MODEL_DIR_NAME:-${MODEL_FILE%.gguf}}"
export MODEL_DIR="${MODEL_DIR:-${ROOT_DIR}/models/${MODEL_DIR_NAME}}"
export HF_HOME_DIR="${HF_HOME_DIR:-${ROOT_DIR}/hf-home}"
export LLAMA_CACHE_DIR="${LLAMA_CACHE_DIR:-${ROOT_DIR}/llama-cache}"
export MODEL_DIR="$(expand_home_path "${MODEL_DIR}")"
export HF_HOME_DIR="$(expand_home_path "${HF_HOME_DIR}")"
export LLAMA_CACHE_DIR="$(expand_home_path "${LLAMA_CACHE_DIR}")"

export CONTAINER_NAME="${CONTAINER_NAME:-llama-server-${PROFILE_NAME}}"
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8080}"
export GPU_VISIBLE_DEVICES="${GPU_VISIBLE_DEVICES:-0}"
export PARALLEL="${PARALLEL:-1}"
export THREADS="${THREADS:-${DEFAULT_THREADS}}"
export THREADS_BATCH="${THREADS_BATCH:-$THREADS}"
export N_GPU_LAYERS="${N_GPU_LAYERS:-999}"
export SPLIT_MODE="${SPLIT_MODE:-none}"
export MAIN_GPU="${MAIN_GPU:-0}"
export TENSOR_SPLIT="${TENSOR_SPLIT:-}"
export FLASH_ATTN="${FLASH_ATTN:-on}"
export USE_MLOCK="${USE_MLOCK:-1}"
export ENABLE_METRICS="${ENABLE_METRICS:-1}"
export ENABLE_JINJA="${ENABLE_JINJA:-1}"
export POLL="${POLL:-1}"
export POLL_BATCH="${POLL_BATCH:-1}"
export PRIO="${PRIO:-2}"
export PRIO_BATCH="${PRIO_BATCH:-2}"

case "${PROFILE_NAME}" in
  3090)
    export CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-86}"
    export CTX_SIZE="${CTX_SIZE:-32768}"
    export BATCH_SIZE="${BATCH_SIZE:-1024}"
    export UBATCH_SIZE="${UBATCH_SIZE:-256}"
    ;;
  v100)
    export CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-70}"
    export CTX_SIZE="${CTX_SIZE:-16384}"
    export BATCH_SIZE="${BATCH_SIZE:-512}"
    export UBATCH_SIZE="${UBATCH_SIZE:-128}"
    export FLASH_ATTN="${FLASH_ATTN:-off}"
    ;;
  4090)
    export CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-89}"
    export CTX_SIZE="${CTX_SIZE:-65536}"
    export BATCH_SIZE="${BATCH_SIZE:-2048}"
    export UBATCH_SIZE="${UBATCH_SIZE:-512}"
    ;;
  h100)
    export CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-90}"
    export CTX_SIZE="${CTX_SIZE:-131072}"
    export BATCH_SIZE="${BATCH_SIZE:-4096}"
    export UBATCH_SIZE="${UBATCH_SIZE:-1024}"
    ;;
  h200)
    export CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-90}"
    export CTX_SIZE="${CTX_SIZE:-200000}"
    export BATCH_SIZE="${BATCH_SIZE:-4096}"
    export UBATCH_SIZE="${UBATCH_SIZE:-1024}"
    ;;
  h100nvl)
    export CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-90}"
    export CTX_SIZE="${CTX_SIZE:-200000}"
    export BATCH_SIZE="${BATCH_SIZE:-4096}"
    export UBATCH_SIZE="${UBATCH_SIZE:-1024}"
    ;;
  *)
    echo "Unknown GPU profile: ${PROFILE_NAME}" >&2
    echo "Choose one of: 3090, v100, 4090, h100, h200, h100nvl" >&2
    return 1
    ;;
esac

export CUDA_IMAGE="${CUDA_IMAGE:-$(default_cuda_image devel)}"
export VERIFY_IMAGE="${VERIFY_IMAGE:-$(default_cuda_image base)}"

echo "Loaded GPU profile: ${PROFILE_NAME}"
echo "  IMAGE_TAG=${IMAGE_TAG}"
echo "  CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES}"
echo "  GPU_VISIBLE_DEVICES=${GPU_VISIBLE_DEVICES}"
echo "  CTX_SIZE=${CTX_SIZE}"
echo "  BATCH_SIZE=${BATCH_SIZE}"
echo "  UBATCH_SIZE=${UBATCH_SIZE}"
echo "  THREADS=${THREADS}"
