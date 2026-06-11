#!/bin/sh
set -e

: "${HF_REPO:=HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Aggressive}"
: "${HF_QUANT:=IQ4_XS}"
: "${MODELS_DIR:=/models}"

# Cache each model in its own subdir keyed by repo + quant, so switching models
# reuses an existing download instead of re-fetching.
MODEL_DIR="${MODELS_DIR}/$(printf '%s_%s' "$HF_REPO" "$HF_QUANT" | tr '/' '_')"
mkdir -p "$MODEL_DIR"

if ! find "$MODEL_DIR" -name "*.gguf" -print -quit | grep -q .; then
    echo "No GGUF found in ${MODEL_DIR}. Downloading ${HF_REPO} (${HF_QUANT})..."
    python3 -c "from huggingface_hub import snapshot_download; snapshot_download('${HF_REPO}', allow_patterns=['*${HF_QUANT}*', '*mmproj*'], local_dir='${MODEL_DIR}')"
fi

GGUF=$(find "$MODEL_DIR" -name "*.gguf" ! -name "mmproj-*" | head -1)
MMPROJ=$(find "$MODEL_DIR" -name "mmproj-*.gguf" | head -1)

if [ -z "$GGUF" ]; then
    echo "ERROR: no GGUF found in ${MODEL_DIR} after download" >&2
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
