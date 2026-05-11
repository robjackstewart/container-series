#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REGISTRY="${REGISTRY:-docker.io}"
REPO="${REPO:-your-dockerhub-username/talk03-r-plumber}"
IMAGE_TAG="${IMAGE_TAG:-1.0.0}"
ARTIFACT_REPO="${ARTIFACT_REPO:-your-dockerhub-username/talk03-artifacts}"
ARTIFACT_TAG="${ARTIFACT_TAG:-sbom-demo}"
COPY_TARGET="${COPY_TARGET:-ghcr.io/your-org/talk03-r-plumber:${IMAGE_TAG}}"

IMAGE_REF="${REGISTRY}/${REPO}:${IMAGE_TAG}"
ARTIFACT_REF="${REGISTRY}/${ARTIFACT_REPO}:${ARTIFACT_TAG}"
SBOM_PATH="${SCRIPT_DIR}/sample-artifact/sbom.json"
PULL_DIR="${SCRIPT_DIR}/pulled-sbom"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

headline() {
  printf '\n== %s ==\n' "$1"
}

headline "1. ORAS installation check"
need_cmd oras
need_cmd docker
oras version

echo "Using image ref:    ${IMAGE_REF}"
echo "Using artifact ref: ${ARTIFACT_REF}"
headline "2. Push a JSON file as an OCI artifact"
oras push "${ARTIFACT_REF}" \
  "${SBOM_PATH}:application/vnd.example.sbom.v1+json"

headline "3. Pull the artifact back down"
rm -rf "${PULL_DIR}"
mkdir -p "${PULL_DIR}"
oras pull "${ARTIFACT_REF}" -o "${PULL_DIR}"
ls -la "${PULL_DIR}"

headline "4. Attach the SBOM to an existing image"
echo "Ensure ${IMAGE_REF} exists in the registry before running this step."
oras attach "${IMAGE_REF}" \
  "${SBOM_PATH}:application/vnd.cyclonedx+json" \
  --artifact-type application/vnd.cyclonedx+json

headline "5. Discover referrers attached to the image"
oras discover "${IMAGE_REF}"

headline "6. Inspect the image manifest with Docker"
docker manifest inspect "${IMAGE_REF}"

headline "7. Inspect the image remotely with skopeo"
if command -v skopeo >/dev/null 2>&1; then
  skopeo inspect "docker://${IMAGE_REF}"
else
  echo "skopeo not installed; example command:"
  echo "  skopeo inspect docker://${IMAGE_REF}"
fi

headline "8. Copy an image between registries"
if command -v skopeo >/dev/null 2>&1; then
  echo "Copy target: ${COPY_TARGET}"
  skopeo copy "docker://${IMAGE_REF}" "docker://${COPY_TARGET}"
else
  echo "skopeo not installed; example command:"
  echo "  skopeo copy docker://${IMAGE_REF} docker://${COPY_TARGET}"
fi

headline "9. Inspect multi-arch metadata"
if docker buildx imagetools inspect "${IMAGE_REF}"; then
  :
else
  echo "If the image is single-arch or not yet pushed, try a known multi-arch image instead:"
  echo "  docker buildx imagetools inspect docker.io/library/alpine:latest"
fi

headline "Done"
echo "This script demonstrated ORAS push/pull/attach/discover, Docker manifest inspection, skopeo inspection/copy, and buildx imagetools inspection."
