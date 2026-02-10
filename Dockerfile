FROM nvidia/cuda:12.9.1-devel-ubuntu22.04

ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
RUN ldconfig /usr/local/cuda-12.9/compat/

RUN apt-get update -y \
    && apt-get install -y cmake ninja-build curl libcurl4-openssl-dev git libssl-dev openssh-server nginx \
    && rm -rf /var/lib/apt/lists/*

# Build llama.cpp with CUDA support (provides llama-server binary)
ENV CMAKE_ARGS="-DGGML_CUDA=on"
RUN git clone https://github.com/ggml-org/llama.cpp && \
    cd llama.cpp && \
    cmake -B build && \
    cmake --build build --config Release --target install && \
    cd ..

# Dual-mode support: pod (development) or serverless (production)
ARG MODE_TO_RUN=serverless
ENV MODE_TO_RUN=$MODE_TO_RUN

ENV WORKSPACE_DIR=/workspace

# Download model at build time
ARG MODEL_URL="https://huggingface.co/unsloth/Nemotron-3-Nano-30B-A3B-GGUF/resolve/main/Nemotron-3-Nano-30B-A3B-UD-Q4_K_XL.gguf"
ARG MODEL_PATH="/models/model.gguf"

ENV MODEL_PATH=$MODEL_PATH \
    N_GPU_LAYERS=-1 \
    N_CTX=4096

RUN mkdir -p "$(dirname "$MODEL_PATH")" && \
    if [ -n "$MODEL_URL" ]; then \
    curl -L -o "$MODEL_PATH" "$MODEL_URL"; \
    fi

# Configure nginx as reverse proxy for llama-server
COPY nginx.conf /etc/nginx/sites-available/default

# Setup startup script for dual-mode operation
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
