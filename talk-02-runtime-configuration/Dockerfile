# syntax=docker/dockerfile:1.7
FROM python:3.12-slim

# ARG is fine for non-sensitive build metadata, but not for secrets.
# Values passed via ARG can show up in image history and build metadata.
ARG APP_VERSION=dev
ARG BUILD_NOTE="runtime-configuration-demo"

# ENV is also unsafe for secrets because it becomes part of the image config.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_HOME=/app \
    APP_VERSION=${APP_VERSION} \
    BUILD_NOTE=${BUILD_NOTE} \
    APP_ENV=production \
    PORT=8000

WORKDIR ${APP_HOME}

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
apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
if [ -s /run/secrets/netskope_cert ]; then
  rm -f /usr/local/share/ca-certificates/netskope.crt
  mv /tmp/ca-bundle.orig /etc/ssl/certs/ca-certificates.crt
fi
EOF

COPY src/requirements.txt ./requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then export PIP_CERT=/run/secrets/netskope_cert REQUESTS_CA_BUNDLE=/run/secrets/netskope_cert; fi
pip install --no-cache-dir -r requirements.txt
EOF

# Demo only: BuildKit mounts the secret for this step without storing it as ARG/ENV.
# The following pattern is intentionally shown because `cat /run/secrets/mysecret > /tmp/secret_used.txt`
# is a common demonstration of an ephemeral secret mount.
RUN --mount=type=secret,id=mysecret,required=false \
    sh -c 'if [ -f /run/secrets/mysecret ]; then cat /run/secrets/mysecret > /tmp/secret_used.txt && rm -f /tmp/secret_used.txt; else echo "No build secret supplied; continuing demo build."; fi'

COPY src ./src

RUN useradd --create-home --shell /usr/sbin/nologin appuser \
    && mkdir -p ${APP_HOME}/data \
    && chown -R appuser:appuser ${APP_HOME}

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:8000/health || exit 1

CMD ["gunicorn", "--chdir", "src", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "--timeout", "60", "app:app"]
