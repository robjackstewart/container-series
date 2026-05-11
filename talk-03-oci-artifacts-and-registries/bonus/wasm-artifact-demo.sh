#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SAMPLE_DIR="${ROOT_DIR}/sample-artifact"

REGISTRY="${REGISTRY:-docker.io}"
REPO="${REPO:-your-dockerhub-username/talk03-wasm-demo}"
TAG="${TAG:-0.1.0}"
WASM_REF="${REGISTRY}/${REPO}:${TAG}"
CONFIG_REF="${REGISTRY}/${REPO}-config:2025-01-15"
WASM_FILE="${WASM_FILE:-${SAMPLE_DIR}/hello.wasm}"
WAT_FILE="${SAMPLE_DIR}/hello.wat"
CONFIG_FILE="${ROOT_DIR}/bonus/config.v2025-01-15.json"
LOCAL_OCI_LAYOUT="${ROOT_DIR}/bonus/local-oci"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

section() {
  printf '\n== %s ==\n' "$1"
}

need_cmd oras
section "1. Push a Wasm binary as an OCI artifact"
if [[ ! -f "${WASM_FILE}" ]]; then
  if command -v wat2wasm >/dev/null 2>&1; then
    cat > "${WAT_FILE}" <<'WAT'
(module
  (func (export "run") (result i32)
    i32.const 42))
WAT
    wat2wasm "${WAT_FILE}" -o "${WASM_FILE}"
  else
    echo "No Wasm file found at ${WASM_FILE} and wat2wasm is unavailable." >&2
    echo "Provide WASM_FILE=/path/to/module.wasm or install wabt." >&2
    exit 1
  fi
fi

oras push "${WASM_REF}" \
  "${WASM_FILE}:application/wasm"

section "2. Pull the Wasm artifact and run it with wasmtime"
oras pull "${WASM_REF}" -o "${ROOT_DIR}/bonus/pulled-wasm"
if command -v wasmtime >/dev/null 2>&1; then
  wasmtime "${ROOT_DIR}/bonus/pulled-wasm/$(basename "${WASM_FILE}")"
else
  echo "wasmtime not installed; example command:"
  echo "  wasmtime ${ROOT_DIR}/bonus/pulled-wasm/$(basename "${WASM_FILE}")"
fi

section "3. Use ORAS as a versioned config registry"
cat > "${CONFIG_FILE}" <<'JSON'
{
  "featureFlag": true,
  "modelVersion": "2025-01-15",
  "trafficPercentage": 25,
  "notes": "Example config blob stored as an OCI artifact"
}
JSON
oras push "${CONFIG_REF}" \
  "${CONFIG_FILE}:application/vnd.example.config.v1+json"

section "4. Copy an image into a local OCI layout with skopeo"
if command -v skopeo >/dev/null 2>&1; then
  mkdir -p "${LOCAL_OCI_LAYOUT}"
  skopeo copy "docker://${WASM_REF}" "oci:${LOCAL_OCI_LAYOUT}:${TAG}"
else
  echo "skopeo not installed; example command:"
  echo "  skopeo copy docker://${WASM_REF} oci:${LOCAL_OCI_LAYOUT}:${TAG}"
fi

section "Done"
echo "This script showed Wasm push/pull, wasmtime execution, versioned config blobs, and copying into a local OCI layout."
