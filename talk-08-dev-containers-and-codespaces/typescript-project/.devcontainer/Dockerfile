FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV NVM_DIR=/usr/local/share/nvm
ENV NODE_VERSION=20.17.0
ENV PATH=${NVM_DIR}/versions/node/v${NODE_VERSION}/bin:${PATH}

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Default EXTRA_CERTS_DIR=certs points at an empty placeholder, so this is a NO-OP
# on a normal laptop and only activates when real .crt files are supplied in certs/.
# Pass real certs with:  docker build --build-arg EXTRA_CERTS_DIR=certs ...
ARG EXTRA_CERTS_DIR=certs
COPY ${EXTRA_CERTS_DIR}/ /usr/local/share/ca-certificates/extra/
RUN if ls -A /usr/local/share/ca-certificates/extra/ 2>/dev/null | grep -q .; then \
        if command -v update-ca-certificates >/dev/null 2>&1; then \
            update-ca-certificates; \
        else \
            cat /usr/local/share/ca-certificates/extra/*.crt >> /etc/ssl/certs/ca-certificates.crt; \
        fi; \
    fi
# -----------------------------------------------------------------------------

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl git jq httpie build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p "${NVM_DIR}" \
    && curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | PROFILE=/dev/null NVM_DIR="${NVM_DIR}" bash \
    && source "${NVM_DIR}/nvm.sh" \
    && nvm install "${NODE_VERSION}" \
    && nvm alias default "${NODE_VERSION}" \
    && ln -sf "${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/node" /usr/local/bin/node \
    && ln -sf "${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/npm" /usr/local/bin/npm \
    && ln -sf "${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/npx" /usr/local/bin/npx
