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
- **`slides/talk-01.html`** — the presentation: 36 slides, keyboard-driven, diagram-led. **Share this on screen.**
- **`RUNSHEET.md`** — one-page cue card, organised by slide number. Keep it on your **private** screen.
- **`notes/`** — speaker guide (the teaching narrative), section headings keyed to the same slide numbers.
- **`src/`** — the ASP.NET Core minimal API.
- **`Dockerfile`** — the intentionally simple single-stage image.
- **`Dockerfile.multistage`** — the optimised multi-stage image.
- **`bonus/`** — a tiny Go binary packaged from `scratch`.
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## How the three presenting artefacts line up

All three use the **same slide numbers** as their index, so you never have to hunt for your place. The deck
displays the slide number bottom-right and the section name top-right.

| Deck slides | Section | Speaker guide | Runsheet |
| --- | --- | --- | --- |
| 1–2 | Opening and route map | Opening | — |
| 3–7 | Containers are packaged processes | §1 | **Demo 1** (slide 7) |
| 8–10 | Docker architecture and the build context | §2 | — |
| 11–12 | The first Dockerfile | §3 | — |
| 13–18 | The build has its own trust store | §3a | **Demo 2** (slide 16) |
| 19–23 | Layers, cache reuse, ordering | §4 | **Demo 3** (slide 23) |
| 24–25 | Build-time versus runtime configuration | §5 | — |
| 26–29 | Multi-stage builds | §6 | **Demo 4** (slide 29) |
| 30 | BuildKit cache mounts | §7 | — |
| 31 | Ports, logs, operational basics | §8 | — |
| 32–33 | Bonus: `dive` and `scratch` | §9 | **Demo 5** (slide 33) |
| 34–36 | Discussion, takeaways, handover | Closing | — |

**Presenting cold?** Open `RUNSHEET.md`, work the pre-flight checklist, open `slides/talk-01.html` in a
browser, and drive down the runsheet. It tells you which slide each command belongs to.

## Run it
See **`RUNSHEET.md`** for the exact command sequence, split into the five demos. Quick start:
```powershell
docker build -t weatherapi:multi -f .\Dockerfile.multistage --build-arg APP_VERSION=1.0.0 .
```

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`**. One command does it for every talk in the series:

```powershell
..\scripts\sync-netskope-cert.ps1
```

It prefers the Netskope agent's own copy at `%ProgramData%\netskope\stagent\data\nscacert.pem`, which stays current through a CA rotation, and falls back to a Windows root store export. Re-running is safe; `-WhatIf` previews and `-Remove` strips it again.

Then build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation.

In this talk the proxy is part of the material rather than an obstacle. **Slides 13–18 / Demo 2** build *without* the cert on purpose:

| Beat | Command | Point being made |
| --- | --- | --- |
| 1 | `docker build --no-cache` (no `--secret`) | `dotnet restore` fails with `NU1301` — the builder cannot reach nuget.org, even though your host can |
| 2 | `curl` inside the same base image | `curl: (60) … self-signed certificate in certificate chain` — it *did* connect; it rejected the certificate |
| 3 | Same container, cert bind-mounted in + `update-ca-certificates` | `curl` now succeeds. The controlled experiment: one variable changed, no Dockerfile involved, so the CA is provably the missing piece |
| 4 | `docker build --secret id=netskope_cert,…` | Restore succeeds once the builder trusts the CA for that one `RUN` |
| 5 | Inspect the finished image | No `netskope.crt`, no `/run/secrets` — the secret never became a layer |

The lesson is that `RUN` is not your shell: it runs inside a container whose CA trust store came from `mcr.microsoft.com/dotnet/sdk:8.0`, which has no reason to trust your employer's CA. Speaker narrative is in `notes/README.md` §3a.

> Not behind a proxy? Beat 1 will simply succeed. Narrate the expected output from the runsheet instead of manufacturing a failure.

## Next in the series
Talk 02 moves from image fundamentals into runtime configuration: ports, environment variables, secrets, and configuration boundaries.
