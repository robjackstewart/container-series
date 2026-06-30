# RUNSHEET — Talk 10: .NET Aspire Cloud-Native Orchestration

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Trust the corporate CA on the host OS and Docker daemon first; `certs/` is only a placeholder in this non-Dockerfile talk.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] .NET 9 SDK installed — `dotnet --version`
- [ ] Aspire workload present — `dotnet workload list`
- [ ] Optional cloud stretch ready — `azd version` and `az account show`
- [ ] Optional Ollama bonus ready — `ollama --version`
- [ ] (if behind Netskope) corporate CA trusted by Windows and Docker Desktop
- [ ] Warm the caches — `docker pull redis:latest; docker pull postgres:latest; docker pull rabbitmq:management; dotnet restore .\ContainerSeries.Aspire.sln`
- [ ] Terminal in `talk-10-dotnet-aspire`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```powershell
# 1) Start the full distributed app from the AppHost
dotnet run --project .\ContainerSeries.AppHost\ContainerSeries.AppHost.csproj

# 2) In a second PowerShell terminal, paste the API HTTP endpoint from the Aspire Dashboard
$api = Read-Host 'Paste the API http endpoint from the Aspire Dashboard, for example http://localhost:5123'
Invoke-RestMethod "$api/"
Invoke-RestMethod "$api/health"
Invoke-RestMethod "$api/cache-test"

# 3) Create an order and trigger the API -> OrderService -> PostgreSQL -> RabbitMQ -> NotificationService path
$order = @{ customerName = 'Ada Lovelace'; productName = 'Container course seat'; quantity = 2 } | ConvertTo-Json
Invoke-RestMethod "$api/orders" -Method Post -ContentType 'application/json' -Body $order
Invoke-RestMethod "$api/orders"

# 4) Optional deployment stretch: let azd scaffold and deploy the Aspire app
azd auth login
azd init
azd up
azd deploy

# 5) Optional Ollama bonus: prove the local AI runtime is available before discussing it as another Aspire resource
ollama list
```

## Beat-by-beat talking points
1. Start from the AppHost, not an individual service: this is the orchestration entry point for the whole graph.
2. Open the Aspire Dashboard link printed by `dotnet run`; show Resources first so the room sees projects and dependency containers together.
3. Point at PostgreSQL, Redis, RabbitMQ, pgAdmin, RedisInsight, and RabbitMQ management as host-Docker-managed resources, not Dockerfile builds.
4. Open the API and Web endpoints from the Dashboard. Explain that the external host ports are dynamic, while service-to-service calls use names such as `http://api` and `http://orderservice`.
5. Hit `/cache-test` twice and show Redis changing the API response from generated to cached.
6. Create an order, then show OrderService logs, NotificationService logs, and distributed traces in the Dashboard.
7. Move to metrics and health checks to show that `ServiceDefaults` made observability and `/health` consistent across projects.
8. If showing `azd`, frame it as a deployment bridge that can generate Azure infrastructure assets from the Aspire graph.
9. If showing Ollama, keep it conceptual unless you have a prepared branch: it is another local service that can be orchestrated and observed like the other dependencies.

## If it breaks
- **Docker resources do not start** → confirm Docker Desktop is running: `docker version`.
- **Image pull / x509 / TLS error behind Netskope** → trust the corporate CA in Windows and Docker Desktop, restart Docker, then run the AppHost again. Copying a `.crt` into `certs/` is not enough for this non-Dockerfile talk.
- **Aspire workload missing** → install it with `dotnet workload install aspire`, then rerun the AppHost.
- **Endpoint command fails** → copy the API endpoint from the Aspire Dashboard Resources view again; Aspire chooses dynamic host ports.
- **Order flow fails** → check RabbitMQ and PostgreSQL are healthy in the Dashboard before retrying the POST.
- **`azd init` creates files you do not want to keep** → treat them as disposable demo output unless you are intentionally turning the talk into a deployable sample.
- **Ollama is unavailable** → skip the bonus; the core Aspire orchestration story is complete without it.

## Reset / cleanup
```powershell
# Stop the AppHost with Ctrl+C in the terminal running dotnet.
# Optional: remove stopped containers and unused Aspire demo resources after the session.
docker container prune -f
docker volume prune -f
```
