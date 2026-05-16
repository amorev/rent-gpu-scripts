#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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
DOCKERFILE_PATH="${DOCKERFILE_PATH:-${SCRIPT_DIR}/llama-server.dockerfile}"
BUILD_CONTEXT="${BUILD_CONTEXT:-${SCRIPT_DIR}}"
CUDA_IMAGE="${CUDA_IMAGE:-nvidia/cuda:12.4.0-devel-ubuntu22.04}"
CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-89}"
VERIFY_IMAGE="${VERIFY_IMAGE:-nvidia/cuda:12.4.0-base-ubuntu22.04}"
INSTALL_DOCKER="${INSTALL_DOCKER:-1}"
INSTALL_NVIDIA_TOOLKIT="${INSTALL_NVIDIA_TOOLKIT:-1}"
ROOT_DIR="${ROOT_DIR:-$HOME/llama-runtime}"
LLAMA_CACHE_DIR="${ROOT_DIR}/llama-cache"

mkdir -p "${LLAMA_CACHE_DIR}"

if command -v docker >/dev/null 2>&1; then
  echo "[1/4] Docker is already installed"
elif [[ "${INSTALL_DOCKER}" == "1" ]]; then
  echo "[1/4] Installing Docker"
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo systemctl enable --now docker
else
  echo "Docker is not installed. Set INSTALL_DOCKER=1 or install Docker manually." >&2
  exit 1
fi

echo "[2/4] Building Docker image: ${IMAGE_TAG}"
docker_cmd build \
  -f "${DOCKERFILE_PATH}" \
  --build-arg CUDA_IMAGE="${CUDA_IMAGE}" \
  --build-arg CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES}" \
  -t "${IMAGE_TAG}" \
  "${BUILD_CONTEXT}"

if [[ "${INSTALL_NVIDIA_TOOLKIT}" == "1" ]]; then
  echo "[3/4] Installing NVIDIA Container Toolkit"
  sudo apt-get update
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
else
  echo "[3/4] Skipping NVIDIA Container Toolkit installation"
fi

echo "[4/4] Verifying Docker GPU access"
docker_cmd run --rm --gpus all "${VERIFY_IMAGE}" nvidia-smi

echo "Done"
echo
echo "Local folders:"
echo "  llama-cache: ${LLAMA_CACHE_DIR}"
echo
echo "Next steps:"
echo "  1. Download a model with: bash ${SCRIPT_DIR}/download.sh"
echo "  2. Start the server with: bash ${SCRIPT_DIR}/run.sh"
