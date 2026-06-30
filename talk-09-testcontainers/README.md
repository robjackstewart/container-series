# Talk 09 — Testcontainers

Use Testcontainers.NET to run integration tests against real infrastructure without a shared dev environment. The sample is an ASP.NET Core order API tested with disposable PostgreSQL and Redis containers, with RabbitMQ discussed as the same pattern for broker-backed tests. Language: C# / .NET 8 + xUnit.

## What you'll learn
- How Testcontainers provisions realistic dependencies directly from the test suite.
- How xUnit fixtures, `IAsyncLifetime`, and `WebApplicationFactory` control container lifecycle and app configuration.
- How wait strategies, resource cleanup, and Docker socket access affect reliable local and CI runs.
- Where Testcontainers Cloud, Testcontainers Desktop, reusable containers, and Playwright E2E tests fit.

## Prerequisites
- Docker Desktop installed and running.
- .NET 8 SDK installed.
- Optional: Testcontainers Desktop for observing test containers locally.
- Optional: Testcontainers Cloud access for remote test-container execution.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/OrderApi/`** — the ASP.NET Core minimal API and Dockerfile.
- **`tests/OrderApi.Tests/`** — xUnit tests, Testcontainers fixtures, and `WebApplicationFactory` integration.
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```powershell
dotnet test .\OrderApi.sln
```

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`**. The API Docker build trusts it automatically via the `EXTRA_CERTS_DIR` build-arg (default `certs`). Testcontainers also pulls PostgreSQL, Redis, and optional RabbitMQ images at test time, so Docker Desktop or the Docker host must trust the same corporate CA for registry pulls. Leave `certs/` empty and normal builds are unchanged. See the repo root README for the full explanation.

## Next in the series
Talk 10 moves from test-time dependencies into .NET Aspire and local orchestration for cloud-native development.
