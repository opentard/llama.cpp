#!/bin/sh
set -e

: "${HF_REPO:=HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Aggressive}"
: "${HF_QUANT:=IQ4_XS}"
: "${MODELS_DIR:=/models}"

mkdir -p "$MODELS_DIR"

if ! find "$MODELS_DIR" -maxdepth 3 -name "*.gguf" -print -quit | grep -q .; then
    echo "No GGUF found in ${MODELS_DIR}. Downloading ${HF_REPO} (${HF_QUANT})..."
    python3 -c "from huggingface_hub import snapshot_download; snapshot_download('${HF_REPO}', allow_patterns=['*${HF_QUANT}*', '*mmproj*'], local_dir='${MODELS_DIR}')"
fi

GGUF=$(find "$MODELS_DIR" -name "*.gguf" ! -name "mmproj-*" | head -1)
MMPROJ=$(find "$MODELS_DIR" -name "mmproj-*.gguf" | head -1)

if [ -z "$GGUF" ]; then
    echo "ERROR: no GGUF found in ${MODELS_DIR} after download" >&2
    exit 1
fi

set -- --model "$GGUF" \
    --alias openai/singularity \
    --host 0.0.0.0 \
    --port 8080 \
    --n-gpu-layers 99 \
    --image-min-tokens 1024 \
    --jinja \
    --reasoning-budget 2048 \
    --ctx-size 262144 \
    --parallel 1 \
    --cache-type-k q5_1 \
    --cache-type-v q5_1 \
    --flash-attn on \
    --temp 0.1 \
    --top-p 0.9 \
    "$@"

if [ -n "$MMPROJ" ]; then
    set -- "$@" --mmproj "$MMPROJ"
fi

exec /app/llama-server "$@"
