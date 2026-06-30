# RUNSHEET — Talk 01: Container Fundamentals

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — every build trusts it automatically.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] .NET 8 SDK installed — `dotnet --version`
- [ ] Optional layer explorer installed — `dive --version`
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/`
- [ ] Warm the caches — `docker pull mcr.microsoft.com/dotnet/sdk:8.0; docker pull mcr.microsoft.com/dotnet/aspnet:8.0; docker pull golang:1.22-alpine`
- [ ] Terminal in `talk-01-container-fundamentals`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```powershell
# 1) Run the API locally with .NET
$localApi = Start-Process -FilePath dotnet -ArgumentList 'run --project .\src\WeatherApi.csproj --urls http://localhost:5088' -PassThru
Start-Sleep -Seconds 8
Invoke-RestMethod http://localhost:5088/health
Invoke-RestMethod http://localhost:5088/info
Invoke-RestMethod http://localhost:5088/weatherforecast
Stop-Process -Id $localApi.Id

# 2) Build the intentionally simple single-stage image
docker build -t weatherapi:single -f .\Dockerfile .

# 3) Run and smoke-test the single-stage container
docker run --rm -d --name weatherapi-single -p 8080:8080 weatherapi:single
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8080/health
Invoke-RestMethod http://localhost:8080/info
docker logs weatherapi-single
docker stop weatherapi-single

# 4) Build the optimised multi-stage image
docker build -t weatherapi:multi -f .\Dockerfile.multistage --build-arg APP_VERSION=1.0.0 .

# 5) Run and smoke-test the multi-stage container
docker run --rm -d --name weatherapi-multi -p 8080:8080 -e ASPNETCORE_ENVIRONMENT=Production -e APP_VERSION=1.0.0 weatherapi:multi
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8080/health
Invoke-RestMethod http://localhost:8080/info
docker logs weatherapi-multi

# 6) Compare image size and layer history
docker image ls weatherapi
docker history weatherapi:single
docker history weatherapi:multi

# 7) Optional: inspect layers visually with dive
dive weatherapi:multi

# 8) Bonus: build and run the scratch image
docker build -t hello-scratch -f .\bonus\Dockerfile.scratch .\bonus
docker run --rm hello-scratch

# 9) Cleanup
docker stop weatherapi-multi
docker image rm weatherapi:single weatherapi:multi hello-scratch
```

## Beat-by-beat talking points
1. Local run proves the app before Docker enters the conversation; containerisation should not hide app basics.
2. The single-stage build is readable and useful for first principles, but it ships the SDK and build output history.
3. Running the container shows the port mapping boundary: the app listens on 8080 inside, the host chooses what to publish.
4. The multi-stage build separates compilation from execution and keeps only published output in the runtime image.
5. Runtime environment variables demonstrate configuration outside the immutable image.
6. `docker history` makes layers concrete and lets the audience compare the cost of each Dockerfile decision.
7. `dive` is the visual explanation of wasted space, added files, and layer composition.
8. The `scratch` bonus is the extreme endpoint: a container image can be just a binary and metadata.
9. Cleanup keeps the next rehearsal deterministic.

## If it breaks
- **Build can't pull / x509 / TLS error** → corporate CA not trusted: copy `.crt` into `certs/`, then rebuild. (Default `certs/` is empty = no-op.)
- **Port already in use** → stop the previous demo container: `docker stop weatherapi-single weatherapi-multi`.
- **Local API still running** → close the spawned `dotnet` process from the PowerShell process ID captured in `$localApi`.
- **`dive` is missing** → skip the visual layer inspection and use `docker history` for the same concept.
- **Slow first build** → explain base image pulls and NuGet restore, then point out that cache reuse improves subsequent builds.

## Reset / cleanup
```powershell
docker stop weatherapi-single weatherapi-multi 2>$null
docker container prune -f
docker image rm weatherapi:single weatherapi:multi hello-scratch 2>$null
docker image prune -f
```
