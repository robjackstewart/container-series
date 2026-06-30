# Talk 10 — .NET Aspire Cloud-Native Orchestration

Use .NET Aspire as the developer orchestration layer for a small distributed .NET 9 application, with projects, backing services, and observability started from one AppHost. Language: C# / .NET 9 Aspire.

## What you'll learn
- How an Aspire AppHost models projects, dependencies, service discovery, and container-backed resources.
- How the Aspire Dashboard brings logs, traces, metrics, endpoints, and health checks into the local inner loop.
- How Aspire bridges local orchestration, dependency containers, optional `azd` deployment, and AI-enabled extensions.

## Prerequisites
- Docker Desktop installed and running.
- .NET 9 SDK installed.
- Aspire workload installed.
- Optional: Azure Developer CLI (`azd`) and Azure CLI for the deployment stretch.
- Optional: Ollama for the local AI bonus.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`ContainerSeries.AppHost/`** — the Aspire orchestration entry point; there is no Dockerfile in this talk.
- **`ContainerSeries.Api/`**, **`ContainerSeries.Web/`**, **`ContainerSeries.OrderService/`**, **`ContainerSeries.NotificationService/`** — the application projects.
- **`ContainerSeries.ServiceDefaults/`** — shared OpenTelemetry, service discovery, resilience, and health defaults.
- **`certs/`** — documentation placeholder for a corporate CA `.crt` if future Dockerfile-based extensions are added.

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```powershell
dotnet run --project .\ContainerSeries.AppHost\ContainerSeries.AppHost.csproj
```

## Behind a TLS-intercepting proxy (Netskope)?
There is no Dockerfile in this talk, so the usual `EXTRA_CERTS_DIR` Docker build pattern does not run here. Aspire asks the host Docker daemon to pull and run dependency containers such as Redis, PostgreSQL, and RabbitMQ, so trust the corporate CA at the host OS and Docker daemon level. See **`notes/README.md`** for the non-Dockerfile workaround.

## Next in the series
Talk 11 moves from local orchestration into CI/CD pipelines for containerised applications.
