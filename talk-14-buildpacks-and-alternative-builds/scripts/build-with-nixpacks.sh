#!/bin/bash
# Install: curl -sSL https://nixpacks.com/install.sh | bash

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Build Node app with Nixpacks ==="
cd "${ROOT_DIR}/node-app"
nixpacks build . --name node-nixpacks

echo "=== Build Ruby app with Nixpacks ==="
cd "${ROOT_DIR}/ruby-app"
nixpacks build . --name ruby-nixpacks

echo "=== Show nixpacks build plan (what it detected) ==="
nixpacks plan .
