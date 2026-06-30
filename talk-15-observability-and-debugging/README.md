# Talk 15 — Observability and Debugging

Run an Elixir / Phoenix API with a complete local observability stack, then practise debugging live and minimal containers. Language: Elixir / Phoenix.

## What you'll learn
- How traces, metrics, and structured logs work together in a containerised service.
- How the OpenTelemetry Collector decouples application instrumentation from Jaeger, Prometheus, Loki, and Grafana.
- How `docker debug`, `kubectl debug`, and ephemeral containers change the debugging story for slim images.

## Prerequisites
- Docker Desktop installed and running, with Docker Compose v2.
- `curl` for endpoint checks and load generation.
- Optional: `jq`, `kubectl`, and Docker Desktop with `docker debug` support.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the Elixir / Phoenix JSON API with OpenTelemetry and Prometheus instrumentation.
- **`compose.yaml`**, **`otel-collector-config.yaml`**, **`prometheus.yml`**, **`fluent-bit.conf`**, **`grafana/`** — the observability stack.
- **`scripts/`** — optional helper scripts for stack setup and debugging examples.
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
docker compose up -d --build
```

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`**. Every Docker build in this talk trusts it automatically via the `EXTRA_CERTS_DIR` build-arg (default `certs`). Leave `certs/` empty and nothing changes. See the repo root README for the full explanation.

## Next in the series
This is the final talk: use it as the operational wrap-up that connects image design, runtime behaviour, and production support.
