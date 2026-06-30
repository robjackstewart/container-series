# Talk 13 — WebAssembly Containers

Build and compare a Rust WebAssembly HTTP component with a traditional .NET 8 container, then place both in the Docker and Kubernetes runtime story. Language: Rust / Fermyon Spin / C# / .NET 8.

## What you'll learn
- How WASI lets WebAssembly workloads access host capabilities without exposing a full operating-system surface.
- How Fermyon Spin packages HTTP handlers as lightweight Wasm components.
- Where Wasm containers fit beside traditional OCI containers, Docker runtimes, and SpinKube.

## Prerequisites
- Docker Desktop installed and running, with Wasm support enabled for Docker + Wasm demos.
- Rust toolchain installed, including the `wasm32-wasi` target.
- Fermyon Spin CLI installed.
- .NET 8 SDK installed for the traditional app.
- Optional: `kubectl` and a Kubernetes cluster with SpinKube installed.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`spin-app/`** — Rust + Spin HTTP component targeting `wasm32-wasi`.
- **`traditional-app/`** — .NET 8 minimal API and Dockerfile for the container comparison.
- **`k8s/`** — SpinKube RuntimeClass and deployment examples.
- **`scripts/`** — optional helper scripts for building and Docker + Wasm demos.
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).
- **`traditional-app/certs/`** — same certificate placeholder for the traditional app's Docker build context.

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
cd spin-app && spin build && spin up
```

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`** for the talk notes and into **`traditional-app/certs/`** for the .NET Docker build, because that Dockerfile is built with `traditional-app/` as its build context. The Dockerfile trusts it automatically via the `EXTRA_CERTS_DIR` build-arg (default `certs`). Spin builds, pulls, and Wasm OCI registry operations use the host trust store, so also trust the CA at the OS and Docker Desktop level. See the repo root README for the full explanation.

## Next in the series
Talk 14 moves from Wasm into Dockerfile-free image builders such as Buildpacks, ko, Jib, and Nixpacks.
