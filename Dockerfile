# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
# Используем python-образ для установки huggingface-cli
FROM python:3.9-slim as download

RUN pip install --no-cache-dir huggingface_hub[cli]

# Скачиваем Pony Diffusion V6 XL с Hugging Face
# HF_HUB_ENABLE_HF_TRANSFER=1 включает многопоточное скачивание для скорости
RUN HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download \
    LyliaEngine/Pony_Diffusion_V6_XL \
    ponyDiffusionV6XL_v6StartWithThisOne.safetensors \
    --local-dir /model \
    --local-dir-use-symlinks False

# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.14-slim as build_final_image

ARG A1111_RELEASE=v1.9.3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev libtcmalloc-minimal4 procps libgl1 libglib2.0-0 && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard ${A1111_RELEASE} && \
    pip install xformers && \
    pip install -r requirements_versions.txt && \
    python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test

# Копируем модель из Stage 1 в папку Checkpoints внутри WebUI
COPY --from=download /model/ponyDiffusionV6XL_v6StartWithThisOne.safetensors /stable-diffusion-webui/models/Stable-diffusion/ponyDiffusionV6XL.safetensors

# install dependencies
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY test_input.json .

ADD src .

RUN chmod +x /start.sh
CMD /start.sh
