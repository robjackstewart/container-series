#!/bin/bash
# Install pack CLI first: https://buildpacks.io/docs/install-pack/

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Building Ruby app with Paketo Buildpacks ==="
cd "${ROOT_DIR}/ruby-app"
pack build ruby-sinatra-app \
  --builder paketobuildpacks/builder-jammy-base:latest \
  --env PORT=4567
docker run -p 4567:4567 ruby-sinatra-app

echo "=== Building Node app with Heroku Buildpacks ==="
cd "${ROOT_DIR}/node-app"
pack build node-app \
  --builder heroku/builder:24 \
  --env PORT=3000

echo "=== Rebase: update OS layer without rebuilding ==="
pack rebase ruby-sinatra-app

echo "=== Generate SBOM from buildpack ==="
pack sbom download ruby-sinatra-app --output-dir "${ROOT_DIR}/sbom-output"
