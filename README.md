# worker-llamacpp

RunPod serverless worker for llama.cpp inference using a
[load balancing endpoint](https://docs.runpod.io/serverless/load-balancing/overview).
Runs llama-server directly with an OpenAI-compatible API. Supports dual-mode
operation for pod-first development.

## Build

```bash
# Default model (Nemotron-3-Nano-30B-A3B, UD-Q4_K_XL, fits 24GB VRAM)
docker build -t worker-llamacpp .

# Custom model (any direct URL to a .gguf file)
docker build \
  --build-arg MODEL_URL="https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf" \
  -t worker-llamacpp .
```

Push the image to Docker Hub or a container registry.

## Dual-Mode Development

This worker supports
[pod-first development](https://docs.runpod.io/serverless/development/dual-mode-worker),
allowing you to develop and test on a GPU Pod before deploying to serverless.

### Pod Mode (Development)

Deploy to a RunPod Pod for interactive development:

1. Go to **Pods** in the RunPod console
2. Click **Deploy** and select your GPU type
3. Enter your container image
4. Set environment variable: `MODE_TO_RUN=pod`
5. Deploy

Once running, you can:

- Connect via the web terminal or **SSH** (set `PUBLIC_KEY` env var with your
  public key)
- Start llama-server manually to test inference

### Serverless Mode (Production)

Deploy to RunPod Serverless with a **load balancing** endpoint:

1. Go to **Serverless** in the RunPod console
2. Click **New Endpoint**
3. Select **Load Balancing** as the endpoint type
4. Enter your container image
5. Set environment variable: `MODE_TO_RUN=serverless`
6. Configure endpoint settings and deploy

The endpoint exposes an OpenAI-compatible API. All llama-server endpoints are
accessible via:

```
https://ENDPOINT_ID.api.runpod.ai/<path>
```

### Development Workflow

1. **Develop on Pod**: Deploy with `MODE_TO_RUN=pod`, connect via JupyterLab/SSH
2. **Test locally**: Start llama-server and send requests to test
3. **Rebuild & deploy**: Push new image, deploy to serverless with
   `MODE_TO_RUN=serverless`

## Configuration

Set these environment variables on your RunPod endpoint:

| Variable       | Default              | Description                                                      |
| -------------- | -------------------- | ---------------------------------------------------------------- |
| `MODE_TO_RUN`  | `serverless`         | Operation mode: `pod` (development) or `serverless` (production) |
| `MODEL_PATH`   | `/models/model.gguf` | Path to the GGUF model file inside the container                 |
| `N_GPU_LAYERS` | `-1`                 | Number of layers to offload to GPU (`-1` = all)                  |
| `N_CTX`        | `4096`               | Context length                                                   |
| `PUBLIC_KEY`   | -                    | SSH public key for pod mode access (optional)                    |

## API

The endpoint provides an
[OpenAI-compatible API](https://github.com/ggml-org/llama.cpp/blob/master/examples/server/README.md)
via llama-server.

### Chat completion

```bash
curl https://ENDPOINT_ID.api.runpod.ai/v1/chat/completions \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "temperature": 0.7,
    "max_tokens": 256
  }'
```

### Text completion

```bash
curl https://ENDPOINT_ID.api.runpod.ai/v1/completions \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Once upon a time",
    "temperature": 0.8,
    "max_tokens": 512
  }'
```

### Streaming

Add `"stream": true` to any request to receive server-sent events:

```bash
curl https://ENDPOINT_ID.api.runpod.ai/v1/chat/completions \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "stream": true,
    "max_tokens": 256
  }'
```

## Architecture

```
Client -> RunPod Load Balancer -> nginx (:80) -> llama-server (:8080)
                                    |
                              /ping -> /health (status code mapping)
```

- **nginx** listens on port 80, proxies requests to llama-server on port 8080
- `/ping` health check (required by RunPod) maps to llama-server's `/health`
  endpoint
- During model loading, `/ping` returns 204 (initializing); once ready, returns
  200 (healthy)
