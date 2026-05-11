#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="talk-02-runtime-config"
NETWORK_NAME="mynetwork"
VOLUME_NAME="mydata"
CONTAINER_NAME="runtime-config-demo"

run_or_echo() {
  echo "+ $*"
  if [[ "${RUN_EXAMPLES:-0}" == "1" ]]; then
    eval "$*"
  fi
}

cat <<'INTRO'
Container Runtime Configuration examples

By default this script prints the commands so you can talk through them safely.
Set RUN_EXAMPLES=1 to execute the commands.
INTRO

# 1) Basic run with inline environment variables.
# This is the fastest way to inject a few values at container start time.
run_or_echo "docker run --rm --name ${CONTAINER_NAME} -p 8000:8000 -e DB_HOST=host.docker.internal -e DB_PORT=5432 -e DB_NAME=myapp -e DB_USER=myuser -e APP_SECRET_KEY=runtime-secret -e APP_ENV=development ${IMAGE_NAME}"

# 2) Run with an env file.
# This keeps longer configuration sets readable and reusable.
run_or_echo "docker run --rm --name ${CONTAINER_NAME} -p 8000:8000 --env-file .env ${IMAGE_NAME}"

# 3) Build with a secret using BuildKit.
# The secret is mounted only for the matching RUN step and is not intended to persist in the image.
run_or_echo "DOCKER_BUILDKIT=1 docker build --secret id=mysecret,src=secret.txt -t ${IMAGE_NAME} ."

# 4a) Create a user-defined bridge network.
# User-defined bridges provide automatic DNS resolution between attached containers.
run_or_echo "docker network create ${NETWORK_NAME}"

# 4b) Run the Flask app on the shared network.
run_or_echo "docker run -d --rm --name runtime-api --network ${NETWORK_NAME} --env-file .env -p 8000:8000 ${IMAGE_NAME}"

# 4c) Run a second container on the same network and resolve the first by name.
# The ping proves Docker DNS works on a user-defined bridge.
run_or_echo "docker run --rm --network ${NETWORK_NAME} busybox:1.36 ping -c 1 runtime-api"

# 4d) Host networking removes the container/host network boundary.
# On Docker Desktop this behaves differently than native Linux, so explain the platform caveat.
run_or_echo "docker run --rm --network=host --env-file .env ${IMAGE_NAME}"

# 4e) Network none starts the container with no external network access.
run_or_echo "docker run --rm --network=none --env-file .env ${IMAGE_NAME}"

# 5) Bind mount a host directory into the container.
# This is useful when you want direct visibility into files on the host.
run_or_echo "mkdir -p data"
run_or_echo "docker run --rm --env-file .env -v \"$(pwd)/data:/app/data\" ${IMAGE_NAME}"

# 6) Use a named volume managed by Docker.
# Volumes survive container recreation without depending on a specific host path.
run_or_echo "docker volume create ${VOLUME_NAME} && docker run --rm --env-file .env -v ${VOLUME_NAME}:/app/data ${IMAGE_NAME}"

# 7) Mount a tmpfs filesystem.
# This creates fast, in-memory temporary storage that disappears when the container stops.
run_or_echo "docker run --rm --env-file .env --tmpfs /tmp:size=100m ${IMAGE_NAME}"

# 8) Apply resource limits.
# These limits protect the host and demonstrate container-level scheduling controls.
run_or_echo "docker run --rm --env-file .env --memory=256m --cpus=0.5 ${IMAGE_NAME}"

# 9) Configure a restart policy.
# `unless-stopped` is a common operational default for long-running services.
run_or_echo "docker run -d --name restart-demo --restart=unless-stopped --env-file .env ${IMAGE_NAME}"

cat <<'OUTRO'

Cleanup examples you can run later:
  docker rm -f runtime-api restart-demo 2>/dev/null || true
  docker network rm mynetwork 2>/dev/null || true
  docker volume rm mydata 2>/dev/null || true
OUTRO
