# RUNSHEET — Talk 04: Docker Compose

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — every build trusts it automatically.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] Docker Compose v2 available — `docker compose version`
- [ ] Optional local Go toolchain installed — `go version`
- [ ] Optional GPU bonus ready — NVIDIA Container Toolkit installed and Docker can see the GPU
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/`
- [ ] Warm the caches — `docker pull postgres:16-alpine; docker pull redis:7-alpine; docker pull nginx:alpine; docker pull golang:1.22-alpine; docker pull gcr.io/distroless/static-debian12`
- [ ] Terminal in `talk-04-docker-compose`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```powershell
# 1) Prepare local defaults and show the resolved Compose model
Copy-Item .\.env.example .\.env -Force
docker compose config

# 2) Build and start the base stack: Go API + PostgreSQL + Redis + Nginx
docker compose up --build -d

# 3) Inspect startup, health checks, and logs
docker compose ps
docker compose logs api --tail 30

# 4) Exercise the application through Nginx on port 80
Invoke-RestMethod http://localhost/health
Invoke-RestMethod http://localhost/items
Invoke-RestMethod http://localhost/items/1
Invoke-RestMethod -Method Post -Uri http://localhost/items -ContentType 'application/json' -Body '{"name":"Compose Demo","description":"Created from PowerShell"}'
Invoke-RestMethod http://localhost/cache-stats

# 5) Inspect the stateful service directly
docker compose exec postgres psql -U appuser -d itemsdb -c "SELECT id, name FROM items ORDER BY id;"

# 6) Scale the stateless API behind the Nginx service name
docker compose up -d --scale api=2
docker compose ps api
Invoke-RestMethod http://localhost/items

# 7) Enable the optional debug profile for pgAdmin
docker compose --profile debug up -d pgadmin
Start-Process http://localhost:5050

# 8) Demonstrate Compose Watch; press Ctrl+C after explaining the rebuild behaviour
docker compose watch

# 9) Reset the default stack before showing the test override
docker compose down -v --remove-orphans

# 10) Show explicit file merge and the test profile / migration container
docker compose -f .\compose.yaml -f .\compose.test.yaml --profile test config
docker compose -f .\compose.yaml -f .\compose.test.yaml --profile test up --build -d
docker compose -f .\compose.yaml -f .\compose.test.yaml --profile test ps
docker compose -f .\compose.yaml -f .\compose.test.yaml --profile test down -v --remove-orphans

# 11) Bonus: GPU Compose with Ollama and Open WebUI, only on prepared GPU hosts
docker compose -f .\bonus\compose.gpu.yaml up -d
docker compose -f .\bonus\compose.gpu.yaml ps
Start-Process http://localhost:3000
```

## Beat-by-beat talking points
1. `docker compose config` proves Compose is a model: variables are resolved and override files are merged before anything runs.
2. `up --build -d` creates the networks, volumes, built images, and containers from one definition.
3. `ps` and `logs` make health checks visible; use them to explain readiness rather than mere startup.
4. The HTTP calls go through Nginx, so the audience sees the whole path: host → proxy → API → PostgreSQL / Redis.
5. The direct `psql` query shows named volumes and seeded state without pretending the database is stateless.
6. Scaling the API shows that a Compose service can have multiple containers when it does not publish a fixed host port itself.
7. The debug profile keeps pgAdmin out of the default path until a presenter deliberately opts in.
8. Watch mode is intentionally a rebuild path for compiled Go; sync is better for runtimes that read changed files directly.
9. The test override demonstrates explicit file order, profile-gated one-shot work, and a separate database name.
10. The GPU bonus reuses the same Compose ideas for local AI infrastructure.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. Default `certs/` is empty = no-op. If the error is during image pull rather than build, also trust the corporate CA in Docker Desktop or the Docker host.
- **Port already in use** → find the owner with `docker ps --filter "publish=80" --format "table {{.ID}}\t{{.Names}}\t{{.Ports}}"`, then stop the printed container ID or change the host port in `compose.yaml`.
- **`COPY certs/` fails during build** → confirm `certs/.gitkeep` exists and the Compose build context is the talk folder.
- **pgAdmin login fails** → use `admin@example.com` and `admin123`; it is profile-only demo tooling, not production configuration.
- **Watch appears to rebuild rather than hot-swap files** → that is expected for this compiled Go API because the running image executes `/app/api`.
- **GPU bonus cannot see a GPU** → skip the device reservation or run the bonus on CPU; it will be slower and may need more memory.

## Reset / cleanup
```powershell
docker compose down -v --remove-orphans
docker compose -f .\compose.yaml -f .\compose.test.yaml --profile test down -v --remove-orphans
docker compose -f .\bonus\compose.gpu.yaml down -v --remove-orphans
docker image rm talk-04-docker-compose-api talk-04-docker-compose-nginx 2>$null
```
