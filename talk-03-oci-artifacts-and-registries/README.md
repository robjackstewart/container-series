# Talk 03 — OCI Artifacts and Registries

This talk shows how container registries store more than runnable images, using an R / Plumber API as the image and ORAS-managed SBOMs, policies, Wasm modules, and model files as OCI artifacts. Language: R / Plumber.

## What you'll learn
- How the OCI image, distribution, and runtime specifications fit together.
- How to build, tag, push, inspect, attach, and discover registry artifacts.
- How tags, digests, manifest lists, and registry choice affect delivery and traceability.

## Prerequisites
- Docker Desktop installed and running.
- A registry namespace you can push to, such as Docker Hub, GitHub Container Registry, or Azure Container Registry.
- ORAS CLI installed — `oras version`.
- `curl` for API smoke tests.
- Optional: `skopeo`, `wasmtime`, and `wabt` for registry-copy and Wasm bonus demos.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the R / Plumber API and model-training script.
- **`sample-artifact/`** — SBOM and policy payloads used for ORAS artifact demos.
- **`bonus/`** — Wasm, config, and local OCI layout bonus workflow.
- **`oci-artifacts-demo.sh`** — optional scripted version of the main ORAS workflow.
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
docker build -t talk03-r-plumber:local .
```

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`**. Build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation.

## Next in the series
Talk 04 moves from registries into Docker Compose and multi-service orchestration.
