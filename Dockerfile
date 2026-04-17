# Use an alpine image
FROM alpine:3.23

RUN apk add --no-cache \
    bash \
    ca-certificates \
    coreutils \
    gzip \
    libffi \
    minio-client \
    openssl \
    postgresql-client \
    py3-pip \
    py3-virtualenv \
    python3 \
    tar \
    tzdata \
    && apk add --no-cache --virtual .azure-cli-build-deps \
    cargo \
    gcc \
    libffi-dev \
    linux-headers \
    make \
    musl-dev \
    openssl-dev \
    python3-dev \
    && python3 -m venv /opt/azure-cli \
    && /opt/azure-cli/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/azure-cli/bin/pip install --no-cache-dir azure-cli \
    && ln -s /opt/azure-cli/bin/az /usr/local/bin/az \
    && if command -v mcli >/dev/null 2>&1 && ! command -v mc >/dev/null 2>&1; then ln -s /usr/bin/mcli /usr/local/bin/mc; fi \
    && apk del .azure-cli-build-deps

CMD ["bash"]