#!/bin/bash
# Install ko: go install github.com/google/ko@latest

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

export KO_DOCKER_REPO=myregistry.azurecr.io/talk-14

echo "=== Build and push Go app with ko ==="
cd "${ROOT_DIR}/go-app"
ko build .

echo "=== Build without pushing (local) ==="
ko build --local .

echo "=== Apply to Kubernetes (build + deploy in one step!) ==="
# ko apply -f k8s/deployment.yaml  # Would build image and replace image reference

echo "=== ko produces distroless images by default - check the size! ==="
docker images | grep talk-14
