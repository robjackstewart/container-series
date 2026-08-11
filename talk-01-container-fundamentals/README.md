# Talk 01 — Container Fundamentals

Build a first container image for a small ASP.NET Core minimal API, then improve it from an intentionally simple single-stage image to a smaller multi-stage runtime image. Language: C# / .NET 8 minimal API.

## What you'll learn
- How containers differ from virtual machines, and how Docker turns a build context into an image.
- Why Dockerfile ordering, image layers, cache reuse, and `.dockerignore` matter.
- That `RUN` executes *inside the image*, with the base image's network and CA trust store — demonstrated by deliberately failing a build behind a TLS-intercepting proxy.
- How to supply a build-time secret with `--mount=type=secret` so it never reaches a shipped layer.
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
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```powershell
docker build -t weatherapi:multi -f .\Dockerfile.multistage --build-arg APP_VERSION=1.0.0 .
```

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`** (the runsheet pre-flight has a one-off PowerShell export). Build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation.

In this talk the proxy is part of the material rather than an obstacle. **Runsheet steps 2–5** build *without* the cert on purpose:

| Step | Command | Point being made |
| --- | --- | --- |
| 2 | `docker build --no-cache` (no `--secret`) | `dotnet restore` fails with `NU1301` — the builder cannot reach nuget.org, even though your host can |
| 3 | `curl` inside the same base image | `curl: (60) ... self-signed certificate in certificate chain` — it *did* connect; it rejected the certificate |
| 4 | `docker build --secret id=netskope_cert,...` | Restore succeeds once the builder trusts the CA for that one `RUN` |
| 5 | Inspect the finished image | No `netskope.crt`, no `/run/secrets` — the secret never became a layer |

The lesson is that `RUN` is not your shell: it runs inside a container whose CA trust store came from `mcr.microsoft.com/dotnet/sdk:8.0`, which has no reason to trust your employer's CA. Speaker narrative is in `notes/README.md` section 3a.

> Not behind a proxy? Step 2 will simply succeed. Narrate the expected output from the runsheet instead of manufacturing a failure.

## Next in the series
Talk 02 moves from image fundamentals into runtime configuration: ports, environment variables, secrets, and configuration boundaries.
