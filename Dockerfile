# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.43.0 as download

RUN apk add --no-cache wget && \
    # Скачиваем Pony Diffusion V6 XL. 
    # ВАЖНО: Если ссылка устареет, обнови её ниже на новую с Civitai.
    wget -q -O /model.safetensors "https://civitai-delivery-worker-prod.5ac0637cfd0766c97916cefa3764fbdf.r2.cloudflarestorage.com/model/492754/v6.78PX.safetensors?X-Amz-Expires=86400&response-content-disposition=attachment%3B%20filename%3D%22ponyDiffusionV6XL_v6StartWithThisOne.safetensors%22&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=e01358d793ad6966166af8b3064953ad/20260409/us-east-1/s3/aws4_request&X-Amz-Date=20260409T063651Z&X-Amz-SignedHeaders=host&X-Amz-Signature=c0de738a81d7d432a2b2792ffa783ac4db50c64a9926ae25f285217d85e94466"

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

# Копируем модель сразу в папку Checkpoints внутри репозитория WebUI
COPY --from=download /model.safetensors /stable-diffusion-webui/models/Stable-diffusion/ponyDiffusionV6XL.safetensors

# install dependencies
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY test_input.json .

ADD src .

RUN chmod +x /start.sh
CMD /start.sh
