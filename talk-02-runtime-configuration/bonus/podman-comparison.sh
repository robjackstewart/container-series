#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="talk-02-runtime-config"
REGISTRY_IMAGE="quay.io/example/${IMAGE_NAME}:latest"
POD_NAME="runtime-config-pod"

cat <<'INFO'
Podman vs Docker quick comparison

Podman is daemonless and supports rootless containers as a first-class workflow.
Many day-to-day commands are intentionally Docker-compatible.
INFO

# docker run -> podman run
# Rootless Podman lets an unprivileged user start containers without a central daemon.
echo "podman run --rm -p 8000:8000 --env-file .env ${IMAGE_NAME}"

# docker build -> podman build
echo "podman build -t ${IMAGE_NAME} ."

# docker push -> podman push
echo "podman push ${IMAGE_NAME} ${REGISTRY_IMAGE}"

# Unique Podman concept: pods.
# A pod shares networking and can be managed as a unit, which maps neatly to Kubernetes ideas.
echo "podman pod create --name ${POD_NAME} -p 8000:8000"
echo "podman run -d --pod ${POD_NAME} --env-file .env ${IMAGE_NAME}"

# `podman generate kube` can export Kubernetes YAML from running containers or pods.
# This is a convenient bridge between local container experiments and Kubernetes manifests.
echo "podman generate kube ${POD_NAME} > podman-generated-pod.yaml"

cat <<'NOTES'

Notes:
- If your workflow is simple, many developers use `alias docker=podman` for familiar commands.
- Rootless Podman reduces the need to grant broad daemon-level privileges.
- Podman Desktop is a useful GUI companion if you want a desktop experience similar to Docker Desktop.
NOTES
