# Talk 02 — Runtime Configuration

Run the same Flask image with realistic runtime configuration: environment variables, secret-safe builds, networking modes, storage choices, health checks, restart behaviour, and resource limits. Language: Python / Flask.

## What you'll learn
- How image defaults, runtime environment variables, and env files work together.
- Why secrets belong outside `ARG` and `ENV`, and how BuildKit secret mounts help during builds.
- How networking, storage, health checks, restart policies, and limits shape operational behaviour.

## Prerequisites
- Docker Desktop installed and running.
- Bash-compatible shell for the helper scripts.
- Optional: Python 3.12+ for running the Flask app locally.
- Optional: Podman for the bonus comparison.

## Folder map
- **`slides/talk-02.html`** — the presentation: 30 slides, keyboard-driven, diagram-led. **Share this on screen.**
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the Flask API used by the container image.
- **`bonus/`** — Podman comparison commands and pod concepts.
- **`run-examples.sh`** — printable command reference for the Docker demos.
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## How the three presenting artefacts line up

All three use the **same slide numbers** as their index, so you never have to hunt for your place. The deck
displays the slide number bottom-right and the section name top-right.

| Deck slides | Section | Speaker guide | Runsheet |
| --- | --- | --- | --- |
| 1–2 | Opening and route map | Opening | — |
| 3–6 | Config belongs outside the image | §1 | **Demo 1** (slide 6) |
| 7–9 | Inline `-e` flags vs `--env-file` | §2 | **Demo 2** (slide 9) |
| 10–12 | Build-time values and secret mounts | §3 | **Demo 3** (slide 12) |
| 13–15 | Networking modes and service discovery | §4 | **Demo 4** (slide 15) |
| 16–18 | Bind mounts, named volumes, tmpfs | §5 | **Demo 5** (slide 18) |
| 19–21 | Health checks and restart policy | §6 | **Demo 6** (slide 21) |
| 22–24 | Resource limits | §7 | **Demo 7** (slide 24) |
| 25–27 | Bonus: Podman comparison | §8 | **Demo 8** (slide 27) |
| 28–30 | Discussion, takeaways, handover | Closing | — |

**Presenting cold?** Open `RUNSHEET.md`, work the pre-flight checklist, open `slides/talk-02.html` in a
browser, and drive down the runsheet. It tells you which slide each command belongs to.

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
docker build -t talk-02-runtime-config .
```

## API endpoints
- `GET /health`
- `GET /config`
- `GET /items`
- `POST /items`

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`**. Build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation.

## Next in the series
Talk 03 moves from single-container runtime knobs into multi-container applications and Compose.
