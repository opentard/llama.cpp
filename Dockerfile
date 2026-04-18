FROM ghcr.io/ggml-org/llama.cpp:server-cuda AS base

# Install python + huggingface-cli for reliable model download
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip && \
    pip3 install --break-system-packages huggingface-hub && \
    rm -rf /var/lib/apt/lists/*

# Download the Q4_K_M quantized GGUF at build time so it's baked into the image
ARG HF_REPO=HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive
ARG HF_QUANT=Q4_K_M
RUN mkdir -p /models && \
    python3 -c "from huggingface_hub import snapshot_download; snapshot_download('${HF_REPO}', allow_patterns=['*${HF_QUANT}*', '*mmproj*'], local_dir='/models')"

# Find the downloaded GGUF files and store their paths
RUN GGUF=$(find /models -name "*.gguf" ! -name "mmproj-*" | head -1) && \
    MMPROJ=$(find /models -name "mmproj-*.gguf" | head -1) && \
    echo "${GGUF}" > /models/.model_path && \
    echo "${MMPROJ}" > /models/.mmproj_path && \
    echo "Model downloaded: ${GGUF}" && \
    echo "Projector downloaded: ${MMPROJ}"


EXPOSE 8080

ENTRYPOINT ["/bin/sh", "-c", "/app/llama-server --model $(cat /models/.model_path) --mmproj $(cat /models/.mmproj_path) --alias openai/singularity --host 0.0.0.0 --port 8080 --n-gpu-layers 99 --image-min-tokens 1024 --jinja --reasoning-budget 0"]
