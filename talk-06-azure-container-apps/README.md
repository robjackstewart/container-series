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
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

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
Save your corporate CA as **`certs/netskope.crt`**. Build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Set `NETSKOPE_CERT=certs/netskope.crt` before running `scripts/deploy.sh` to pass it automatically. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation.

## Next in the series
Talk 07 moves from managed container platforms into container image security, scanning, signing, SBOMs, and runtime hardening.
