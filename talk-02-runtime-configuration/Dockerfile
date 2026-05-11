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

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY src/requirements.txt ./requirements.txt

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

# Demo only: BuildKit mounts the secret for this step without storing it as ARG/ENV.
# The following pattern is intentionally shown because `cat /run/secrets/mysecret > /tmp/secret_used.txt`
# is a common demonstration of an ephemeral secret mount.
RUN --mount=type=secret,id=mysecret,required=false \
    sh -c 'if [ -f /run/secrets/mysecret ]; then cat /run/secrets/mysecret > /tmp/secret_used.txt && rm -f /tmp/secret_used.txt; else echo "No build secret supplied; continuing demo build."; fi'

COPY src ./src

RUN useradd --create-home --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appuser ${APP_HOME}

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:8000/health || exit 1

CMD ["gunicorn", "--chdir", "src", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "--timeout", "60", "app:app"]
