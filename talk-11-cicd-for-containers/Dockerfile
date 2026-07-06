# syntax=docker/dockerfile:1.7

FROM python:3.12-slim AS build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

RUN python -m venv "$VIRTUAL_ENV"

COPY src/requirements.txt ./src/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then export PIP_CERT=/run/secrets/netskope_cert REQUESTS_CA_BUNDLE=/run/secrets/netskope_cert; fi
pip install --upgrade pip && pip install -r ./src/requirements.txt
EOF

COPY src ./src
RUN python -m compileall ./src

FROM python:3.12-slim

# Runtime makes no outbound TLS calls in this demo, so no extra corporate CA bundle is copied here.

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000 \
    ENVIRONMENT=production \
    APP_VERSION=0.1.0 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app appuser

COPY --from=build /opt/venv /opt/venv
COPY --from=build /app/src /app/src

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "from urllib.request import urlopen; urlopen('http://127.0.0.1:8000/health', timeout=2).read()" || exit 1

CMD ["sh", "-c", "uvicorn src.main:app --host 0.0.0.0 --port ${PORT}"]
