# RUNSHEET — Talk 08: Dev Containers and GitHub Codespaces

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — dev container builds are builds, so Dockerfile-backed examples need the same CA trust pattern.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] VS Code installed — `code --version`
- [ ] VS Code Dev Containers extension installed.
- [ ] Optional Dev Container CLI installed — `devcontainer --version`
- [ ] GitHub account has Codespaces enabled for the cloud section.
- [ ] (if behind Netskope) corporate `.crt` copied into `certs\`, `typescript-project\.devcontainer\certs\`, and `fullstack-project\api\certs\`
- [ ] Warm the caches — `docker pull mcr.microsoft.com/devcontainers/python:3.12; docker pull mcr.microsoft.com/devcontainers/base:ubuntu-22.04; docker pull golang:1.22; docker pull postgres:16-alpine`
- [ ] Terminal in `talk-08-dev-containers-and-codespaces`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```powershell
# 1) Open the Python project: prebuilt image + Features
code .\python-project
# In VS Code: Command Palette -> Dev Containers: Reopen in Container
# In the container terminal: python app.py

# 2) Build the same Python environment with the Dev Container CLI
devcontainer up --workspace-folder .\python-project

# 3) Open the TypeScript project: custom Dockerfile + Features
code .\typescript-project
# In VS Code: Command Palette -> Dev Containers: Reopen in Container
# In the container terminal: npm run dev

# 4) Rebuild the TypeScript dev container after Dockerfile/config changes
devcontainer up --workspace-folder .\typescript-project --remove-existing-container

# 5) Open the full-stack project: Go API + PostgreSQL through Compose
code .\fullstack-project
# In VS Code: Command Palette -> Dev Containers: Reopen in Container
# In the container terminal: cd /workspace/fullstack-project/api; go run main.go

# 6) Inspect the Compose-backed services
docker compose -f .\fullstack-project\.devcontainer\docker-compose.yml config
docker compose -f .\fullstack-project\.devcontainer\docker-compose.yml ps

# 7) Dev Container CLI bonus: build and smoke-check the Compose dev environment
devcontainer up --workspace-folder .\fullstack-project
devcontainer exec --workspace-folder .\fullstack-project bash -lc "cd /workspace/fullstack-project/api && go test ./..."
```

## Beat-by-beat talking points
1. The Python project is the smallest useful shape: a prebuilt language image, a couple of Features, forwarded port `5000`, and one dependency setup hook.
2. The CLI proves this is not magic inside VS Code; the dev container can be built by automation as well.
3. The TypeScript project owns a Dockerfile because it needs extra packages and a pinned Node toolchain.
4. Rebuild makes the boundary concrete: changing the environment means rebuilding the development image, not asking everyone to patch their laptop.
5. The full-stack project shows why Compose matters: the API and PostgreSQL are defined together, share a network, and keep the database off the host machine.
6. The Compose config output lets you point at the `build.secrets`, the API service, the database service, volumes, and ports without opening YAML by hand.
7. The CLI bonus is the CI story: build the dev environment, resolve Features, run hooks, then run a small validation inside the container.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: save `netskope.crt` in the cert folder for that build context and pass `--secret id=netskope_cert,src=<path>/netskope.crt`, then rebuild. A dev container is itself a Docker build, so this matters before `apt`, `curl`, `npm`, or `go mod download`.
- **Secret mount missing** → ensure the `.gitkeep` placeholder exists in the cert folder for each build context: `typescript-project\.devcontainer\certs\.gitkeep` and `fullstack-project\api\certs\.gitkeep`.
- **Command Palette option is missing** → install or enable the VS Code Dev Containers extension, then reload VS Code.
- **Dev Container CLI is missing** → use the VS Code rebuild path for the main demo and treat the CLI section as conceptual.
- **Port already in use** → stop the app running in the earlier dev container terminal, or change the forwarded host port in VS Code.
- **PostgreSQL is not ready yet** → wait a few seconds and rerun the Go API; the app falls back to in-memory data if the database is unavailable.

## Reset / cleanup
```powershell
docker compose -f .\fullstack-project\.devcontainer\docker-compose.yml down -v
docker container prune -f
docker image prune -f
```
