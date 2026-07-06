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
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```powershell
dotnet test .\OrderApi.sln
```

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`**. Build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the API image build — the cert is not stored in any image layer. Testcontainers also pulls PostgreSQL, Redis, and optional RabbitMQ images at test time, so Docker Desktop or the Docker host must also trust the same corporate CA for registry pulls. See the repo root README for the full explanation.

## Next in the series
Talk 10 moves from test-time dependencies into .NET Aspire and local orchestration for cloud-native development.
