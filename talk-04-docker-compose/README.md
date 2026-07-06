# Talk 04 — Docker Compose

Define and run a realistic local stack with Docker Compose: a Go / Gin API, PostgreSQL, Redis, and Nginx, plus development overrides, profiles, test configuration, and a GPU bonus. Language: Go / Gin.

## What you'll learn
- How the Compose specification models services, networks, volumes, health checks, and environment variables.
- How `depends_on` health conditions make multi-service startup more reliable than simple container ordering.
- How profiles, override files, Compose Watch, and scaling support practical local development workflows.

## Prerequisites
- Docker Desktop or Docker Engine with Docker Compose v2.
- Optional: Go 1.22+ if you want to inspect or run the API outside Docker.
- Optional for the bonus: NVIDIA Container Toolkit and a Docker Engine that can expose an NVIDIA GPU.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`api/`** — the Go / Gin API and multi-stage Dockerfile.
- **`db/`** — PostgreSQL schema and seed data.
- **`nginx/`** — reverse-proxy configuration and image wrapper.
- **`compose*.yaml`** — base, development override, and test Compose definitions.
- **`bonus/`** — GPU Compose example for Ollama and Open WebUI.
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```powershell
docker compose up --build
```

## API endpoints
- `GET /health`
- `GET /items`
- `POST /items`
- `GET /items/:id`
- `DELETE /items/:id`
- `GET /cache-stats`

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`**. For `docker build` pass `--secret id=netskope_cert,src=certs/netskope.crt`; for Compose run `NETSKOPE_CERT=./certs/netskope.crt docker compose build` — the cert is not stored in any image layer. Omit the secret when not behind a proxy. See the repo root README for the full explanation.

## Next in the series
Talk 05 moves from local orchestration into Azure Container Registry and App Service deployment.
