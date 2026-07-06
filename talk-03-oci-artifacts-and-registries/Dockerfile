# syntax=docker/dockerfile:1
FROM rocker/r-ver:4.3.0 AS base

# The Rocker project provides curated R images, so we can start from a clean
# R runtime instead of compiling R by hand inside a generic Linux image.
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

RUN --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  cp /etc/ssl/certs/ca-certificates.crt /tmp/ca-bundle.orig
  cp /run/secrets/netskope_cert /usr/local/share/ca-certificates/netskope.crt 2>/dev/null || true
  update-ca-certificates 2>/dev/null || cat /run/secrets/netskope_cert >> /etc/ssl/certs/ca-certificates.crt
fi
apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*
R -q -e "install.packages(c('plumber', 'jsonlite'), repos='https://cloud.r-project.org')"
if [ -s /run/secrets/netskope_cert ]; then
  rm -f /usr/local/share/ca-certificates/netskope.crt
  mv /tmp/ca-bundle.orig /etc/ssl/certs/ca-certificates.crt
fi
EOF

FROM base AS model-builder
COPY src/train_model.R /app/train_model.R
RUN Rscript /app/train_model.R

FROM base AS runtime
RUN groupadd --system plumber \
    && useradd --system --gid plumber --home-dir /app --no-create-home plumber
COPY --from=model-builder --chown=plumber:plumber /app/model.rds /app/model.rds
COPY --chown=plumber:plumber src/api.R /app/api.R

USER plumber
EXPOSE 8000

CMD ["R", "-q", "-e", "api <- plumber::plumb('/app/api.R'); api$run(host = '0.0.0.0', port = 8000)"]
