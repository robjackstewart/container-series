# Container Runtime Deep Dive — Configuration at Runtime

Talk 2 focuses on the runtime knobs that make containers useful in real environments: environment-driven configuration, secret handling, networking, storage, health checks, restart behaviour, and resource limits.

## Prerequisites

- Talk 1 completed so the audience already understands basic images, containers, and `docker build` / `docker run`
- Docker Desktop installed and running
- Optional: Python 3.12+ if you want to run the Flask app locally without Docker
- Optional: Podman if you want to try the bonus section

## Talk outline (~60 minutes)

1. **12-factor app configuration principles** (~8 min)
   - Configuration should live outside the image
   - The same image should move through dev, test, and prod
   - Environment variables are the most common delivery mechanism
2. **`ENV` in Dockerfile vs `-e` at runtime vs `--env-file`** (~10 min)
   - `ENV` provides image defaults
   - `docker run -e ...` overrides values per container
   - `docker run --env-file ...` keeps larger config sets manageable
3. **Build secrets: why `ARG`/`ENV` are unsafe, BuildKit secret mounts** (~8 min)
   - `ARG` and `ENV` values can appear in image metadata and layer history
   - BuildKit secret mounts provide temporary access during build steps
4. **Container networking: bridge, user-defined bridge, host, none** (~10 min)
   - Default bridge gives outbound connectivity
   - User-defined bridge adds built-in DNS between containers
   - Host networking reduces isolation
   - `none` removes network access entirely
5. **Storage: bind mounts vs named volumes vs tmpfs** (~8 min)
   - Bind mounts share host paths directly
   - Named volumes are Docker-managed and portable across container recreation
   - `tmpfs` is memory-backed and ephemeral
6. **Health checks: `HEALTHCHECK` instruction** (~5 min)
   - Distinguish “container is running” from “application is healthy”
7. **Container lifecycle: restart policies** (~5 min)
   - Recover automatically after failures or reboots
8. **Resource limits: `--memory`, `--cpus`** (~6 min)
   - Stop one container from starving the host or neighbouring workloads

## Project contents

```text
.
├── Dockerfile
├── README.md
├── run-examples.sh
├── secret.txt
├── .env.example
├── bonus/
│   └── podman-comparison.sh
└── src/
    ├── app.py
    └── requirements.txt
```

## Demo application

This talk uses a small Flask API that reads its runtime configuration from environment variables.

### Local run (without Docker)

```bash
cd talk-02-runtime-configuration
python -m venv .venv
source .venv/bin/activate
pip install -r src/requirements.txt
cp .env.example .env
python src/app.py
```

What this does:
- creates an isolated Python environment
- installs Flask, Gunicorn, and `python-dotenv`
- copies the sample configuration into `.env`
- runs the API on port `8000`

### API endpoints

- `GET /health` — validates required environment variables and reports status
- `GET /config` — shows non-secret runtime configuration
- `GET /items` — returns in-memory data plus the simulated database target
- `POST /items` — adds an item using JSON input

Example requests:

```bash
curl http://localhost:8000/health
curl http://localhost:8000/config
curl http://localhost:8000/items
curl -X POST http://localhost:8000/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"demo item","description":"created during the talk"}'
```

## Build the image

```bash
docker build -t talk-02-runtime-config .
```

This builds the demo image using the `Dockerfile` in this directory. The Dockerfile accepts builds with no secret, but the talk’s secret-handling demo is more interesting with the BuildKit command shown later.

## 1) 12-factor configuration principles

The 12-factor recommendation is simple: **keep config outside the code and outside the image whenever possible**.

Why this matters:
- one immutable image can be promoted across environments
- secrets and environment-specific values are injected later
- configuration changes do not require rebuilding the application image

The Flask app in `src/app.py` reads these variables at runtime:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `APP_SECRET_KEY`
- `APP_ENV`

## 2) `ENV` in Dockerfile vs `-e` vs `--env-file`

### `ENV` in the Dockerfile

```dockerfile
ENV APP_ENV=production
```

Use `ENV` for safe defaults that make sense for every container built from the image. Good examples are non-secret defaults like log format, a default port, or `PYTHONUNBUFFERED=1`.

### Override with `docker run -e`

```bash
docker run --rm -p 8000:8000 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=myapp \
  -e DB_USER=myuser \
  -e APP_SECRET_KEY=local-dev-secret \
  -e APP_ENV=development \
  talk-02-runtime-config
```

What it shows:
- the image stays the same
- values are supplied only when the container starts
- single-use overrides are quick and explicit

### Use `--env-file` for grouped configuration

```bash
cp .env.example .env
docker run --rm -p 8000:8000 --env-file .env talk-02-runtime-config
```

What it shows:
- configuration is easier to review than a very long command line
- the same file can be shared across demos or environments
- secrets should still be handled carefully; do not commit real `.env` files

## 3) Build secrets: why `ARG` and `ENV` are unsafe

### Unsafe pattern

```dockerfile
ARG API_KEY
ENV API_KEY=${API_KEY}
```

Why it is unsafe:
- build arguments can be visible through image history and build metadata
- environment variables become part of the image configuration
- anyone with access to the image may recover those values later

You can inspect this risk with:

```bash
docker history --no-trunc talk-02-runtime-config
```

### Safer pattern with BuildKit secrets

```bash
DOCKER_BUILDKIT=1 docker build \
  --secret id=mysecret,src=secret.txt \
  -t talk-02-runtime-config .
```

What it does:
- enables BuildKit
- mounts `secret.txt` only for the specific `RUN` step that needs it
- avoids baking the secret into a normal `ENV` or `ARG`

Important note: BuildKit secret mounts are temporary. They are designed for build-time use only, not for runtime configuration.

## 4) Networking modes

### Default bridge / user-defined bridge

Create a network:

```bash
docker network create mynetwork
```

Run two containers on it:

```bash
docker run -d --rm --name runtime-api --network mynetwork \
  --env-file .env -p 8000:8000 talk-02-runtime-config

docker run --rm --network mynetwork busybox:1.36 ping -c 1 runtime-api
```

Why use a user-defined bridge:
- containers get automatic DNS resolution by container name
- isolation is better than putting everything on the default bridge
- it is the normal choice for local multi-container demos

### Host networking

```bash
docker run --rm --network=host --env-file .env talk-02-runtime-config
```

What it means:
- the container shares the host network namespace
- port publishing is unnecessary because the process binds directly on the host stack
- useful for some low-latency or system-level tools

Note: host networking behaves differently on Docker Desktop than on native Linux, so explain the platform caveat during the talk.

### No networking

```bash
docker run --rm --network=none --env-file .env talk-02-runtime-config
```

What it demonstrates:
- the container starts without external network connectivity
- useful for highly restricted workloads or debugging assumptions

## 5) Storage options

### Bind mount

```bash
mkdir -p data
docker run --rm -p 8000:8000 --env-file .env \
  -v "$(pwd)/data:/app/data" \
  talk-02-runtime-config
```

Use bind mounts when:
- you need direct access to host files
- you are iterating on local content
- the data location must be obvious on the host

Trade-off: bind mounts couple the container to the host filesystem layout.

### Named volume

```bash
docker volume create mydata
docker run --rm -p 8000:8000 --env-file .env \
  -v mydata:/app/data \
  talk-02-runtime-config
```

Use named volumes when:
- you want Docker to manage persistence
- you want data to survive container replacement
- you need cleaner separation from host path details

### `tmpfs`

```bash
docker run --rm -p 8000:8000 --env-file .env \
  --tmpfs /tmp:size=100m \
  talk-02-runtime-config
```

Use `tmpfs` when:
- data should never touch disk
- the files are temporary and disposable
- you want fast, memory-backed scratch space

## 6) Health checks

The image defines:

```dockerfile
HEALTHCHECK CMD curl --fail --silent http://127.0.0.1:8000/health || exit 1
```

Build and inspect health:

```bash
docker run -d --name health-demo --env-file .env -p 8000:8000 talk-02-runtime-config
docker inspect --format='{{json .State.Health}}' health-demo
```

Why it matters:
- a running PID is not proof that the app is usable
- health checks help operators and orchestrators decide when a container is actually ready or unhealthy

## 7) Restart policies

```bash
docker run -d --name restart-demo --restart=unless-stopped \
  --env-file .env talk-02-runtime-config
```

Common options:
- `no` — default, do not restart automatically
- `on-failure[:max-retries]` — restart only after non-zero exit codes
- `always` — restart whenever the daemon starts the container again
- `unless-stopped` — restart after daemon restarts unless a human stopped it intentionally

## 8) Resource limits

```bash
docker run --rm -p 8000:8000 --env-file .env \
  --memory=256m --cpus=0.5 \
  talk-02-runtime-config
```

What this teaches:
- `--memory=256m` caps RAM usage
- `--cpus=0.5` gives the container roughly half a CPU worth of scheduling time
- resource controls prevent noisy-neighbour problems on shared hosts

## Suggested talk flow

1. Build the image once
2. Run with inline `-e` variables
3. Switch to `--env-file`
4. Rebuild with BuildKit secret mount enabled
5. Create a user-defined bridge and prove DNS resolution
6. Compare bind mounts, named volumes, and `tmpfs`
7. Show health status in `docker inspect`
8. Finish with restart policies and resource limits

## Supporting scripts

- `run-examples.sh` — command reference for the full demo
- `bonus/podman-comparison.sh` — Docker vs Podman equivalents and Podman-only pod features

## Key takeaways

- keep environment-specific configuration out of the image whenever possible
- do not use `ARG` or `ENV` for secrets you need to protect
- prefer user-defined bridge networks for local multi-container work because they provide DNS
- choose storage based on lifecycle: host-coupled bind mount, Docker-managed volume, or ephemeral memory-backed `tmpfs`
- health checks, restart policies, and resource limits turn a toy container into something operationally useful

## Bonus: Podman as a Docker alternative

Podman is a daemonless container engine with a Docker-compatible CLI surface for many day-to-day commands.

Highlights:
- `podman run`, `podman build`, and `podman push` closely mirror Docker commands
- Podman supports **rootless** containers as a first-class workflow
- Podman can group containers into **pods**, which aligns well with Kubernetes concepts
- `podman generate kube` can export Kubernetes YAML from running pods or containers

See `bonus/podman-comparison.sh` for side-by-side examples.
