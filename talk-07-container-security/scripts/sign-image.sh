#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-myregistry/myapp:latest}"
SBOM_FILE="${2:-sbom.json}"

cat <<'INFO'
Install tools first if needed:
  cosign: https://docs.sigstore.dev/cosign/system_config/installation/
  syft:   https://github.com/anchore/syft#installation
INFO

if ! command -v cosign >/dev/null 2>&1; then
  echo "cosign is required." >&2
  exit 1
fi

if ! command -v syft >/dev/null 2>&1; then
  echo "syft is required." >&2
  exit 1
fi

echo "[1/7] Generate a local key pair"
cosign generate-key-pair

echo "[2/7] Sign the image"
cosign sign --key cosign.key "$IMAGE"

echo "[3/7] Verify the image signature"
cosign verify --key cosign.pub "$IMAGE"

echo "[4/7] Generate a CycloneDX JSON SBOM"
syft "$IMAGE" -o cyclonedx-json > "$SBOM_FILE"

echo "[5/7] Attach the SBOM as an OCI artifact"
cosign attach sbom --sbom "$SBOM_FILE" "$IMAGE"

echo "[6/7] Verify attached attestations or SBOM-related metadata"
cosign verify-attestation --key cosign.pub "$IMAGE"

echo "[7/7] Done. Review $SBOM_FILE and stored signatures in the registry."
