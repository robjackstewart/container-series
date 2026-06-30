# Talk 02 — Runtime Configuration

Run the same Flask image with realistic runtime configuration: environment variables, secret-safe builds, networking modes, storage choices, health checks, restart behaviour, and resource limits. Language: Python / Flask.

## What you'll learn
- How image defaults, runtime environment variables, and env files work together.
- Why secrets belong outside `ARG` and `ENV`, and how BuildKit secret mounts help during builds.
- How networking, storage, health checks, restart policies, and limits shape operational behaviour.

## Prerequisites
- Docker Desktop installed and running.
- Bash-compatible shell for the helper scripts.
- Optional: Python 3.12+ for running the Flask app locally.
- Optional: Podman for the bonus comparison.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the Flask API used by the container image.
- **`bonus/`** — Podman comparison commands and pod concepts.
- **`run-examples.sh`** — printable command reference for the Docker demos.
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
docker build -t talk-02-runtime-config .
```

## API endpoints
- `GET /health`
- `GET /config`
- `GET /items`
- `POST /items`

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`**. Every Docker build in this talk trusts it automatically via the `EXTRA_CERTS_DIR` build-arg (default `certs`). Leave `certs/` empty and nothing changes. See the repo root README for the full explanation.

## Next in the series
Talk 03 moves from single-container runtime knobs into multi-container applications and Compose.
