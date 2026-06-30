# Talk 06 — Azure Container Apps

Deploy a Spring Boot HTTP service and scheduled job to Azure Container Apps, then use revisions, traffic splitting, KEDA scaling, scale-to-zero, and Dapr to explain the managed container platform story. Language: Java 21 / Spring Boot.

## What you'll learn
- Where Azure Container Apps fits between Azure App Service and AKS.
- How services, jobs, revisions, traffic splitting, and scale-to-zero work in ACA.
- How KEDA, Dapr, managed identity, secrets, and Log Analytics support production container workloads.

## Prerequisites
- Docker Desktop installed and running.
- Azure CLI installed, with the `containerapp` extension available.
- Azure subscription with permission to create resource groups, ACR, Container Apps, Log Analytics, and managed identities.
- Bash-compatible shell for the supplied commands and `scripts/deploy.sh`.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`service/`** — Spring Boot order service for ACA ingress, revisions, scale rules, and Dapr state.
- **`job/`** — Spring Boot order processor for ACA scheduled jobs.
- **`infra/`** — Bicep deployment for ACR-backed ACA services, jobs, Dapr, and observability.
- **`scripts/`** — helper deployment script for the main demo path.
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
./scripts/deploy.sh
```

## API endpoints
- `GET /health`
- `GET /orders`
- `POST /orders`
- `GET /orders/{id}`
- `PUT /orders/{id}/status`

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`**. Every Docker build in this talk trusts it automatically via the `EXTRA_CERTS_DIR` build-arg (default `certs`). Leave `certs/` empty and nothing changes. See the repo root README for the full explanation.

## Next in the series
Talk 07 moves from managed container platforms into container image security, scanning, signing, SBOMs, and runtime hardening.
