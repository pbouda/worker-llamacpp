FROM nvidia/cuda:12.9.1-devel-ubuntu22.04 AS build

RUN apt-get update -y \
    && apt-get install -y python3-pip python3-dev cmake ninja-build \
    && rm -rf /var/lib/apt/lists/*

# Install llama-cpp-python with CUDA support
ENV CMAKE_ARGS="-DGGML_CUDA=on"
RUN LD_LIBRARY_PATH=/usr/local/cuda-12.9/compat:$LD_LIBRARY_PATH \
    pip install llama-cpp-python

FROM nvidia/cuda:12.9.1-base-ubuntu22.04

RUN apt-get update -y \
    && apt-get install -y python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN ldconfig /usr/local/cuda-12.9/compat/

# Copy llama-cpp-python from build stage
COPY --from=build /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages

# Install Python dependencies
COPY builder/requirements.txt /requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install --upgrade -r /requirements.txt

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

CMD ["python3", "/src/handler.py"]
