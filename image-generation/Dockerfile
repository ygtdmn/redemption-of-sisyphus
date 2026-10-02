# Reproducible environment for gen.py: Python 3.12.11 on linux/amd64, the exact
# package wheels from the artwork's hash list, and the Stable Diffusion v1.5
# weights baked in so runs work offline.
#
# Build (from this directory):
#   docker build --platform linux/amd64 -t redemption-of-sisyphus .
#
# The model is pinned to the Hugging Face commit that was current when the target
# hash was made (the repo has not changed since 2024-09-07). Override with:
#   docker build --platform linux/amd64 --build-arg MODEL_REVISION=<commit> -t redemption-of-sisyphus .

FROM python:3.12.11-slim-bookworm@sha256:519591d6871b7bc437060736b9f7456b8731f1499a57e22e6c285135ae657bf7

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HOME=/opt/huggingface \
    HF_HUB_DISABLE_TELEMETRY=1

WORKDIR /app

COPY requirements.lock .
# The download cache lives outside the image, so a failed or repeated build does
# not fetch the ~3 GB of wheels again
RUN --mount=type=cache,target=/root/.cache/pip \
    PIP_NO_CACHE_DIR=0 pip install --timeout 120 --retries 10 \
        --require-hashes --no-deps --only-binary=:all: -r requirements.lock

ARG MODEL_ID=sd-legacy/stable-diffusion-v1-5
ARG MODEL_REVISION=451f4fe16113bff5a5d2269ed5ad43b0592e9a14
COPY download_model.py .
# The xet chunk cache holds a second copy of the weights and is not needed to load them
RUN MODEL_ID=${MODEL_ID} MODEL_REVISION=${MODEL_REVISION} python download_model.py \
    && rm -rf "${HF_HOME}/xet"

# From here on gen.py resolves the model from the local cache only
ENV HF_HUB_OFFLINE=1

COPY gen.py verify.py entrypoint.sh ./

# gen.py writes output/ and seed_cache.json to the working directory; mount a
# host directory here to keep results and the seed cache between runs.
WORKDIR /work

# Every command runs with 16 threads and AVX2, and refuses to start on a CPU
# without AVX2 (see entrypoint.sh)
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["python", "/app/gen.py"]
