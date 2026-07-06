# Talk 08 — Dev Containers and GitHub Codespaces

Standardise local and cloud developer environments with Dev Containers, reusable Features, multi-container workspaces, and Codespaces prebuilds. Language: Python + TypeScript + Go.

## What you'll learn
- How `devcontainer.json` turns environment setup into versioned project configuration.
- How Features and Dockerfiles compose language tooling without bloating onboarding docs.
- How Docker Compose and Codespaces prebuilds make realistic, fast-start development environments repeatable.

## Prerequisites
- Docker Desktop installed and running for local dev containers.
- VS Code with the Dev Containers extension, or access to GitHub Codespaces.
- Optional: Dev Container CLI for the CI and automation bonus.
- GitHub account with Codespaces enabled for the cloud section.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`python-project/`** — Flask API using a prebuilt Python dev container image.
- **`typescript-project/`** — Express API using a custom Dockerfile-based dev container.
- **`fullstack-project/`** — Go API + PostgreSQL using a Compose-backed dev container.
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```powershell
devcontainer up --workspace-folder .\fullstack-project
```

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`** (or the appropriate nested `certs/` for each example). Dockerfile-backed dev container builds trust it via `--secret id=netskope_cert,src=<path>/netskope.crt` — the cert is not stored in any image layer. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation, and see **`RUNSHEET.md`** for the build-context-specific paths used by each example.

## Next in the series
Talk 09 moves from developer environments into container orchestration and running multiple services together.
