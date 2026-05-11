#!/bin/bash
# Build Rust code targeting wasm32-wasi
cd spin-app
rustup target add wasm32-wasi
cargo build --target wasm32-wasi --release

# Show the resulting Wasm binary size
echo "Wasm binary size:"
ls -lh target/wasm32-wasi/release/hello_spin.wasm

# For comparison, build the traditional .NET app
cd ../traditional-app
docker build -t talk-13-traditional .
docker images talk-13-traditional

echo "Compare sizes! Wasm binary vs Docker image..."
