#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-myapp:latest}"
VULNERABLE_IMAGE="${2:-myapp:vulnerable}"
HARDENED_IMAGE="${3:-myapp:hardened}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for Docker Scout examples." >&2
  exit 1
fi

echo "[1/5] Show image CVEs"
docker scout cves "$IMAGE"

echo "[2/5] Show base image and package upgrade recommendations"
docker scout recommendations "$IMAGE"

echo "[3/5] Compare a vulnerable image with a hardened image"
docker scout compare "$VULNERABLE_IMAGE" "$HARDENED_IMAGE"

echo "[4/5] Quick summary view for demos"
docker scout quickview "$IMAGE"

echo "[5/5] Generate an SBOM from the image"
docker scout sbom "$IMAGE"
