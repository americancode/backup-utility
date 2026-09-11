ARG ALPINE_VERSION=3.23

FROM alpine:${ALPINE_VERSION} AS azure-cli

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Temporary dependency overrides for findings reported by Trivy. Remove these
# once the Azure CLI dependency set includes fixed releases. The cryptography
# override fixes CVE-2026-69247, CVE-2026-69248, and CVE-2026-69249; the msgpack
# override fixes GHSA-6v7p-g79w-8964.
# pip and setuptools are build-time tooling. Removing them also removes
# CVE-2025-47273 and CVE-2026-59890 from the runtime image.
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
    && /opt/azure-cli/bin/pip install --upgrade \
      'cryptography>=50.0.0' \
      'msgpack>=1.2.1' \
    && /opt/azure-cli/bin/az version \
    && /opt/azure-cli/bin/pip uninstall --yes pip setuptools

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
    && chgrp backup /etc/ssl/certs /usr/local/share/ca-certificates \
    && chmod 0775 /etc/ssl/certs /usr/local/share/ca-certificates \
    && chmod g+rw /etc/ssl/certs/ca-certificates.crt \
    && if command -v mcli >/dev/null 2>&1 && ! command -v mc >/dev/null 2>&1; then ln -s /usr/bin/mcli /usr/local/bin/mc; fi

COPY --from=azure-cli /opt/azure-cli /opt/azure-cli

RUN ln -s /opt/azure-cli/bin/az /usr/local/bin/az

USER backup
WORKDIR /backup

CMD ["bash"]
