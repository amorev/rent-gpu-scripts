ARG CUDA_IMAGE=nvidia/cuda:12.4.0-devel-ubuntu22.04
FROM ${CUDA_IMAGE}

ARG CUDA_ARCHITECTURES=89

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/opt/llama.cpp/build/bin:${PATH}
ENV LD_LIBRARY_PATH=/opt/llama.cpp/build/bin:${LD_LIBRARY_PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    ca-certificates \
    curl \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/ggml-org/llama.cpp.git

WORKDIR /opt/llama.cpp

# Fix for CUDA stub linking inside build container
RUN set -eux; \
    CUDA_STUBS="/usr/local/cuda/targets/x86_64-linux/lib/stubs"; \
    test -f "${CUDA_STUBS}/libcuda.so"; \
    ln -sf "${CUDA_STUBS}/libcuda.so" "${CUDA_STUBS}/libcuda.so.1"

RUN export CUDA_STUBS=/usr/local/cuda/targets/x86_64-linux/lib/stubs && \
    cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DGGML_CUDA=ON \
      -DGGML_NATIVE=OFF \
      -DCMAKE_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_BUILD_TOOLS=ON \
      -DLLAMA_BUILD_SERVER=ON \
      -DLLAMA_BUILD_WEBUI=ON \
      -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link,${CUDA_STUBS}" && \
    cmake --build build --config Release --target llama-server -j"$(nproc)"

WORKDIR /work
EXPOSE 8080

ENTRYPOINT ["llama-server"]
