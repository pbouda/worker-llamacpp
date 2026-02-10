#!/bin/bash
set -e

start_nginx() {
    echo "Starting Nginx..."
    service nginx start || true
}

setup_ssh() {
    if [[ $PUBLIC_KEY ]]; then
        echo "Setting up SSH..."
        mkdir -p ~/.ssh
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh
        ssh-keygen -A
        service ssh start || true
    fi
}

start_llama_server() {
    MODEL_PATH="${MODEL_PATH:-/models/model.gguf}"
    N_GPU_LAYERS="${N_GPU_LAYERS:--1}"
    N_CTX="${N_CTX:-4096}"

    echo "Starting llama-server..."
    echo "  Model: $MODEL_PATH"
    echo "  GPU layers: $N_GPU_LAYERS"
    echo "  Context: $N_CTX"

    exec llama-server \
        --model "$MODEL_PATH" \
        --n-gpu-layers "$N_GPU_LAYERS" \
        --ctx-size "$N_CTX" \
        --host 0.0.0.0 \
        --port 8080
}

# Optional services
setup_ssh

case $MODE_TO_RUN in
    serverless)
        echo "Running in serverless mode (load balancing endpoint)"
        start_nginx
        start_llama_server
        ;;
    pod)
        echo "Running in pod mode"
        start_nginx
        echo "Pod ready for development."
        echo "Run 'llama-server --model \$MODEL_PATH --n-gpu-layers \$N_GPU_LAYERS --ctx-size \$N_CTX --host 0.0.0.0 --port 8080' to start the server."
        sleep infinity
        ;;
    *)
        echo "Invalid MODE_TO_RUN value: $MODE_TO_RUN"
        echo "Valid options: 'pod' or 'serverless'"
        exit 1
        ;;
esac
