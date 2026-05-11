# Docker Compose — Multi-Service Orchestration

This talk builds on Talks 1-3 and shows how Docker Compose makes local multi-service development predictable, repeatable, and easy to share.

## Prerequisites

- Completed or reviewed Talks 1-3 in this series
- Docker Desktop or Docker Engine with Docker Compose v2
- Basic familiarity with containers, Dockerfiles, images, and container networking
- Optional: Go 1.22+ if you want to run the API outside Docker

## Talk outline (~60 mins)

1. **Why Docker Compose**: local multi-service development
2. **`compose.yaml` structure**: services, networks, volumes, configs, secrets
3. **Building the full-stack app** (Go API + PostgreSQL + Redis + Nginx)
4. **`depends_on` with health check conditions**
5. **Compose networking and DNS**
6. **Compose commands**: `up`, `down`, `build`, `logs`, `exec`, `ps`, `top`
7. **Compose profiles**
8. **Compose Watch** for hot reload
9. **Override files and extending**
10. **Environment variable substitution**

## What we are building

A small stack made of:

- **Go / Gin API** for CRUD-style item endpoints
- **PostgreSQL** as the system of record
- **Redis** as a cache for item lookups
- **Nginx** as a reverse proxy with rate limiting

## Project layout

```text
.
├── .env.example
├── compose.yaml
├── compose.override.yaml
├── compose.test.yaml
├── api
│   ├── Dockerfile
│   ├── go.mod
│   └── main.go
├── db
│   └── init.sql
├── nginx
│   ├── Dockerfile
│   └── nginx.conf
└── bonus
    └── compose.gpu.yaml
```

## Why Docker Compose?

Compose is the easiest way to define a local application stack as code. Instead of manually starting a database, cache, API, and reverse proxy one by one, you define the stack in YAML and start it with a single command.

Benefits:

- One command to bring up the whole environment
- Stable service discovery using built-in DNS
- Shared networks between services
- Persistent named volumes for stateful services
- Health checks so dependent services wait until dependencies are ready
- Repeatable onboarding for new developers

## The core Compose concepts

### Services

A service is a containerized component such as `api`, `postgres`, `redis`, or `nginx`.

### Networks

Networks define who can talk to whom:

- `frontend`: Nginx ↔ API
- `backend`: API ↔ PostgreSQL and Redis

Compose automatically provides DNS names matching service names. For example:

- `api` resolves to the API container
- `postgres` resolves to PostgreSQL
- `redis` resolves to Redis

### Volumes

Named volumes persist data across container restarts:

- `postgres_data`
- `redis_data`

### Configs and secrets

This demo uses environment variables for simplicity, but Compose also supports:

- **configs** for non-sensitive config files
- **secrets** for passwords, certificates, and credentials

In production, prefer secrets for sensitive values.

## Environment variables

Copy the example file first:

```bash
cp .env.example .env
```

On PowerShell:

```powershell
Copy-Item .env.example .env
```

Example values:

```env
DB_PASSWORD=secretpassword
DB_NAME=itemsdb
POSTGRES_PASSWORD=secretpassword
```

Compose uses `${VAR}` and `${VAR:-default}` substitution inside YAML.

## Build and start the stack

### Start everything

```bash
docker compose up --build
```

**What it does:**

- Builds the local API and Nginx images
- Pulls PostgreSQL and Redis images if needed
- Creates networks and volumes
- Starts services in dependency order
- Streams logs to your terminal

### Start in detached mode

```bash
docker compose up --build -d
```

**What it does:** Starts the stack in the background so you can keep using the terminal.

### Stop and remove containers

```bash
docker compose down
```

**What it does:** Stops and removes containers and networks created by Compose.

### Stop and also remove volumes

```bash
docker compose down -v
```

**What it does:** Removes persistent volumes too, which resets PostgreSQL and Redis data.

## Validate the application

### Check service status

```bash
docker compose ps
```

**What it does:** Shows container state, published ports, and health status.

### View live logs

```bash
docker compose logs -f
```

**What it does:** Streams logs from all services.

### View logs for one service

```bash
docker compose logs -f api
```

**What it does:** Streams logs only from the API container.

### See running processes inside containers

```bash
docker compose top
```

**What it does:** Lists processes running in each service container.

### Open a shell in PostgreSQL

```bash
docker compose exec postgres sh
```

**What it does:** Opens a shell inside the PostgreSQL container.

### Open `psql`

```bash
docker compose exec postgres psql -U appuser -d itemsdb
```

**What it does:** Connects directly to the application database.

## Test the API

### Health endpoint through Nginx

```bash
curl http://localhost/health
```

**What it does:** Verifies Nginx can reach the API and the API can reach PostgreSQL and Redis.

### List items

```bash
curl http://localhost/items
```

**What it does:** Reads all seeded items from PostgreSQL.

### Get an item by ID

```bash
curl http://localhost/items/1
```

**What it does:** Returns a single item. The API also caches item lookups in Redis.

### Create an item

```bash
curl -X POST http://localhost/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Compose Demo","description":"Created from curl"}'
```

**What it does:** Inserts a row into PostgreSQL and returns the created record.

PowerShell version:

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost/items -ContentType 'application/json' -Body '{"name":"Compose Demo","description":"Created from PowerShell"}'
```

### Delete an item

```bash
curl -X DELETE http://localhost/items/1
```

**What it does:** Deletes the row from PostgreSQL and clears its cache entry.

### View cache statistics

```bash
curl http://localhost/cache-stats
```

**What it does:** Shows Redis-backed cache hit and miss counts tracked by the API.

## `compose.yaml` walkthrough

### `api`

The API service:

- builds from `./api`
- waits for PostgreSQL and Redis to become healthy
- joins both `frontend` and `backend`
- exposes an internal health check used by Compose

### `postgres`

The database service:

- uses `postgres:16-alpine`
- initializes schema and sample data from `db/init.sql`
- stores data in a named volume
- reports readiness using `pg_isready`

### `redis`

The cache service:

- uses `redis:7-alpine`
- stores data in a named volume
- reports readiness using `redis-cli ping`

### `nginx`

The reverse proxy service:

- builds from `./nginx`
- depends on a healthy API
- publishes port `80:80`
- rate limits incoming traffic

## `depends_on` with health conditions

A common Compose mistake is assuming container startup means application readiness. It does not.

This talk uses:

- `service_healthy` for PostgreSQL and Redis before the API starts
- `service_healthy` for the API before Nginx starts
- `service_completed_successfully` in the test override for a one-shot migration task

That pattern is far more reliable than simple startup ordering.

## Compose networking and DNS

Compose creates internal DNS entries for each service name. That means the API connects to:

- `postgres:5432`
- `redis:6379`

Nginx connects to:

- `api:8080`

No hard-coded IPs are needed.

## Common Compose commands

### Build images explicitly

```bash
docker compose build
```

**What it does:** Builds the `api` and `nginx` images without starting the stack.

### Rebuild a single service

```bash
docker compose build api
```

**What it does:** Rebuilds only the API image.

### Start one service and its dependencies

```bash
docker compose up api
```

**What it does:** Starts the API and anything it depends on.

### Restart a service

```bash
docker compose restart api
```

**What it does:** Restarts the running API container.

### Show the resolved config

```bash
docker compose config
```

**What it does:** Expands variables, merges overrides, and prints the final Compose model.

## Compose profiles

Profiles let you enable optional services only when needed.

This talk includes:

- `debug` profile for **pgAdmin**
- `test` profile for the one-shot **db-migrate** service

### Start with debug tooling

```bash
docker compose --profile debug up --build
```

**What it does:** Starts the normal stack plus pgAdmin.

### Start with test services

```bash
docker compose -f compose.yaml -f compose.test.yaml --profile test up --build
```

**What it does:** Applies the test override, uses the test database settings, runs migrations, and brings up the stack.

## Compose Watch for hot reload

Compose Watch is useful for inner-loop development.

### Start watch mode

```bash
docker compose watch
```

**What it does:** Watches configured paths and syncs or rebuilds when files change.

In `compose.override.yaml`, the API service includes:

- a source mount for `./api`
- a `develop.watch` section
- a debug environment flag

That gives you a good starting point for live development workflows.

## Override files and extending

Compose automatically loads `compose.override.yaml` when present.

Use overrides for:

- development-only ports
- volume mounts
- debug settings
- optional services like pgAdmin

### Resolve base + override configuration

```bash
docker compose config
```

**What it does:** Shows the merged result of `compose.yaml` plus `compose.override.yaml`.

### Use a specific stack of files

```bash
docker compose -f compose.yaml -f compose.test.yaml config
```

**What it does:** Prints the merged configuration for the test stack.

## Environment variable substitution

Examples from the Compose file:

```yaml
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-secretpassword}
POSTGRES_DB: ${DB_NAME:-itemsdb}
```

This means:

- use the environment variable if provided
- otherwise fall back to the default value

### Preview resolved variables

```bash
docker compose config
```

**What it does:** Shows the final values after substitution.

## Troubleshooting tips

### Recreate containers after config changes

```bash
docker compose up --build --force-recreate
```

**What it does:** Rebuilds images and recreates containers even if Compose thinks they are unchanged.

### Remove everything and start fresh

```bash
docker compose down -v && docker compose up --build
```

**What it does:** Clears old state and boots a fresh environment.

### Check health check output

```bash
docker inspect --format='{{json .State.Health}}' $(docker compose ps -q api)
```

**What it does:** Prints API health check history and status.

## Key takeaways

- Compose turns a multi-service app into a single reproducible definition
- Health checks are critical for reliable startup sequencing
- Compose networks provide simple DNS-based service discovery
- Named volumes preserve state across restarts
- Profiles keep optional services out of the default path
- Override files are ideal for development-specific behavior
- Compose Watch improves local feedback loops

## Bonus: GPU containers with Compose

See `bonus/compose.gpu.yaml` for an example of running:

- **Ollama** with NVIDIA GPU passthrough
- **Open WebUI** connected to Ollama

Important notes:

- GPU containers require the **NVIDIA Container Toolkit** on the host
- The Docker Engine must be able to access the NVIDIA runtime
- If a GPU is unavailable, remove the device reservation and run on CPU instead

### Start the GPU example

```bash
docker compose -f bonus/compose.gpu.yaml up -d
```

**What it does:** Starts the local LLM stack with GPU access when supported.

## Suggested live demo flow

1. Walk through `compose.yaml`
2. Start the stack with `docker compose up --build`
3. Show `docker compose ps` and health checks
4. Call `/items` and `/items/1`
5. Show Redis cache stats
6. Open PostgreSQL with `docker compose exec`
7. Show `compose.override.yaml` and `compose.test.yaml`
8. Finish with the GPU example
