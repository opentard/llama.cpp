# ot-llama

Dockerized [llama.cpp](https://github.com/ggerganov/llama.cpp) server.

**Default model:** `HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Aggressive` (IQ4_XS quantization)

The model is **not** baked into the image — it's downloaded on first run into a named Docker volume (`models`) so subsequent starts reuse the cached files.

## Prerequisites

- Docker with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed
- An NVIDIA GPU

## Quick Start

```bash
# Build the image (small — no model included)
docker compose build

# Start the server. First run downloads the model into the `models` volume;
# later runs reuse it.
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
| `--n-gpu-layers`, `-ngl` | Number of layers to offload to GPU | `99` (all layers) |
| `--threads`, `-t` | Number of CPU threads | auto |
| `--port` | Port to listen on | `8080` |
| `--host` | Address to bind to | `0.0.0.0` |
| `--chat-template` | Override the chat template | model default |
| `--cont-batching` | Enable continuous batching | off |
| `--flash-attn`, `-fa` | Enable flash attention | off |
| `--api-key` | Set an API key for authentication | none |

### CPU-only mode

To run without a GPU, override the GPU layers flag:

```bash
docker run -p 8080:8080 ot-llama-llama \
  --model /models/model.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --n-gpu-layers 0
```

### Using a different model

Set `HF_REPO` and `HF_QUANT` as environment variables on the container. The download happens on first start (if `/models` is empty), so clear the volume when switching models:

```bash
docker compose down -v           # removes the `models` volume
HF_REPO=TheBloke/Mistral-7B-Instruct-v0.2-GGUF HF_QUANT=Q4_K_M docker compose up
```

Or with plain `docker run`, mount your own directory and pass the env vars:

```bash
docker run -p 8080:8080 \
  -v $(pwd)/models:/models \
  -e HF_REPO=TheBloke/Mistral-7B-Instruct-v0.2-GGUF \
  -e HF_QUANT=Q4_K_M \
  ot-llama-llama
```
