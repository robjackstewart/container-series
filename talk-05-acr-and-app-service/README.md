# Talk 05 — ACR and App Service

Package a Rust + Actix-web API, publish it to Azure Container Registry, and run it on Azure App Service for Containers with managed identity, deployment slots, and Bicep. Language: Rust / Actix-web.

## What you'll learn
- How ACR stores, builds, and governs container images for Azure workloads.
- Why managed identity is safer than registry admin credentials for App Service pulls.
- How Bicep and deployment slots make container releases repeatable and lower risk.

## Prerequisites
- Azure CLI installed and signed in to an Azure subscription.
- Docker Desktop for the optional local build-and-push path.
- Rust toolchain for optional local application development.
- Talks 1-4 completed or understood.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the Rust / Actix-web todo API.
- **`infra/`** — Bicep template and sample parameters for ACR, App Service, and role assignments.
- **`scripts/`** — optional helper scripts for deployment and ACR Tasks.
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
az acr build --registry <acr-name> --image rust-todo-api:latest --file Dockerfile .
```

## API endpoints
- `GET /health`
- `GET /info`
- `GET /todos`
- `POST /todos`
- `GET /todos/{id}`
- `PUT /todos/{id}`
- `DELETE /todos/{id}`

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`**. Build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation.

## Next in the series
Talk 06 moves from App Service into Azure Container Apps and serverless container hosting.
