# RUNSHEET — Talk 01: Container Fundamentals

> One-page cue card. Keep it on your **private** screen; share the deck + terminal.
> Deck: [`slides/talk-01.html`](./slides/talk-01.html) · Narrative: [`notes/README.md`](./notes/README.md)
> Behind Netskope? Put your CA in `certs/netskope.crt` first (see pre-flight) — **slides 13–18 turn that
> into a teaching moment rather than a blocker.**

## How to drive this talk

The deck is the spine. It shows the **slide number** bottom-right and the **section** top-right;
every heading below names the slide it belongs to, so you can always find your place.
Press <kbd>O</kbd> in the deck for a clickable index, <kbd>→</kbd>/<kbd>space</kbd> to advance.

| You are on slide | Do this |
| --- | --- |
| 1–6 | Talk only. No terminal. |
| **7** | **Demo 1** — run the API with plain `dotnet run` |
| 8–15 | Talk only. Slides 13–15 set up the failure. |
| **16** | **Demo 2** — the five-beat certificate demo (the centrepiece) |
| 17–22 | Talk only. Slide 20 is the layer diagram. |
| **23** | **Demo 3** — `docker history`, optionally `dive` |
| 24–28 | Talk only. |
| **29** | **Demo 4** — build multi-stage, override at runtime, compare sizes |
| 30–32 | Talk only. |
| **33** | **Demo 5** — `dive` + the `scratch` bonus |
| 34–36 | Discussion, takeaways, handover to Talk 02 |

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] .NET 8 SDK installed — `dotnet --version`
- [ ] Optional layer explorer installed — `dive --version`
- [ ] Warm the caches — `docker pull mcr.microsoft.com/dotnet/sdk:8.0; docker pull mcr.microsoft.com/dotnet/aspnet:8.0; docker pull golang:1.22-alpine`
- [ ] Terminal in `talk-01-container-fundamentals`, large font, speaker guide closed
- [ ] Deck open at slide 1 in a second window — `.\slides\talk-01.html`
- [ ] (if behind Netskope) corporate CA in place — one command, covers every talk:

```powershell
..\scripts\sync-netskope-cert.ps1
```

> Finds the CA automatically (the Netskope agent's own copy at
> `%ProgramData%\netskope\stagent\data\nscacert.pem` first, since that stays current through a CA
> rotation; else the Windows root store) and writes it as `netskope.crt` into all 19 `certs/` folders.
> Safe to re-run — identical files are left alone and a *different* cert is reported rather than
> overwritten unless you pass `-Force`. `-WhatIf` previews; `-Remove` strips it again.
> `certs/*` is git-ignored, so the real certificate is never committed.

---

## Demo 1 — slide 7 · prove the app works without Docker

```powershell
$localApi = Start-Process -FilePath dotnet -ArgumentList 'run --project .\src\WeatherApi.csproj --urls http://localhost:5088' -PassThru
Start-Sleep -Seconds 8
Invoke-RestMethod http://localhost:5088/health
Invoke-RestMethod http://localhost:5088/info
Invoke-RestMethod http://localhost:5088/weatherforecast
Stop-Process -Id $localApi.Id
```

**Say:** containerisation should not hide app basics. Note `version : dev` in `/info` — you will pull that
thread again on slides 25 and 29.

---

## Demo 2 — slide 16 · the deliberate failure (five beats)

**Beat 1 — build with no certificate.** Ask the room why before you say anything.

```powershell
docker build --no-cache -t weatherapi:nocert -f .\Dockerfile .
#  Expect: error NU1301: Unable to load the service index for source https://api.nuget.org/v3/index.json
```

> `--no-cache` is **mandatory**. A secret mount's *contents* are not part of the layer cache key — only the
> declaration is — so with a warm cache this build succeeds without the cert and spoils the whole demo.

**Beat 2 — narrow it down inside the same base image.** Network, or certificate?

```powershell
docker run --rm mcr.microsoft.com/dotnet/sdk:8.0 curl -sS https://api.nuget.org/v3/index.json
#  Expect: curl: (60) SSL certificate problem: self-signed certificate in certificate chain
#  It connected. It refused the certificate. Different problem entirely.
```

**Beat 3 — same container, same command, cert mounted in.** The controlled experiment: one variable changed,
and no Dockerfile involved yet. This is the beat that settles it.

```powershell
docker run --rm -v "${PWD}\certs\netskope.crt:/usr/local/share/ca-certificates/netskope.crt:ro" `
  mcr.microsoft.com/dotnet/sdk:8.0 sh -c "update-ca-certificates && curl -sS https://api.nuget.org/v3/index.json"
#  Expect: Updating certificates in /etc/ssl/certs...
#          1 added, 0 removed; done.
#          { "version": "3.0.0", "resources": [ … ]   ← nuget.org answers
```

> The `rehash: warning: skipping ca-certificates.crt` line is harmless noise from `update-ca-certificates`
> reading the existing bundle. Mention it only if someone asks.

**Beat 4 — now do the same thing in the build, for one step only.**

```powershell
docker build --secret id=netskope_cert,src=.\certs\netskope.crt -t weatherapi:single -f .\Dockerfile .
#  Not behind a TLS-intercepting proxy? Omit --secret; the cert guard is a complete no-op:
#    docker build -t weatherapi:single -f .\Dockerfile .
```

**Beat 5 — prove the cert did not contaminate the image.** "Trust me, it's clean" is not an engineering standard.

```powershell
docker run --rm --entrypoint sh weatherapi:single -c "ls -A /usr/local/share/ca-certificates/ | grep -i netskope || echo 'no netskope.crt in image'; ls -A /run/secrets 2>/dev/null || echo 'no /run/secrets in image'"
#  Expect: no netskope.crt in image / no /run/secrets in image
```

**Then smoke-test the single-stage container** (fits after slide 17, or skip if time is tight):

```powershell
docker run --rm -d --name weatherapi-single -p 8080:8080 weatherapi:single
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8080/health
Invoke-RestMethod http://localhost:8080/info
docker logs weatherapi-single
docker stop weatherapi-single
```

> **Off the corporate network?** Beats 1–3 all simply succeed. Narrate the expected output above rather than
> manufacturing a failure — slides 14–15 and 17–18 carry the lesson on their own.

---

## Demo 3 — slide 23 · make the layers real

```powershell
docker history weatherapi:single
```

**Point at the 508 MB line** — nobody in the room wrote it. Then: we are shipping a compiler, PowerShell,
git and curl to production so a web API can answer three endpoints.

Optional, same idea with more detail:

```powershell
dive weatherapi:single
```

---

## Demo 4 — slide 29 · multi-stage, then compare

```powershell
docker build --secret id=netskope_cert,src=.\certs\netskope.crt `
  -t weatherapi:multi -f .\Dockerfile.multistage --build-arg APP_VERSION=1.0.0 .

docker run --rm -d --name weatherapi-multi -p 8080:8080 `
  -e ASPNETCORE_ENVIRONMENT=Production weatherapi:multi
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8080/info      # version : 1.0.0  ← stamped at BUILD time
docker exec -it weatherapi-multi whoami           # app, not root
docker stop weatherapi-multi

# runtime override — no rebuild
docker run --rm -d --name weatherapi-v2 -p 8081:8080 -e APP_VERSION=2.0.0 weatherapi:multi
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8081/info      # version : 2.0.0
docker stop weatherapi-v2

# the payoff
docker image ls weatherapi
docker history weatherapi:multi                   # the restore layer is simply not there
```

---

## Demo 5 — slide 33 · dive and the scratch bonus

```powershell
dive weatherapi:multi

docker build -t hello-scratch -f .\bonus\Dockerfile.scratch .\bonus
docker run --rm hello-scratch
docker image ls hello-scratch

# run this one deliberately — the error IS the lesson
docker run --rm -it --entrypoint sh hello-scratch
#  Expect: exec: "sh": executable file not found in $PATH
```

---

## Expected numbers (measured on this repo, 2026-08-19)

Quote these if a build is slow or fails on the day. Your figures will differ slightly with base image updates.

| What | Value |
| --- | --- |
| `weatherapi:single` | **1.27 GB**, 14 layers |
| `weatherapi:multi` | **324 MB**, 8 layers |
| `mcr.microsoft.com/dotnet/aspnet:8.0` base | 320 MB, 6 layers |
| `hello-scratch` | **1.82 MB**, 1 layer |
| `RUN dotnet restore` layer | 41.8 MB |
| `RUN dotnet publish` layer | 5.64 MB |
| `COPY --from=build /app/publish` | 2.71 MB |
| `COPY src/. ./src/` layer | 20.5 kB (from a 3.0 MB `src/` on disk) |
| `WORKDIR` | 8.19 kB — not free |
| `ENV` / `EXPOSE` / `ENTRYPOINT` / `USER` | 0 B |

> `docker history` sizes sum to ~930 MB for the single-stage image while `docker image ls` reports 1.27 GB.
> The two tools count differently. Quote whichever one is on screen rather than mixing them.

---

## If it breaks
- **`/bin/sh: 1: set: Illegal option -`** → CRLF line endings in the Dockerfile heredoc, **not** certificates. Fails before any network call, so rule it out first: `git ls-files --eol .\Dockerfile` should read `w/lf`.
- **Build can't pull / x509 / TLS error / `NU1301`** → corporate CA not trusted: copy the `.crt` into `certs/`, then rebuild with `--secret`. (Absent `certs/netskope.crt` = the guard is a no-op.)
- **The failing build in beat 1 unexpectedly succeeds** → you forgot `--no-cache`, or you are off the corporate network.
- **Port already in use** → `docker stop weatherapi-single weatherapi-multi weatherapi-v2`.
- **Local API still running** → stop the spawned `dotnet` process via the PowerShell PID captured in `$localApi`.
- **`dive` is missing** → skip it and use `docker history` for the same concept (slide 23 says so).
- **Slow first build** → explain base image pulls and NuGet restore, then point at slide 22 and show cache reuse on the second build.
- **Deck won't advance** → click once inside the deck first so it has keyboard focus; or use the on-screen `prev`/`next` buttons.

## Reset / cleanup
```powershell
docker stop weatherapi-single weatherapi-multi weatherapi-v2 2>$null
docker container prune -f
docker image rm weatherapi:single weatherapi:multi weatherapi:nocert hello-scratch 2>$null
docker image prune -f
```
