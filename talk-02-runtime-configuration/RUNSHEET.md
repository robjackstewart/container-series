# RUNSHEET — Talk 02: Runtime Configuration

> One-page cue card. Keep it on your **private** screen; share the deck + terminal.
> Deck: [`slides/talk-02.html`](./slides/talk-02.html) · Narrative: [`notes/README.md`](./notes/README.md)
> Behind Netskope? Drop your CA `.crt` into `certs/` first (see pre-flight) — every build trusts
> it automatically, no teaching moment required this time.

## How to drive this talk

The deck is the spine. It shows the **slide number** bottom-right and the **section** top-right;
every heading below names the slide it belongs to, so you can always find your place.
Press <kbd>O</kbd> in the deck for a clickable index, <kbd>→</kbd>/<kbd>space</kbd> to advance.

| You are on slide | Do this |
| --- | --- |
| 1–5 | Talk only. No terminal. |
| **6** | **Demo 1** — build once, configure at run (inline `-e` flags) |
| 7–8 | Talk only. |
| **9** | **Demo 2** — `--env-file` and the `/items` API |
| 10–11 | Talk only. |
| **12** | **Demo 3** — BuildKit build secret, then `docker history` |
| 13–14 | Talk only. |
| **15** | **Demo 4** — bridge, host, and none networking |
| 16–17 | Talk only. |
| **18** | **Demo 5** — bind mount, named volume, tmpfs |
| 19–20 | Talk only. |
| **21** | **Demo 6** — health check state, then restart policy |
| 22–23 | Talk only. |
| **24** | **Demo 7** — run under a resource cap |
| 25–26 | Talk only. |
| **27** | **Demo 8** — Podman equivalents (bonus) |
| 28–30 | Discussion, takeaways, handover to Talk 03 |

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] Bash-compatible shell available — `bash --version`
- [ ] Optional Podman installed — `podman --version`
- [ ] Sample env file copied — `cp .env.example .env`
- [ ] Warm the caches — `docker pull python:3.12-slim; docker pull busybox:1.36`
- [ ] Terminal in `talk-02-runtime-configuration`, large font, speaker guide closed
- [ ] Deck open at slide 1 in a second window — `.\slides\talk-02.html`
- [ ] (if behind Netskope) corporate CA in place — one command, covers every talk:

```powershell
..\scripts\sync-netskope-cert.ps1
```

> Finds the CA automatically (the Netskope agent's own copy at
> `%ProgramData%\netskope\stagent\data\nscacert.pem` first, since that stays current through a CA
> rotation; else the Windows root store) and writes it as `netskope.crt` into all 19 `certs/` folders.
> Safe to re-run — identical files are left alone and a *different* cert is reported rather than
> overwritten unless you pass `-Force`. `-WhatIf` previews; `-Remove` strips it again.
> `certs/*` is git-ignored, so the real certificate is never committed. Default `certs/` is empty,
> which makes the cert-trust step in the Dockerfile a complete no-op — nothing to demonstrate here,
> unlike Talk 01.

---

## Demo 1 — slide 6 · build once, configure at run

```bash
cp .env.example .env
DOCKER_BUILDKIT=1 docker build -t talk-02-runtime-config .

docker run -d --rm --name runtime-inline -p 8000:8000 \
  -e DB_HOST=host.docker.internal -e DB_PORT=5432 -e DB_NAME=myapp \
  -e DB_USER=myuser -e APP_SECRET_KEY=runtime-secret -e APP_ENV=development \
  talk-02-runtime-config
sleep 3
curl http://localhost:8000/health
curl http://localhost:8000/config
docker stop runtime-inline
```

**Say:** narrate every `-e` flag as you type it — each one is a fact the image did not know at
build time. `/config` reports `app_secret_key_configured: true` and never the value itself.

---

## Demo 2 — slide 9 · `--env-file` and the `/items` API

```bash
docker run -d --rm --name runtime-env-file -p 8000:8000 --env-file .env talk-02-runtime-config

curl http://localhost:8000/items
curl -X POST http://localhost:8000/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"demo item","description":"created during the talk"}'
docker stop runtime-env-file
```

**Say:** point at `database_target` in the GET response — built entirely from env-file values.
Swapping `.env` for a different file is the whole migration story between environments, with no
code change and no rebuild.

---

## Demo 3 — slide 12 · BuildKit build secret, then prove it's clean

```bash
DOCKER_BUILDKIT=1 docker build --secret id=mysecret,src=secret.txt -t talk-02-runtime-config .
docker history --no-trunc talk-02-runtime-config | head
```

> The mount is declared `required=false`, so the build also succeeds cleanly with no `--secret`
> at all — the step just prints "No build secret supplied". Point out that `secret.txt`'s contents
> never appear anywhere in the history output above.

---

## Demo 4 — slide 15 · bridge, host, and none networking

```bash
# a user-defined bridge — DNS resolves the API by name alone
docker network create mynetwork
docker run -d --rm --name runtime-api --network mynetwork --env-file .env -p 8000:8000 talk-02-runtime-config
docker run --rm --network mynetwork busybox:1.36 ping -c 1 runtime-api
docker stop runtime-api
docker network rm mynetwork

# host networking — call out the Docker Desktop VM caveat as you run it
docker run -d --rm --name host-network-demo --network=host --env-file .env talk-02-runtime-config
sleep 3
docker stop host-network-demo

# --network=none — the process starts, and every network call fails immediately
docker run -d --rm --name no-network-demo --network=none --env-file .env talk-02-runtime-config
sleep 3
docker logs no-network-demo | tail -n 5
docker stop no-network-demo
```

**Say:** tear the network down after the bridge beat — `docker stop runtime-api` /
`docker network rm mynetwork` — before moving to host/none, so the port isn't double-bound.

---

## Demo 5 — slide 18 · bind mount, named volume, tmpfs

```bash
mkdir -p data
docker run --rm --env-file .env -v "$(pwd)/data:/app/data" talk-02-runtime-config \
  python -c 'from pathlib import Path; Path("/app/data/bind.txt").write_text("bind mount")'
cat data/bind.txt   #  written straight onto this machine

docker volume create mydata
docker run --rm --env-file .env -v mydata:/app/data talk-02-runtime-config \
  python -c 'from pathlib import Path; Path("/app/data/volume.txt").write_text("named volume")'
docker run --rm --env-file .env -v mydata:/app/data talk-02-runtime-config \
  python -c 'from pathlib import Path; print(Path("/app/data/volume.txt").read_text())'
#  Expect: named volume   ← a brand-new container, same volume, the data outlived the writer

docker run --rm --env-file .env --tmpfs /tmp:size=100m talk-02-runtime-config \
  python -c 'from pathlib import Path; Path("/tmp/tmpfs.txt").write_text("tmpfs")'
```

**Say:** after the tmpfs beat, try to `cat` that file from a fresh container mounting the same
path — there's nothing there. The absence is the entire point, made visible.

---

## Demo 6 — slide 21 · health check state, then restart policy

```bash
docker run -d --name health-demo --env-file .env -p 8000:8000 talk-02-runtime-config
sleep 35
docker inspect --format='{{json .State.Health}}' health-demo
#  Expect: {"Status":"healthy","FailingStreak":0, "Log":[{"ExitCode":0, …}]}

docker run -d --name restart-demo --restart=unless-stopped --env-file .env talk-02-runtime-config
docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' restart-demo
#  Expect: unless-stopped
```

> Both containers run without `--rm` — clean them up explicitly (`docker rm -f health-demo
> restart-demo`) once you've shown the state, unlike most of the earlier demos.

---

## Demo 7 — slide 24 · run under a resource cap

```bash
docker run --rm --env-file .env --memory=256m --cpus=0.5 talk-02-runtime-config \
  python -c 'import os; print("limited container pid", os.getpid())'
```

**Optional, if there's time:** deliberately allocate past 256 MB in a throwaway Python one-liner
and let the room watch the container exit with code 137. Seeing the OOM kill happen live lands
harder than describing it.

---

## Demo 8 — slide 27 · Podman equivalents (bonus)

```bash
bash bonus/podman-comparison.sh
```

**Say:** pause on the pod and `podman generate kube` lines at the end of the script's output — a
pod grouping containers under one shared network namespace is precisely the Kubernetes concept
Talk 12 spends an hour on.

---

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception isn't trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. Default `certs/` is empty = no-op.
- **`COPY certs/` fails** → ensure `certs/.gitkeep` exists and the build context is the talk folder.
- **Port already in use** → stop old demo containers: `docker rm -f runtime-inline runtime-env-file runtime-api no-network-demo health-demo host-network-demo restart-demo`.
- **`curl` is missing on Windows** → use Git Bash, WSL, or replace with `Invoke-RestMethod` in PowerShell.
- **Host networking behaves oddly (slide 15, beat 2)** → explain that Docker Desktop runs containers inside a VM; native Linux host networking is the cleanest version of this demo.
- **`ping: bad address 'runtime-api'` (slide 15, beat 1)** → this is a DNS problem, not Netskope/certs — Docker's embedded DNS (`127.0.0.11`) never touches the host proxy or TLS trust store. It means `runtime-api` was never registered because it never actually started. Check, in order: `docker ps -a --filter name=runtime-api` (did it start or exit?), `docker logs runtime-api` (why did it exit?), `docker images talk-02-runtime-config` (was the image ever built here?). Most common cause: `.env` doesn't exist yet — run `cp .env.example .env` (pre-flight) first.
- **`head` is missing** → skip the history truncation and run `docker history --no-trunc talk-02-runtime-config`.
- **Podman is unavailable (slide 27)** → skip the bonus script and explain the rootless/daemonless concepts from the speaker guide instead.
- **Deck won't advance** → click once inside the deck first so it has keyboard focus; or use the on-screen `prev`/`next` buttons.

## Reset / cleanup
```bash
docker rm -f runtime-inline runtime-env-file runtime-api no-network-demo health-demo host-network-demo restart-demo 2>/dev/null || true
docker network rm mynetwork 2>/dev/null || true
docker volume rm mydata 2>/dev/null || true
rm -rf data .env
docker image rm talk-02-runtime-config 2>/dev/null || true
```
