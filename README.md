# worker-llamacpp

RunPod serverless worker for llama.cpp inference. Supports dual-mode operation for pod-first development.

## Build

```bash
# Default model (Qwen3-Coder-Next-Q4_K_M)
docker build -t worker-llamacpp .

# Custom model
docker build \
  --build-arg MODEL_REPO="bartowski/Meta-Llama-3.1-8B-Instruct-GGUF" \
  --build-arg MODEL_FILENAME="Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" \
  -t worker-llamacpp .

# Gated models (pass HF token)
docker build \
  --secret id=HF_TOKEN,env=HF_TOKEN \
  --build-arg MODEL_REPO="..." \
  --build-arg MODEL_FILENAME="..." \
  -t worker-llamacpp .
```

Push the image to Docker Hub or a container registry.

## Dual-Mode Development

This worker supports [pod-first development](https://docs.runpod.io/serverless/development/dual-mode-worker), allowing you to develop and test on a GPU Pod before deploying to serverless.

### Pod Mode (Development)

Deploy to a RunPod Pod for interactive development:

1. Go to **Pods** in the RunPod console
2. Click **Deploy** and select your GPU type
3. Enter your container image
4. Set environment variable: `MODE_TO_RUN=pod`
5. Deploy

Once running, you can:
- Connect via **JupyterLab** (port 8888) to edit and test code
- Connect via **SSH** (set `PUBLIC_KEY` env var with your public key)
- Run `python3 /src/handler.py` to test the handler interactively

### Serverless Mode (Production)

Deploy to RunPod Serverless:

1. Go to **Serverless** in the RunPod console
2. Click **New Endpoint**
3. Enter your container image
4. Set environment variable: `MODE_TO_RUN=serverless`
5. Configure endpoint settings and deploy

### Development Workflow

1. **Develop on Pod**: Deploy with `MODE_TO_RUN=pod`, connect via JupyterLab/SSH, iterate on handler code
2. **Test locally**: Run `python3 /src/handler.py` to verify changes
3. **Update dependencies**: Add new packages to `builder/requirements.txt`
4. **Rebuild & deploy**: Push new image, deploy to serverless with `MODE_TO_RUN=serverless`

## RunPod Configuration

Set these environment variables on your RunPod endpoint:

| Variable | Default | Description |
|---|---|---|
| `MODE_TO_RUN` | `serverless` | Operation mode: `pod` (development) or `serverless` (production) |
| `MODEL_PATH` | `/models/<MODEL_FILENAME>` | Path to the GGUF model file inside the container |
| `N_GPU_LAYERS` | `-1` | Number of layers to offload to GPU (`-1` = all) |
| `N_CTX` | `4096` | Context length |
| `DEFAULT_BATCH_SIZE` | `5` | Tokens to accumulate per streamed chunk |
| `PUBLIC_KEY` | - | SSH public key for pod mode access (optional) |

## Request Format

### Chat completion

```json
{
  "input": {
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "stream": false,
    "sampling_params": {
      "temperature": 0.7,
      "max_tokens": 256
    }
  }
}
```

### Text completion

```json
{
  "input": {
    "prompt": "Once upon a time",
    "stream": true,
    "sampling_params": {
      "temperature": 0.8,
      "top_p": 0.95,
      "top_k": 40,
      "max_tokens": 512,
      "repeat_penalty": 1.1,
      "stop": ["\n"]
    }
  }
}
```
