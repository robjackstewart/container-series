# Container Series 🐳

A comprehensive, hands-on talk series on containerisation spanning the full software development lifecycle — from first principles to production Kubernetes deployments.

## About This Series

Each talk is approximately 60 minutes and builds on the previous one. Every talk directory is **fully self-contained** with all source code, Dockerfiles, infrastructure templates, and scripts — no shared artifacts between talks.

A different programming language is used in each talk to emphasise container versatility: containers work the same regardless of language.

### How each talk is laid out

Every talk separates **what you say** from **what you run**, so you never have speaker notes and live code fighting for the same screen:

| Path | Purpose | When to open it |
|------|---------|-----------------|
| `README.md` | Slim index — what you'll learn, prerequisites, folder map | First, to orient yourself |
| `RUNSHEET.md` | One-page cue card: pre-flight checklist, copy-paste commands, talking points, "if it breaks" recovery | On your **private** screen while presenting |
| `notes/` | Speaker guide — the teaching narrative and "expert asides" (no command blocks) | When preparing, or on a private screen |
| `certs/` | Drop a corporate CA `.crt` here if you're behind a TLS-intercepting proxy (empty by default) | Only behind Netskope-style proxies |
| code dirs | The working example(s) — share these on screen | During the live demo |

**Presenting a talk in 10 minutes?** Open the talk's `RUNSHEET.md`, run the pre-flight checklist, then work down the command sequence while sharing the code/terminal. Keep `notes/` and the runsheet on your own screen.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine on Linux)
- [Git](https://git-scm.com/)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for Talks 5, 6, 12)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (for Talk 12)
- [Helm](https://helm.sh/docs/intro/install/) v3 (for Talk 12)
- An Azure subscription (for Talks 5, 6, 12)

## Talk Index

| # | Title | Language | Topics |
|---|-------|----------|--------|
| [01](./talk-01-container-fundamentals/) | Container Fundamentals — Building Your First Image | C# / .NET 8 | Layers, multi-stage builds, Dockerfile instructions, BuildKit cache mounts, basic commands |
| [02](./talk-02-runtime-configuration/) | Container Runtime Deep Dive — Configuration at Runtime | Python / Flask | Env vars, build secrets, networking, bind mounts, volumes, tmpfs, health checks, resource limits |
| [03](./talk-03-oci-artifacts-and-registries/) | OCI Artifacts & Container Registries | R / Plumber | OCI spec, ORAS, push/pull/attach/discover, registries, tagging strategies, manifest lists |
| [04](./talk-04-docker-compose/) | Docker Compose — Multi-Service Orchestration | Go / Gin | Compose spec, depends_on, networking, profiles, Compose Watch, override files |
| [05](./talk-05-acr-and-app-service/) | Azure Container Registry & App Service Deployment | Rust / Actix-web | ACR tiers, ACR Tasks, managed identity, App Service, deployment slots, Bicep IaC |
| [06](./talk-06-azure-container-apps/) | Azure Container Apps — Services & Jobs | Java / Spring Boot | ACA services, revisions, traffic splitting, KEDA scaling, cron jobs, Dapr, scale-to-zero |
| [07](./talk-07-container-security/) | Container Security — Scanning & Hardened Images | TypeScript / Express | Trivy, Docker Scout, distroless images, Chainguard, non-root, Cosign, SBOMs, seccomp |
| [08](./talk-08-dev-containers-and-codespaces/) | Dev Containers & GitHub Codespaces | Multi-language | devcontainer.json, Features, multi-container devcontainers, Codespaces prebuilds |
| [09](./talk-09-testcontainers/) | Testcontainers — Integration Testing with Real Dependencies | C# / .NET 8 + xUnit | PostgreSQL/Redis/RabbitMQ in tests, WebApplicationFactory, wait strategies, Testcontainers Cloud |
| [10](./talk-10-dotnet-aspire/) | .NET Aspire — Cloud-Native Orchestration | C# / .NET 9 Aspire | AppHost, service discovery, Aspire Dashboard (traces/metrics/logs), azd deployment |
| [11](./talk-11-cicd-for-containers/) | CI/CD Pipelines for Containerised Applications | Python / FastAPI | GitHub Actions, multi-arch builds, OIDC auth, Cosign in CI, GitOps, Buildx Bake |
| [12](./talk-12-kubernetes-helm-aks/) | Kubernetes, Helm & Azure Kubernetes Service | Kotlin / Ktor | Pods, Deployments, Services, Ingress, HPA, Helm charts, AKS, Bicep IaC |
| [13](./talk-13-wasm-containers/) | WebAssembly Containers — The Future | Rust (Wasm) + C# | WASI, Docker+Wasm, Fermyon Spin, Wasm vs containers, SpinKube, cold start comparison |
| [14](./talk-14-buildpacks-and-alternative-builds/) | Cloud Native Buildpacks & Alternative Build Tools | Ruby / Sinatra | Buildpacks, `pack`, `ko`, `jib`, Nixpacks, rebase, reproducible builds |
| [15](./talk-15-observability-and-debugging/) | Container Observability & Debugging | Elixir / Phoenix | OpenTelemetry, Loki, Jaeger, Prometheus, Grafana, docker debug, kubectl debug, ephemeral containers |

## Languages Used

| Talk | Language | Framework |
|------|----------|-----------|
| 1 | C# | .NET 8 Minimal API |
| 2 | Python | Flask |
| 3 | R | Plumber |
| 4 | Go | Gin |
| 5 | Rust | Actix-web |
| 6 | Java | Spring Boot |
| 7 | TypeScript | Express |
| 8 | Python + TypeScript + Go | Flask / Express / net/http |
| 9 | C# | .NET 8 + xUnit |
| 10 | C# | .NET 9 Aspire |
| 11 | Python | FastAPI |
| 12 | Kotlin | Ktor |
| 13 | Rust (Wasm) + C# | Spin + .NET |
| 14 | Ruby + Go + Java + Node.js | Sinatra + Gin + Spring + Express |
| 15 | Elixir | Phoenix |

## 🎯 Each Talk's Bonus / Niche Corner

Every talk ends with a fun, lesser-known topic:

| Talk | Bonus Topic |
|------|-------------|
| 1 | Exploring layers with `dive`, building from `scratch` |
| 2 | Podman: the daemonless Docker alternative |
| 3 | Storing Wasm modules and ML models in OCI registries |
| 4 | GPU containers with Compose + Ollama LLM |
| 5 | ACR Artifact Streaming & image quarantine policies |
| 6 | Event-driven jobs, ACA session pools, custom KEDA scalers |
| 7 | Live container "hacking" demo, CVE exploitation |
| 8 | Dev Container CLI in CI pipelines |
| 9 | Testcontainers Desktop, reusable containers, Playwright E2E |
| 10 | Aspire + Ollama for local AI orchestration |
| 11 | Buildx Bake, SLSA attestations, hadolint |
| 12 | Helm tests, Kustomize comparison, Helmfile |
| 13 | Wasm Component Model, polyglot plugins |
| 14 | Reproducible builds, custom buildpacks, pack rebase |
| 15 | Debugging distroless containers, CRIU checkpoint/restore |

## Getting Started

Clone the repository:
```bash
git clone https://github.com/robjackstewart/container-series.git
cd container-series
```

Each talk has its own README with prerequisites, commands, and explanations. Start with Talk 1:
```bash
cd talk-01-container-fundamentals
cat README.md
```

## Quick Start: Run Any Talk's App

Each talk directory contains a self-contained application. For example, to run Talk 4 (Docker Compose):
```bash
cd talk-04-docker-compose
docker compose up
curl http://localhost/items
```

## Behind a TLS-intercepting proxy (Netskope)?

Some corporate networks (e.g. **Netskope**) intercept TLS, which makes Docker builds and
image pulls fail with certificate errors unless the corporate CA is trusted inside the build.

Every Dockerfile in this series supports a **BuildKit build secret** (`--mount=type=secret`)
that trusts a corporate CA certificate **only during the RUN steps that need it** — the cert
is never written to any image layer, so it cannot be extracted from a pulled image.

**To use it:**

1. Export your corporate CA certificate as a PEM file named `netskope.crt`.
2. Save it as `certs/netskope.crt` inside the relevant talk folder.
3. Pass it as a BuildKit secret. The build guards every network step with the cert and removes
   it within the same layer:

   ```bash
   # Plain docker build
   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .

   # Docker Compose (the secret is wired into every build: block already)
   NETSKOPE_CERT=./certs/netskope.crt docker compose build
   ```

**How it works:** each `RUN` step that makes a network call mounts the secret at
`/run/secrets/netskope_cert`. If the file is present and non-empty it is added to the CA trust
store (or passed via a tool-specific env var), the network command runs, then the cert is
removed and the trust store is restored — all within the same `RUN`. Nothing persists.
Omitting `--secret` (or leaving `certs/netskope.crt` absent) is a complete no-op.

**Non-Dockerfile builders** (Aspire, Buildpacks/`pack`, `ko`, `jib`, Nixpacks, Spin/Wasm)
can't use Dockerfile secrets — for those, trust the corporate CA at the **host/OS level** (and
the Docker daemon). The relevant talk's `notes/` explains the exact workaround
(`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`, JVM trust store, `pack --volume`, etc.).

> Real certificates saved to `certs/` are git-ignored; only the `.gitkeep` placeholder is committed.

## Repository Structure

```text
container-series/
├── README.md                               ← You are here
├── .gitignore                              ← Ignores build output (bin/obj, target, node_modules, …) and real certs
├── talk-01-container-fundamentals/         ← C# .NET 8
│   ├── README.md                           ← Slim index for the talk
│   ├── RUNSHEET.md                         ← One-page cue card (present from this)
│   ├── notes/                              ← Speaker guide (teaching narrative)
│   ├── certs/                              ← Drop corporate CA .crt here (Netskope); empty by default
│   ├── Dockerfile
│   ├── Dockerfile.multistage
│   ├── .dockerignore
│   ├── src/
│   └── bonus/
├── talk-02-runtime-configuration/          ← Python Flask
├── talk-03-oci-artifacts-and-registries/   ← R Plumber
├── talk-04-docker-compose/                 ← Go Gin
├── talk-05-acr-and-app-service/            ← Rust Actix-web
├── talk-06-azure-container-apps/           ← Java Spring Boot
├── talk-07-container-security/             ← TypeScript Express
├── talk-08-dev-containers-and-codespaces/  ← Multi-language
├── talk-09-testcontainers/                 ← C# .NET + xUnit
├── talk-10-dotnet-aspire/                  ← C# .NET 9 Aspire
├── talk-11-cicd-for-containers/            ← Python FastAPI
├── talk-12-kubernetes-helm-aks/            ← Kotlin Ktor
├── talk-13-wasm-containers/               ← Rust Wasm + C#
├── talk-14-buildpacks-and-alternative-builds/ ← Ruby Sinatra
└── talk-15-observability-and-debugging/   ← Elixir Phoenix
```

## Tools You'll Need (by talk)

Install these as you progress through the series:

```bash
# Core (all talks)
docker --version          # Docker Engine / Desktop
docker compose version    # Docker Compose V2

# Talk 3: OCI artifacts
brew install oras         # or: https://oras.land
brew install skopeo       # or: https://github.com/containers/skopeo

# Talk 5-6, 12: Azure
az --version              # Azure CLI
az extension add --name containerapp

# Talk 7: Security scanning
brew install trivy        # or: https://aquasecurity.github.io/trivy
brew install cosign       # or: https://docs.sigstore.dev/cosign/installation/
brew install syft         # or: https://github.com/anchore/syft

# Talk 8: Dev Containers
# Install VS Code + Dev Containers extension, or GitHub Codespaces

# Talk 12: Kubernetes
kubectl version --client  # kubectl
helm version              # Helm v3

# Talk 13: WebAssembly
rustup target add wasm32-wasi
brew install fermyon/tap/spin  # Fermyon Spin CLI

# Talk 14: Alternative builds
brew install buildpacks/tap/pack  # Cloud Native Buildpacks
go install github.com/google/ko@latest  # ko for Go
brew install nixpacks     # or: https://nixpacks.com
```

## Key Concepts Across the Series

| Concept | Where Covered |
|---------|---------------|
| Multi-stage builds | Talk 1, 4, 5, 7 |
| BuildKit secrets & cache | Talks 1, 2 |
| OCI spec & artifacts | Talk 3 |
| Networking & volumes | Talk 2, 4 |
| Azure Container Registry | Talks 5, 6, 12 |
| Supply chain security | Talks 7, 11 |
| GitOps | Talk 11 |
| Infrastructure as Code (Bicep) | Talks 5, 6, 12 |
| OpenTelemetry | Talks 10, 15 |
| Kubernetes | Talks 12, 13 |
| WebAssembly | Talks 3, 13 |

## Contributing

Found an issue? Each talk is self-contained — PRs to individual talk directories are welcome.

## License

MIT — see [LICENSE](LICENSE) for details.
