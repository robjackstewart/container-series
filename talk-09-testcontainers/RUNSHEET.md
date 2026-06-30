# RUNSHEET — Talk 09: Testcontainers

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — Docker builds trust it automatically, and Docker Desktop/your Docker host must also trust it for Testcontainers image pulls.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] .NET 8 SDK installed — `dotnet --version`
- [ ] Optional: Testcontainers Desktop running for visual inspection.
- [ ] Optional: Testcontainers Cloud agent installed if you plan to show remote execution.
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/` and Docker Desktop/host trust store updated for registry pulls.
- [ ] Warm the caches — `docker pull postgres:16-alpine; docker pull redis:7-alpine; docker pull rabbitmq:3-management-alpine; dotnet restore .\OrderApi.sln`
- [ ] Terminal in `talk-09-testcontainers`, large font, speaker-guide closed.

## Command sequence (copy-paste, in order)
```powershell
# 1) Start real local dependencies for the API demo
Set-Location .
docker rm -f orderapi-postgres orderapi-redis 2>$null
docker run --rm -d --name orderapi-postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=orders -p 5432:5432 postgres:16-alpine
docker run --rm -d --name orderapi-redis -p 6379:6379 redis:7-alpine
Start-Sleep -Seconds 8

# 2) Run the ASP.NET Core API against those real dependencies
$env:ConnectionStrings__Postgres = 'Host=localhost;Port=5432;Database=orders;Username=postgres;Password=postgres'
$env:ConnectionStrings__Redis = 'localhost:6379'
$env:ASPNETCORE_URLS = 'http://localhost:5089'
$api = Start-Process -FilePath dotnet -ArgumentList 'run --project .\src\OrderApi\OrderApi.csproj' -PassThru
Start-Sleep -Seconds 10
Invoke-RestMethod http://localhost:5089/health

# 3) Smoke-test the order API and show database + cache behaviour through HTTP
$orderBody = @{ customerName = 'Ada Lovelace'; product = 'USB-C Dock'; quantity = 2; totalPrice = 189.50; status = 'Pending' } | ConvertTo-Json
$created = Invoke-RestMethod -Method Post -Uri http://localhost:5089/orders -ContentType 'application/json' -Body $orderBody
Invoke-RestMethod http://localhost:5089/orders
Invoke-RestMethod "http://localhost:5089/orders/$($created.id)"
Invoke-RestMethod "http://localhost:5089/orders/$($created.id)"  # second read should hit the Redis-backed cache path

# 4) Stop the manual API demo before the Testcontainers section
Stop-Process -Id $api.Id
docker rm -f orderapi-postgres orderapi-redis
Remove-Item Env:\ConnectionStrings__Postgres, Env:\ConnectionStrings__Redis, Env:\ASPNETCORE_URLS -ErrorAction SilentlyContinue

# 5) Run the integration tests; PostgreSQL and Redis containers appear and disappear automatically
$containerWatcher = Start-Job -ScriptBlock {
    1..25 | ForEach-Object {
        docker ps --filter "label=org.testcontainers=true" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
        Start-Sleep -Seconds 2
    }
}
dotnet test .\OrderApi.sln --logger "console;verbosity=minimal"
Receive-Job $containerWatcher -Wait
Remove-Job $containerWatcher
docker ps -a --filter "label=org.testcontainers=true" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# 6) Optional: build the API image to show the Dockerfile's build-stage certificate wiring
docker build -t orderapi:testcontainers -f .\src\OrderApi\Dockerfile .

# 7) Optional: Testcontainers Cloud, if the agent and token are available
$env:TESTCONTAINERS_CLOUD_TOKEN = '<token-from-your-Testcontainers-Cloud-account>'
$tcc = Start-Process -FilePath testcontainers-cloud -ArgumentList 'agent start' -PassThru
Start-Sleep -Seconds 10
dotnet test .\OrderApi.sln --logger "console;verbosity=minimal"
Stop-Process -Id $tcc.Id
Remove-Item Env:\TESTCONTAINERS_CLOUD_TOKEN -ErrorAction SilentlyContinue
```

## Beat-by-beat talking points
1. The manual API run is deliberately old-fashioned: start PostgreSQL and Redis yourself so the room sees the dependency problem before Testcontainers solves it.
2. The environment variables prove the app only needs normal configuration; it does not need to know whether dependencies are manual, shared, or test-owned.
3. The HTTP smoke test shows persistence and cache paths through the actual ASP.NET Core pipeline.
4. Stopping the manual containers resets the room's mental model: the next section should not rely on anything pre-existing.
5. As `dotnet test` runs, point out the provider images, dynamic ports, fixture lifetime, labels, and cleanup. The watcher is there to make ephemeral containers visible.
6. The optional Docker build is not the point of the talk; use it only to show where the corporate CA trust pattern sits before NuGet restore.
7. Testcontainers Cloud is the CI/laptop escape hatch: the tests stay the same while container execution moves away from the local Docker engine.

## Bonus talking points
- Open Testcontainers Desktop while the watcher is running to inspect container names, logs, port mappings, and cleanup.
- Reusable containers need both user-level opt-in (`testcontainers.reuse.enable=true`) and code-level reuse configuration. Keep that as a local-development optimisation, not a CI default.
- A Playwright E2E version would reuse the same pattern: start real dependencies, boot the app against their connection strings, then drive the browser against the running app.
- RabbitMQ follows the same pattern as PostgreSQL and Redis: start a broker container, wait for AMQP readiness, inject the URI, then assert publish/consume behaviour.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. For Testcontainers image pulls, also add the CA to Docker Desktop or the Docker host trust store; the Dockerfile does not affect daemon-level registry pulls.
- **Testcontainers fails before tests start** → is Docker running, and can the test process access the Docker socket/named pipe?
- **CI cannot find Docker** → mount the Docker socket, use a supported Docker-in-Docker setup, or run through Testcontainers Cloud.
- **Port already in use during the manual API demo** → stop local PostgreSQL/Redis or change the host ports before starting the manual containers.
- **Tests are slow on first run** → explain image pulls. Warm `postgres:16-alpine` and `redis:7-alpine` before the session.
- **Containers remain after a cancelled run** → inspect labels with `docker ps -a --filter "label=org.testcontainers=true"` and remove only the leftover demo containers.
- **Testcontainers Cloud command is missing** → skip that optional section; the local Docker run is the core demo.

## Reset / cleanup
```powershell
if ($api) { Stop-Process -Id $api.Id -ErrorAction SilentlyContinue }
if ($tcc) { Stop-Process -Id $tcc.Id -ErrorAction SilentlyContinue }
docker rm -f orderapi-postgres orderapi-redis 2>$null
docker ps -aq --filter "label=org.testcontainers=true" | ForEach-Object { docker rm -f $_ }
docker image rm orderapi:testcontainers 2>$null
Remove-Item Env:\ConnectionStrings__Postgres, Env:\ConnectionStrings__Redis, Env:\ASPNETCORE_URLS, Env:\TESTCONTAINERS_CLOUD_TOKEN -ErrorAction SilentlyContinue
```
