# Speaker Guide — Talk 04: Docker Compose

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with the pain of running a database, cache, API, and reverse proxy by hand. Then show how Compose turns that set of moving parts into one declarative application model that can be inspected, overridden, scaled, and reset. The big idea is that Compose is not just a convenience wrapper around `docker run`; it is the local contract for a multi-service system.

## Section-by-section narrative
### 1) Compose as an application model
- Position the Compose specification as a small, readable description of the whole local stack: services, images, builds, networks, volumes, environment, health checks, and profiles.
- Use `compose.yaml` as the centre of gravity. The API and Nginx are built locally, while PostgreSQL and Redis come from maintained images.
- Emphasise that the file is shareable onboarding documentation as well as executable configuration.
> Expert aside: Compose file syntax has evolved from the old versioned format into the Compose Specification. Modern files do not need a top-level `version`; the plugin interprets the model and warns about unsupported fields.

### 2) Services, networks, and DNS
- Explain each service by responsibility: Nginx accepts host traffic, the Go API owns application logic, PostgreSQL stores records, and Redis caches item lookups.
- The `frontend` network deliberately contains only Nginx and the API; the `backend` network contains the API, PostgreSQL, and Redis.
- Land the practical DNS point: the API connects to `postgres` and `redis`, and Nginx connects to `api`. No fixed container IPs are required.

### 3) Volumes and repeatable state
- Named volumes keep PostgreSQL and Redis data alive across container restarts, so a restart is not the same as a reset.
- The seed SQL file is mounted read-only into PostgreSQL's entrypoint folder, which makes the first boot deterministic.
- Use cleanup as a teaching moment: removing volumes is a deliberate destructive reset, not a normal stop.

### 4) Health checks and `depends_on` conditions
- Make the common mistake explicit: a container can be running while the service inside it is still booting, migrating, or rejecting connections.
- This stack waits for PostgreSQL and Redis to be healthy before starting the API, then waits for the API to be healthy before starting Nginx.
- The test override adds a one-shot migration service and uses a successful completion condition before the API proceeds.
> Expert aside: `depends_on` with `service_started` is only startup ordering; `service_healthy` waits for the dependency's health check to pass. That is why the health check itself must test the real readiness signal, not merely whether a process exists.

### 5) Environment variables and configuration boundaries
- Show how `.env.example` documents expected inputs and how `${VAR:-default}` keeps the demo runnable without secret setup.
- Be clear that the defaults are teaching values, not production credentials.
- Compose substitution happens before the final model is sent to Docker, so `docker compose config` is the best way to explain what the engine will actually receive.

### 6) Development overrides and Compose Watch
- `compose.override.yaml` is automatically merged for the normal development path. It adds debug settings, host ports for PostgreSQL and Redis, and the optional pgAdmin service behind a profile.
- Compose Watch gives a file-change feedback loop. For this compiled Go service, rebuild is the honest action because the runtime image executes a binary; plain file sync would not update that binary.
- Use the override file to discuss the line between development convenience and production-like defaults.
> Expert aside: `develop.watch` supports both sync and rebuild. Sync is ideal when the runtime reads files directly, such as an interpreted app or static assets; rebuild is the safer choice when source changes must be compiled into the image.

### 7) Profiles for optional services
- Profiles keep non-essential services out of the default path. The stack remains small until the presenter explicitly asks for debug or test tooling.
- The `debug` profile enables pgAdmin, which is useful for a live explanation but not needed for every developer boot.
- The `test` profile enables a migration-style one-shot container in the test Compose file.
> Expert aside: profiles are a good way to avoid maintaining separate whole-stack files for optional tools. They are less useful for changing core service behaviour; that is usually cleaner in an override file.

### 8) Multiple Compose files and merge precedence
- Compose automatically reads `compose.yaml` and `compose.override.yaml` for the default project.
- Explicit `-f` flags let the presenter build a different model, such as the test stack, without copying the base file.
- The later file wins for scalar values and extends maps, so the test file can change the database name while inheriting networks, images, and health checks.
> Expert aside: file order matters. Treat `docker compose -f base -f override config` as the source of truth, because it shows the fully merged model after variable substitution and override precedence.

### 9) Scaling with a reverse proxy
- Scaling the API service demonstrates that a Compose service is a template for one or more containers.
- Nginx still targets the service name, which keeps the routing example simple and avoids publishing host ports for every replica.
- This is a local teaching demo, not a replacement for production orchestration; it prepares the mental model for Kubernetes services and load balancing later in the series.

### 10) Bonus: GPU Compose with Ollama and Open WebUI
- The bonus file is intentionally separate so the main talk works on any laptop.
- Ollama gets a named volume for model data and a GPU device reservation when the host supports NVIDIA containers.
- Open WebUI talks to Ollama over the Compose network, which reinforces the same service-name DNS pattern from the main stack.
- If the room has no GPU, use it as a reading exercise: remove the device reservation and the same topology can run on CPU, just more slowly.

## Discussion prompts (engage the room)
- Which services in your local development stack are currently started by hand, and what breaks when one starts too slowly?
- Where should a team draw the line between useful defaults in Compose and production-like configuration?
- When would you choose a profile, an override file, or a separate Compose project?
- What does scaling mean locally when stateful services and host ports are involved?

## Key takeaways (the close)
- Compose makes a multi-service development environment explicit, repeatable, and reviewable.
- Health checks are the readiness contract that make `depends_on` conditions meaningful.
- Compose networks give stable service names and let you avoid container IPs.
- Profiles and override files keep optional and environment-specific behaviour out of the base path.
- Compose Watch is useful, but the right action depends on whether the app reads files directly or needs a rebuild.
- The GPU bonus is the same Compose model applied to an AI workload: services, volumes, ports, and device access.

## Bonus / niche corner
Use the Ollama and Open WebUI stack to show that Compose is not limited to web apps. It can describe local AI infrastructure just as naturally as a database-backed API: persistent model storage, a backend service, a UI service, network discovery, and optional hardware acceleration. Keep the demo optional because GPU availability is host-specific.

## Netskope / corporate proxy note
This talk uses Dockerfiles for the API and Nginx builds. The Go build stage trusts an optional corporate CA certificate via a BuildKit secret (`--secret id=netskope_cert,src=certs/netskope.crt`) before `go mod download` runs. The cert is never written to any image layer — omit `--secret` when not behind a TLS-intercepting proxy.

The final API image is shell-less, but the demo app only talks to PostgreSQL, Redis, and its own local health endpoint, so no runtime CA bundle is needed. If the Go service later makes outbound HTTPS calls, copy `/etc/ssl/certs/ca-certificates.crt` from the build stage into the final stage. Image pulls for PostgreSQL, Redis, Ollama, and Open WebUI use the Docker host or Docker Desktop trust store, so a registry x509 error during pull needs host-level proxy trust separately from the per-build secret.
