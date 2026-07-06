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
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

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
Save your corporate CA as **`certs/netskope.crt`**. Build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation.

## Next in the series
Talk 08 moves from image hardening into developer environments with dev containers and Codespaces.
