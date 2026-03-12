FROM ghcr.io/ggml-org/llama.cpp:server AS base

# Install python + huggingface-cli for reliable model download
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip && \
    pip3 install --break-system-packages huggingface-hub && \
    rm -rf /var/lib/apt/lists/*

# Download the Q4_K_M quantized GGUF at build time so it's baked into the image
ARG HF_REPO=HauhauCS/Qwen3.5-4B-Uncensored-HauhauCS-Aggressive
ARG HF_QUANT=Q4_K_M
RUN mkdir -p /models && \
    huggingface-cli download "${HF_REPO}" \
      --include "*${HF_QUANT}*" \
      --local-dir /models

# Find the downloaded GGUF and create a stable symlink
RUN GGUF=$(find /models -name "*.gguf" | head -1) && \
    ln -sf "${GGUF}" /models/model.gguf && \
    echo "Model downloaded: ${GGUF}"

EXPOSE 8080

ENTRYPOINT ["llama-server"]
CMD ["--model", "/models/model.gguf", "--host", "0.0.0.0", "--port", "8080", "--n-gpu-layers", "99"]
