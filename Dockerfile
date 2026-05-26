ARG ALPINE_VERSION=3.23
ARG AZCOPY_VERSION=10.31.1

FROM alpine:${ALPINE_VERSION} AS azure-cli

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apk upgrade --no-cache \
    && apk add --no-cache --virtual .azure-cli-build-deps \
      cargo \
      gcc \
      libffi-dev \
      linux-headers \
      make \
      musl-dev \
      openssl-dev \
      python3-dev \
    && apk add --no-cache \
      ca-certificates \
      py3-pip \
      py3-virtualenv \
      python3 \
    && python3 -m venv /opt/azure-cli \
    && /opt/azure-cli/bin/pip install --upgrade pip \
    && /opt/azure-cli/bin/pip install azure-cli \
    && /opt/azure-cli/bin/az version

FROM alpine:${ALPINE_VERSION} AS azcopy

ARG AZCOPY_VERSION
ARG TARGETARCH

RUN apk upgrade --no-cache \
    && apk add --no-cache \
      ca-certificates \
      curl \
      tar \
    && case "${TARGETARCH}" in \
      amd64) azcopy_arch='amd64' ;; \
      arm64) azcopy_arch='arm64' ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/Azure/azure-storage-azcopy/releases/download/v${AZCOPY_VERSION}/azcopy_linux_${azcopy_arch}_${AZCOPY_VERSION}.tar.gz" -o /tmp/azcopy.tar.gz \
    && tar -xzf /tmp/azcopy.tar.gz -C /tmp \
    && mv "/tmp/azcopy_linux_${azcopy_arch}_${AZCOPY_VERSION}/azcopy" /usr/local/bin/azcopy \
    && chmod +x /usr/local/bin/azcopy \
    && /usr/local/bin/azcopy --version

FROM alpine:${ALPINE_VERSION}

ENV HOME=/home/backup \
    PATH=/opt/azure-cli/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apk upgrade --no-cache \
    && apk add --no-cache \
      bash \
      ca-certificates \
      coreutils \
      curl \
      gzip \
      libffi \
      minio-client \
      openssl \
      postgresql-client \
      python3 \
      tar \
      tzdata \
    && addgroup -S -g 65532 backup \
    && adduser -S -D -H -u 65532 -G backup -h /home/backup -s /sbin/nologin backup \
    && mkdir -p /backup /home/backup \
    && chown -R backup:backup /backup /home/backup \
    && if command -v mcli >/dev/null 2>&1 && ! command -v mc >/dev/null 2>&1; then ln -s /usr/bin/mcli /usr/local/bin/mc; fi

COPY --from=azure-cli /opt/azure-cli /opt/azure-cli
COPY --from=azcopy /usr/local/bin/azcopy /usr/local/bin/azcopy

RUN ln -s /opt/azure-cli/bin/az /usr/local/bin/az

USER backup
WORKDIR /backup

CMD ["bash"]
