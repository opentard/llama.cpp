FROM ghcr.io/ggml-org/llama.cpp:server-cuda AS base

# Install python + huggingface-cli for reliable model download
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip && \
    pip3 install huggingface-hub && \
    rm -rf /var/lib/apt/lists/*

# Download the Q6_K quantized GGUF at build time so it's baked into the image
ARG HF_REPO=HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive
ARG HF_QUANT=Q6_K
RUN mkdir -p /models && \
    python3 -c "from huggingface_hub import snapshot_download; snapshot_download('${HF_REPO}', allow_patterns=['*${HF_QUANT}*', '*mmproj*'], local_dir='/models')"

# Find the downloaded GGUF files and store their paths
RUN GGUF=$(find /models -name "*.gguf" ! -name "*mmproj*" | head -1) && \
    MMPROJ=$(find /models -name "*mmproj*.gguf" | head -1) && \
    echo "${GGUF}" > /models/.model_path && \
    echo "${MMPROJ}" > /models/.mmproj_path && \
    echo "Model downloaded: ${GGUF}" && \
    echo "Vision encoder downloaded: ${MMPROJ}"


EXPOSE 8080

ENTRYPOINT ["/bin/sh", "-c", "/app/llama-server --model $(cat /models/.model_path) --mmproj $(cat /models/.mmproj_path) --alias openai/singularity --host 0.0.0.0 --port 8080 --n-gpu-layers 99 --ctx-size 100000 --reasoning off --reasoning-budget 0 --temp 0.1 --top-p 0.9 --top-k 20 --repeat-penalty 1.05 --image-min-tokens 1024"]
