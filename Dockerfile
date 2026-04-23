FROM ghcr.io/ggml-org/llama.cpp:server-cuda AS base

# huggingface-hub is used at runtime to download the model on first start
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip && \
    pip3 install --break-system-packages huggingface-hub && \
    rm -rf /var/lib/apt/lists/*

ENV HF_REPO=HauhauCS/Qwen3.6-27B-Uncensored-HauhauCS-Aggressive \
    HF_QUANT=IQ4_XS \
    MODELS_DIR=/models

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
