#!/bin/bash
set -e

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"

start_nginx() {
    if command -v nginx &> /dev/null && service --status-all 2>&1 | grep -q nginx; then
        echo "Starting Nginx service..."
        service nginx start || true
    fi
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

start_jupyter() {
    if command -v jupyter &> /dev/null; then
        echo "Starting Jupyter Lab..."
        mkdir -p "$WORKSPACE_DIR"
        cd /
        nohup jupyter lab --allow-root --no-browser --port=8888 --ip=* \
            --NotebookApp.token='' --NotebookApp.password='' \
            --FileContentsManager.delete_to_trash=False &> /jupyter.log &
    else
        echo "Jupyter not installed, skipping..."
    fi
}

call_python_handler() {
    echo "Starting handler.py..."
    python3 /src/handler.py
}

# Optional services for pod mode
start_nginx
setup_ssh

case $MODE_TO_RUN in
    serverless)
        echo "Running in serverless mode"
        call_python_handler
        ;;
    pod)
        echo "Running in pod mode"
        start_jupyter
        echo "Pod ready for development. Use 'python3 /src/handler.py' to test."
        sleep infinity
        ;;
    *)
        echo "Invalid MODE_TO_RUN value: $MODE_TO_RUN"
        echo "Valid options: 'pod' or 'serverless'"
        exit 1
        ;;
esac
