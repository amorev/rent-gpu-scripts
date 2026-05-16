#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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
INSTALL_NVIDIA_DRIVER="${INSTALL_NVIDIA_DRIVER:-1}"
NVIDIA_DRIVER_PACKAGE="${NVIDIA_DRIVER_PACKAGE:-}"
ROOT_DIR="${ROOT_DIR:-$HOME/llama-runtime}"
ROOT_DIR="$(expand_home_path "${ROOT_DIR}")"
LLAMA_CACHE_DIR="${ROOT_DIR}/llama-cache"

mkdir -p "${LLAMA_CACHE_DIR}"

echo "[1/5] Checking NVIDIA driver on host"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "NVIDIA driver is already working"
elif [[ "${INSTALL_NVIDIA_DRIVER}" == "1" ]]; then
  echo "nvidia-smi is not working, installing NVIDIA driver"
  sudo apt-get update
  sudo apt-get install -y ubuntu-drivers-common pciutils
  sudo apt-get install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)"
  lspci -nn | grep -Ei 'nvidia|vga|3d' || true
  ubuntu-drivers devices || true
  ubuntu-drivers list --gpgpu || true
  if [[ -n "${NVIDIA_DRIVER_PACKAGE}" ]]; then
    sudo apt-get install --reinstall -y "${NVIDIA_DRIVER_PACKAGE}"
  else
    sudo ubuntu-drivers install --gpgpu
  fi
  sudo modprobe nvidia || true
  nvidia-smi
else
  echo "nvidia-smi is not working and INSTALL_NVIDIA_DRIVER=0" >&2
  exit 1
fi

if command -v docker >/dev/null 2>&1; then
  echo "[2/5] Docker is already installed"
elif [[ "${INSTALL_DOCKER}" == "1" ]]; then
  echo "[2/5] Installing Docker"
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

echo "[3/5] Building Docker image: ${IMAGE_TAG}"
docker_cmd build \
  -f "${DOCKERFILE_PATH}" \
  --build-arg CUDA_IMAGE="${CUDA_IMAGE}" \
  --build-arg CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES}" \
  -t "${IMAGE_TAG}" \
  "${BUILD_CONTEXT}"

if [[ "${INSTALL_NVIDIA_TOOLKIT}" == "1" ]]; then
  echo "[4/5] Installing NVIDIA Container Toolkit"
  sudo apt-get update
  sudo apt-get install -y curl gnupg ca-certificates
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y nvidia-container-toolkit
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
else
  echo "[4/5] Skipping NVIDIA Container Toolkit installation"
fi

echo "[5/5] Verifying Docker GPU access"
docker_cmd run --rm --gpus all "${VERIFY_IMAGE}" nvidia-smi

echo "Done"
echo
echo "Local folders:"
echo "  llama-cache: ${LLAMA_CACHE_DIR}"
echo
echo "Next steps:"
echo "  1. Download a model with: bash ${SCRIPT_DIR}/download.sh"
echo "  2. Start the server with: bash ${SCRIPT_DIR}/run.sh"
