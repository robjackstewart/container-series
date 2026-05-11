#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-myapp:latest}"
VULNERABLE_IMAGE="${2:-myapp:vulnerable}"
HARDENED_IMAGE="${3:-myapp:hardened}"

if ! command -v trivy >/dev/null 2>&1; then
  echo "Trivy is required: https://trivy.dev/latest/getting-started/installation/" >&2
  exit 1
fi

echo "[1/8] Scan a local image"
trivy image "$IMAGE"

echo "[2/8] Filter to high and critical findings"
trivy image --severity HIGH,CRITICAL "$IMAGE"

echo "[3/8] Scan the filesystem for vulnerable dependencies and secrets"
trivy fs .

echo "[4/8] Scan Dockerfiles, Compose files, and other IaC configuration"
trivy config .

echo "[5/8] Produce machine-readable output for automation"
trivy image --format json -o trivy-report.json "$IMAGE"
trivy image --format sarif -o trivy-report.sarif "$IMAGE"

echo "[6/8] Fail a CI job when critical issues are found"
trivy image --exit-code 1 --severity CRITICAL "$IMAGE" || true

echo "[7/8] Apply a local ignore policy"
trivy image --ignorefile .trivyignore "$IMAGE"

echo "[8/8] Compare the intentionally vulnerable and hardened images"
trivy image "$VULNERABLE_IMAGE"
trivy image "$HARDENED_IMAGE"

echo "Reports written to trivy-report.json and trivy-report.sarif"
