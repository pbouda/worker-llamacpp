FROM nvidia/cuda:12.9.1-devel-ubuntu22.04

ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
RUN ldconfig /usr/local/cuda-12.9/compat/

RUN apt-get update -y \
    && apt-get install -y python3-pip python3-dev cmake ninja-build curl libcurl4-openssl-dev git libssl-dev openssh-server nginx \
    && rm -rf /var/lib/apt/lists/*

# Install llama-cpp-python with CUDA support
ENV CMAKE_ARGS="-DGGML_CUDA=on"
RUN git clone https://github.com/ggml-org/llama.cpp && \
    cd llama.cpp && \
    cmake -B build && \
    cmake --build build --config Release --target install && \
    cd ..
RUN CMAKE_ARGS="-DLLAMA_BUILD=OFF" pip install llama-cpp-python

# Dual-mode support: pod (development) or serverless (production)
ARG MODE_TO_RUN=serverless
ENV MODE_TO_RUN=$MODE_TO_RUN

ENV PYTHONUNBUFFERED=1
ENV WORKSPACE_DIR=/workspace

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install --upgrade -r /requirements.txt

# Install Jupyter for pod mode development
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install jupyterlab

# Setup for baking model into image (optional)
ARG MODEL_REPO="unsloth/Qwen3-Coder-Next-GGUF"
ARG MODEL_FILENAME="Qwen3-Coder-Next-Q4_K_M.gguf"
ARG MODEL_DIR="/models"

ENV MODEL_REPO=$MODEL_REPO \
    MODEL_FILENAME=$MODEL_FILENAME \
    MODEL_DIR=$MODEL_DIR \
    MODEL_PATH="${MODEL_DIR}/${MODEL_FILENAME}" \
    N_GPU_LAYERS=-1 \
    N_CTX=4096

COPY src /src

RUN --mount=type=secret,id=HF_TOKEN,required=false \
    if [ -f /run/secrets/HF_TOKEN ]; then \
    export HF_TOKEN=$(cat /run/secrets/HF_TOKEN); \
    fi && \
    if [ -n "$MODEL_REPO" ] && [ -n "$MODEL_FILENAME" ]; then \
    python3 /src/download_model.py; \
    fi

# Setup startup script for dual-mode operation
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
