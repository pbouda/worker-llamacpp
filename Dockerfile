# Stage 1: Build llama.cpp
FROM nvidia/cuda:12.9.1-devel-ubuntu22.04 AS builder

RUN apt-get update -y \
    && apt-get install -y cmake ninja-build curl libcurl4-openssl-dev git libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ggml-org/llama.cpp && \
    cd llama.cpp && \
    cmake -B build && \
    cmake --build build --config Release && \
    cmake --install build --prefix /opt/llama.cpp

# Stage 2: Runtime
FROM nvidia/cuda:12.9.1-runtime-ubuntu22.04

RUN apt-get update -y \
    && apt-get install -y curl libcurl4 libgomp1 openssh-server nginx \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/llama.cpp /opt/llama.cpp

ENV PATH="/opt/llama.cpp/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/llama.cpp/lib:$LD_LIBRARY_PATH"

# Dual-mode support: pod (development) or serverless (production)
ARG MODE_TO_RUN=serverless
ENV MODE_TO_RUN=$MODE_TO_RUN \
    WORKSPACE_DIR=/workspace

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
