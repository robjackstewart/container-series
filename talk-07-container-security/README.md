# Talk 07 — Container Security

This talk demonstrates how to find, interpret, and reduce container image risk using scanners, hardened runtime images, signing, and SBOMs. Language: TypeScript / Express.

## What you'll learn
- How Trivy, Docker Scout, and similar tools surface image and dependency risk.
- How base-image choice, multi-stage builds, and non-root runtimes reduce attack surface.
- How signing, SBOMs, and runtime hardening support a stronger supply-chain story.

## Prerequisites
- Docker Desktop installed and working.
- Node.js and npm for local TypeScript development.
- Trivy installed locally.
- Docker Scout available via Docker Desktop.
- Optional: Cosign and Syft for the supply-chain section.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the TypeScript / Express API used by the images.
- **`scripts/`** — optional helper scripts for Trivy, Docker Scout, signing, and SBOM demos.
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
docker build -f Dockerfile.hardened -t myapp:hardened .
```

## API endpoints
- `GET /health`
- `GET /items`
- `POST /items`
- `GET /items/:id`
- `DELETE /items/:id`

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`**. Every Docker build in this talk trusts it automatically via the `EXTRA_CERTS_DIR` build-arg (default `certs`). Leave `certs/` empty and nothing changes. See the repo root README for the full explanation.

## Next in the series
Talk 08 moves from image hardening into developer environments with dev containers and Codespaces.
