# RUNSHEET — Talk 01: Container Fundamentals

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Export your CA into `certs/netskope.crt` first (see pre-flight) — steps 2–5 turn that
> into a teaching moment rather than a blocker.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] .NET 8 SDK installed — `dotnet --version`
- [ ] Optional layer explorer installed — `dive --version`
- [ ] Warm the caches — `docker pull mcr.microsoft.com/dotnet/sdk:8.0; docker pull mcr.microsoft.com/dotnet/aspnet:8.0; docker pull golang:1.22-alpine`
- [ ] Terminal in `talk-01-container-fundamentals`, large font, speaker-guide closed
- [ ] (if behind Netskope) corporate CA in place — one command, covers every talk:

```powershell
..\scripts\sync-netskope-cert.ps1
```

> Finds the CA automatically (Netskope agent copy, else the Windows store) and drops it into all
> 19 `certs/` folders as `netskope.crt`. Safe to re-run. `certs/*` is git-ignored, so the real
> certificate never gets committed. `-Remove` strips it again.

## Command sequence (copy-paste, in order)
```powershell
# 1) Run the API locally with .NET
$localApi = Start-Process -FilePath dotnet -ArgumentList 'run --project .\src\WeatherApi.csproj --urls http://localhost:5088' -PassThru
Start-Sleep -Seconds 8
Invoke-RestMethod http://localhost:5088/health
Invoke-RestMethod http://localhost:5088/info
Invoke-RestMethod http://localhost:5088/weatherforecast
Stop-Process -Id $localApi.Id

# 2) Build WITHOUT the corporate CA — this FAILS behind Netskope.
#    --no-cache matters: a secret's contents are NOT part of the layer cache key, so a
#    previously cached restore layer would let this build "succeed" and spoil the point.
docker build --no-cache -t weatherapi:nocert -f .\Dockerfile .
#    Expect:
#      error NU1301: Unable to load the service index for source https://api.nuget.org/v3/index.json.

# 3) NU1301 alone is ambiguous — it looks identical to having no network at all.
#    Prove the real cause is TLS trust:
docker run --rm mcr.microsoft.com/dotnet/sdk:8.0 curl -sS https://api.nuget.org/v3/index.json
#    Expect:
#      curl: (60) SSL certificate problem: self-signed certificate in certificate chain

# 4) Build WITH the corporate CA supplied as a BuildKit secret — this SUCCEEDS.
docker build --secret id=netskope_cert,src=.\certs\netskope.crt -t weatherapi:single -f .\Dockerfile .
#    Not behind a TLS-intercepting proxy? Omit --secret; the cert guard is a complete no-op:
#      docker build -t weatherapi:single -f .\Dockerfile .

# 5) Show that trusting the CA did not contaminate the image.
docker run --rm --entrypoint sh weatherapi:single -c "ls -A /usr/local/share/ca-certificates/ | grep -i netskope || echo 'no netskope.crt in image'; ls -A /run/secrets 2>/dev/null || echo 'no /run/secrets in image'"

# 6) Run and smoke-test the single-stage container
docker run --rm -d --name weatherapi-single -p 8080:8080 weatherapi:single
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8080/health
Invoke-RestMethod http://localhost:8080/info
docker logs weatherapi-single
docker stop weatherapi-single

# 7) Build the optimised multi-stage image
docker build --secret id=netskope_cert,src=.\certs\netskope.crt -t weatherapi:multi -f .\Dockerfile.multistage --build-arg APP_VERSION=1.0.0 .

# 8) Run and smoke-test the multi-stage container
docker run --rm -d --name weatherapi-multi -p 8080:8080 -e ASPNETCORE_ENVIRONMENT=Production -e APP_VERSION=1.0.0 weatherapi:multi
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8080/health
Invoke-RestMethod http://localhost:8080/info
docker logs weatherapi-multi

# 9) Compare image size and layer history
docker image ls weatherapi
docker history weatherapi:single
docker history weatherapi:multi

# 10) Optional: inspect layers visually with dive
dive weatherapi:multi

# 11) Bonus: build and run the scratch image
docker build -t hello-scratch -f .\bonus\Dockerfile.scratch .\bonus
docker run --rm hello-scratch

# 12) Cleanup
docker stop weatherapi-multi
docker image rm weatherapi:single weatherapi:multi weatherapi:nocert hello-scratch 2>$null
```

## Beat-by-beat talking points
1. Local run proves the app before Docker enters the conversation; containerisation should not hide app basics.
2. **The failing build is the point.** `dotnet restore` is a *network* step, and it runs inside the builder — not on your laptop. Your host already trusts the Netskope CA, which is why `dotnet restore` works in your terminal and fails three feet away inside the container. The build has its own trust store, inherited from the base image, and Microsoft does not ship your company's CA in it.
3. `curl` narrows "it can't reach nuget.org" down to "it reached nuget.org and refused the certificate". Netskope terminates the TLS connection and re-signs it with its own CA, so from the container's point of view a stranger is impersonating nuget.org — and refusing that is TLS working correctly, not a bug.
4. The fix is not `--trust-any-cert` or baking the CA into a layer. `--mount=type=secret` exposes the cert at `/run/secrets/netskope_cert` for the lifetime of that one `RUN`, and the guard restores the original trust bundle before the layer is committed.
5. Prove the cleanliness claim rather than asserting it: no `netskope.crt`, no `/run/secrets`. Contrast with `COPY netskope.crt` — that ships your interception CA to anyone who pulls the image, and `docker history` would show it.
6. The single-stage build is readable and useful for first principles, but it ships the SDK and build output history.
7. Running the container shows the port mapping boundary: the app listens on 8080 inside, the host chooses what to publish.
8. The multi-stage build separates compilation from execution and keeps only published output in the runtime image.
9. Runtime environment variables demonstrate configuration outside the immutable image.
10. `docker history` makes layers concrete and lets the audience compare the cost of each Dockerfile decision.
11. `dive` is the visual explanation of wasted space, added files, and layer composition.
12. The `scratch` bonus is the extreme endpoint: a container image can be just a binary and metadata.
13. Cleanup keeps the next rehearsal deterministic.

## If it breaks
- **`/bin/sh: 1: set: Illegal option -`** → the Dockerfile heredoc has CRLF line endings. `.gitattributes` forces `eol=lf`, but files checked out *before* it landed keep CRLF. Check with `git ls-files --eol .\Dockerfile` (`w/crlf` is the tell) and fix with `git rm --cached -r .; git reset --hard` from the repo root on a clean tree.
- **`NU1301` / x509 / TLS error** → that's step 2 working as designed. Supply the CA: `--secret id=netskope_cert,src=.\certs\netskope.crt`.
- **`failed to stat .\certs\netskope.crt`** → the secret source file doesn't exist. Run the pre-flight export, or drop `--secret` entirely if you're off the corporate network.
- **Step 2 unexpectedly succeeds** → either you're not behind the proxy (fine — narrate the expected output instead), or you dropped `--no-cache` and hit a cached restore layer.
- **Port already in use** → stop the previous demo container: `docker stop weatherapi-single weatherapi-multi`.
- **Local API still running** → close the spawned `dotnet` process from the PowerShell process ID captured in `$localApi`.
- **`dive` is missing** → skip the visual layer inspection and use `docker history` for the same concept.
- **Slow first build** → explain base image pulls and NuGet restore, then point out that cache reuse improves subsequent builds.

## Reset / cleanup
```powershell
docker stop weatherapi-single weatherapi-multi 2>$null
docker container prune -f
docker image rm weatherapi:single weatherapi:multi weatherapi:nocert hello-scratch 2>$null
docker image prune -f
```
