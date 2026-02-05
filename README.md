# worker-llamacpp

RunPod serverless worker for llama.cpp inference.

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

Push the image to Docker Hub or a container registry, then use it as the image for your RunPod serverless endpoint.

## RunPod Configuration

Set these environment variables on your RunPod serverless endpoint:

| Variable | Default | Description |
|---|---|---|
| `MODEL_PATH` | `/models/<MODEL_FILENAME>` | Path to the GGUF model file inside the container |
| `N_GPU_LAYERS` | `-1` | Number of layers to offload to GPU (`-1` = all) |
| `N_CTX` | `4096` | Context length |
| `DEFAULT_BATCH_SIZE` | `5` | Tokens to accumulate per streamed chunk |

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
