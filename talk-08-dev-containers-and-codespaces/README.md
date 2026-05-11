# Dev Containers & GitHub Codespaces

## Prerequisites
- VS Code with the **Dev Containers** extension, or
- Access to **GitHub Codespaces**
- Docker Desktop (for local dev containers)
- GitHub account with Codespaces enabled

## Talk outline (~60 mins)
1. **The "works on my machine" problem**
   - Local drift, inconsistent tooling, onboarding pain
   - Reproducible environments as part of the source code
2. **Dev Containers spec overview**
   - What a dev container is
   - `devcontainer.json`, images, Dockerfiles, Compose, Features
3. **`devcontainer.json` deep dive**
   - `image`
   - `features`
   - `forwardPorts`
   - `postCreateCommand`
   - VS Code `customizations` and extensions
4. **Dev Container Features**
   - Reusable, modular tooling
   - Add Docker, GitHub CLI, language runtimes, databases, and more
5. **Multi-container devcontainers with Docker Compose**
   - App + database development
   - Shared networks, service dependencies, mounted workspace
6. **Dev Container Templates**
   - Starting from proven templates instead of hand-writing everything
7. **GitHub Codespaces**
   - Lifecycle
   - Prebuilds
   - Machine types
   - Cost awareness
8. **Secrets and environment variables in Codespaces**
   - Repo, org, and user secrets
   - Avoid hardcoding credentials
9. **Port forwarding**
   - Previewing apps securely
   - Public vs private forwarded ports

## Demo projects in this talk
- `python-project/` - Flask API using a prebuilt Python dev container image
- `typescript-project/` - Express API using a custom Dockerfile-based dev container
- `fullstack-project/` - Go API + PostgreSQL using Docker Compose

## Commands and tips

### Open locally in VS Code
```bash
code .
```
Then run **Dev Containers: Reopen in Container** from the Command Palette.

### Dev Container CLI
```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
devcontainer build --workspace-folder .
```
Tip: great for automation, smoke tests, and CI validation.

### Python demo
```bash
cd python-project
pip install -r requirements.txt
python app.py
```

### TypeScript demo
```bash
cd typescript-project
npm install
npm run dev
```

### Go + PostgreSQL demo
```bash
cd fullstack-project\api
go run main.go
```
The database-backed setup is defined in `fullstack-project/.devcontainer/docker-compose.yml`.

### Useful tips
- Keep `postCreateCommand` fast and repeatable.
- Use Features for common tools before maintaining your own Dockerfile.
- Forward only the ports you need.
- Prefer secrets for tokens, API keys, and credentials.
- Use prebuilds in Codespaces to reduce startup time for teams.

## GitHub Codespaces notes
- **Lifecycle:** create, prebuild/boot, customize, code, stop, resume, delete
- **Prebuilds:** warm dependency installs and setup ahead of time
- **Machine types:** choose the smallest machine that still feels fast
- **Cost:** storage and compute both matter; stop idle codespaces

## Secrets and environment variables
- Store sensitive values in Codespaces secrets
- Use environment variables for non-secret configuration
- Document required variables in the repo README or sample env files
- Never commit production credentials into source control

## Port forwarding
- Local and cloud dev environments both rely on port forwarding for web apps
- Common examples in this talk:
  - Flask API: `5000`
  - Express API: `3000`
  - Go API: `8080`
  - PostgreSQL: `5432`

## Key takeaways
- Dev environments can be versioned just like application code.
- Dev Containers reduce onboarding time and environment drift.
- Features make container setup modular and reusable.
- Docker Compose unlocks realistic multi-service development.
- Codespaces extends the same ideas into a managed cloud developer experience.

## Bonus: Dev Container CLI and CI
You can validate containerized developer environments in CI by building dev containers as part of pull request checks. The Dev Container CLI is useful for verifying that images build, Features resolve correctly, and setup commands still succeed outside a developer laptop.
