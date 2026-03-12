# ot-llama

Dockerized [llama.cpp](https://github.com/ggerganov/llama.cpp) server with a preloaded model.

**Default model:** `HauhauCS/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive` (Q4_K_M quantization)

## Quick Start

```bash
# Build the image (downloads the model during build — ~2-3 GB)
docker compose build

# Start the server
docker compose up
```

The server is now available at **http://localhost:8080** with:
- Web UI at the root URL
- OpenAI-compatible API at `/v1/chat/completions`, `/v1/completions`, etc.

## Optional Parameters

You can pass any `llama-server` flag by overriding the default command:

```bash
docker run -p 8080:8080 ot-llama-llama \
  --model /models/model.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --ctx-size 4096 \
  --n-gpu-layers 99
```

### Common flags

| Flag | Description | Default |
|---|---|---|
| `--ctx-size`, `-c` | Context window size (tokens) | `2048` |
| `--n-gpu-layers`, `-ngl` | Number of layers to offload to GPU | `0` (CPU only) |
| `--threads`, `-t` | Number of CPU threads | auto |
| `--port` | Port to listen on | `8080` |
| `--host` | Address to bind to | `0.0.0.0` |
| `--chat-template` | Override the chat template | model default |
| `--cont-batching` | Enable continuous batching | off |
| `--flash-attn`, `-fa` | Enable flash attention | off |
| `--api-key` | Set an API key for authentication | none |

### GPU support

To use GPU acceleration, run with the NVIDIA Container Toolkit:

```bash
docker run --gpus all -p 8080:8080 ot-llama-llama \
  --model /models/model.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --n-gpu-layers 99
```

### Using a different model at build time

You can swap the model by passing build args:

```bash
docker build \
  --build-arg HF_REPO=TheBloke/Mistral-7B-Instruct-v0.2-GGUF \
  --build-arg HF_QUANT=Q4_K_M \
  -t ot-llama-custom .
```
