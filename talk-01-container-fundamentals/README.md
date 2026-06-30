# Talk 01 — Container Fundamentals

Build a first container image for a small ASP.NET Core minimal API, then improve it from an intentionally simple single-stage image to a smaller multi-stage runtime image. Language: C# / .NET 8 minimal API.

## What you'll learn
- How containers differ from virtual machines, and how Docker turns a build context into an image.
- Why Dockerfile ordering, image layers, cache reuse, and `.dockerignore` matter.
- How multi-stage builds reduce image size and separate build tooling from runtime execution.

## Prerequisites
- Docker Desktop installed and running.
- .NET 8 SDK installed.
- Optional: `curl` or `Invoke-RestMethod` for endpoint checks.
- Optional: [`dive`](https://github.com/wagoodman/dive) for exploring image layers.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the ASP.NET Core minimal API.
- **`Dockerfile`** — the intentionally simple single-stage image.
- **`Dockerfile.multistage`** — the optimised multi-stage image.
- **`bonus/`** — a tiny Go binary packaged from `scratch`.
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```powershell
docker build -t weatherapi:multi -f .\Dockerfile.multistage --build-arg APP_VERSION=1.0.0 .
```

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`**. Every Docker build in this talk trusts it automatically via the `EXTRA_CERTS_DIR` build-arg (default `certs`). Leave `certs/` empty and nothing changes. See the repo root README for the full explanation.

## Next in the series
Talk 02 moves from image fundamentals into runtime configuration: ports, environment variables, secrets, and configuration boundaries.
