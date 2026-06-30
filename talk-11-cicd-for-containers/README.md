# Talk 11 — CI/CD for Containers

Build, test, scan, publish, sign, and deploy a small containerised API through modern CI/CD patterns. Language: Python / FastAPI.

> GitHub only discovers workflows from the repository root `.github/workflows/` directory. The workflow files in this talk folder are teaching artefacts; copy them to the root `.github/workflows/` directory to activate them in GitHub.

## What you'll learn
- How GitHub Actions and Azure Pipelines build, test, scan, and publish container images.
- How Buildx, QEMU, Bake, cache strategy, and multi-architecture manifests fit into CI.
- How OIDC, Cosign, SBOMs, provenance attestations, and GitOps strengthen the delivery chain.

## Prerequisites
- Docker Desktop installed and running.
- Python 3.12+ for local tests and development.
- Azure CLI and access to an Azure Container Registry / Azure Container Apps environment for cloud demos.
- Optional: `gh`, Cosign, Trivy, and hadolint for the CI/CD and supply-chain walkthroughs.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the FastAPI application used by the image and pipelines.
- **`tests/`** — pytest coverage for the API routes.
- **`.github/workflows/`** — GitHub Actions teaching workflows for CI, CD, and multi-arch builds.
- **`azure-pipelines/`** — Azure Pipelines equivalents for CI, CD, and multi-arch builds.
- **`docker-bake.hcl`** — declarative Buildx Bake target for repeatable image builds.
- **`scripts/`** — helper script for Azure Container Apps deployment.
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```powershell
docker build -t talk-11-fastapi:dev .
```

## API endpoints
- `GET /`
- `GET /health`
- `GET /items`
- `POST /items`
- `GET /items/{id}`
- `DELETE /items/{id}`

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`**. Every Docker build in this talk trusts it automatically via the `EXTRA_CERTS_DIR` build-arg (default `certs`). Leave `certs/` empty and nothing changes. See the repo root README for the full explanation.

## Next in the series
Talk 12 moves from CI/CD pipelines into Kubernetes, Helm, and AKS deployment patterns.
