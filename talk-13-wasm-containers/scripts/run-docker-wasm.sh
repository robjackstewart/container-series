#!/bin/bash
# Note: Requires Docker Desktop with containerd image store and Wasm support enabled

# Check Docker Wasm support
docker info | grep -i wasm

# Run a Wasm workload using Docker (after building with spin build or providing a pre-built image)
# Using a public Wasm example image
docker run \
  --runtime=io.containerd.spin.v2 \
  --platform=wasi/wasm \
  ghcr.io/fermyon/spin-hello-world:latest

# Run the traditional container for comparison
docker run -p 8080:8080 talk-13-traditional

# Time comparison script
echo "=== Cold Start Time Comparison ==="
echo "Timing Wasm container start..."
time docker run --runtime=io.containerd.spin.v2 --platform=wasi/wasm --rm ghcr.io/fermyon/spin-hello-world:latest &

echo "Timing traditional container start..."
time docker run --rm -p 8081:8080 talk-13-traditional &
