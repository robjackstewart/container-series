# CI/CD Pipelines for Containerised Applications

This talk shows how to build, test, scan, publish, and deploy a small Python/FastAPI container image with modern CI/CD practices.

> Note: GitHub only discovers workflows from the repository root `.github/workflows/` directory. The workflow files in this talk folder are teaching artifacts; copy them to the root `.github/workflows/` directory to activate them in GitHub.

## Prerequisites

- Completed Talks 1-10 in this series
- A GitHub account
- An Azure subscription
- Docker Desktop or another Docker Engine runtime
- Python 3.12+
- Azure CLI

## Talk outline (~60 minutes)

1. **CI/CD principles for containers** (5 mins)
2. **GitHub Actions: build + push on PR/merge** (6 mins)
3. **`docker/build-push-action`** (5 mins)
4. **Multi-architecture builds: Buildx + QEMU** (5 mins)
5. **Layer caching in CI: GitHub Actions cache and registry cache** (6 mins)
6. **Tagging strategy: git SHA, semver, branch** (5 mins)
7. **Security: Trivy in CI, OIDC auth to ACR, Cosign signing** (8 mins)
8. **Deployment to Azure Container Apps from Actions** (6 mins)
9. **Environment promotion: dev → staging → prod** (5 mins)
10. **GitOps: declarative state, Flux/ArgoCD intro** (5 mins)
11. **Azure DevOps comparison** (4 mins)

## Project structure

```text
.
├── .github/workflows/
│   ├── cd.yml
│   ├── ci.yml
│   └── multi-arch.yml
├── docker-bake.hcl
├── Dockerfile
├── scripts/
│   └── deploy-container-app.sh
├── src/
│   ├── main.py
│   ├── models.py
│   ├── requirements.txt
│   └── routes/
│       └── items.py
└── tests/
    └── test_items.py
```

## Application overview

The sample application is a small FastAPI service with:

- `GET /` - welcome payload with environment metadata
- `GET /health` - health endpoint for probes
- `GET /items` - list in-memory items
- `POST /items` - create an item with Pydantic validation
- `GET /items/{id}` - fetch a single item
- `DELETE /items/{id}` - delete an item
- OpenAPI docs at `/docs` and `/openapi.json`

## Local development

### 1. Create and activate a virtual environment

```powershell
cd C:\Users\robja\repos\container-series\talk-11-cicd-for-containers
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

### 2. Install dependencies

```powershell
python -m pip install --upgrade pip
pip install -r src\requirements.txt pytest httpx
```

### 3. Run the API locally

```powershell
$env:ENVIRONMENT = 'local'
$env:APP_VERSION = 'dev'
$env:PORT = '8000'
uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```

### 4. Run tests

```powershell
pytest tests -v
```

## Container workflow

### Build the image

```powershell
docker build -t talk-11-fastapi:dev .
```

### Run the container

```powershell
docker run --rm -p 8000:8000 `
  -e PORT=8000 `
  -e ENVIRONMENT=local `
  -e APP_VERSION=dev `
  talk-11-fastapi:dev
```

### Health check

```powershell
curl http://localhost:8000/health
```

## CI/CD principles for containers

A good container pipeline should:

- build once and promote the same artifact forward
- test before publishing
- scan images before deployment
- generate deterministic tags
- avoid long rebuilds with caching
- use short-lived credentials where possible
- keep deployment steps repeatable and auditable

A common flow is:

1. Pull request runs tests and an image build.
2. Security scan blocks critical findings.
3. Merge to `main` publishes a tagged image.
4. Deployment updates the runtime platform.
5. Promotion copies or retags the trusted image to higher environments.

## GitHub Actions workflows

### CI workflow (`.github/workflows/ci.yml`)

Triggered on pull requests.

**Job 1: `test`**

- checks out the code
- installs Python 3.12
- installs runtime and test dependencies
- runs `pytest tests/ -v`

**Job 2: `build-and-scan`**

- waits for tests to pass
- configures Docker Buildx
- builds the image without pushing it
- loads it into the runner's local Docker engine
- reuses GitHub Actions cache for layers
- runs Trivy and fails on critical vulnerabilities

### CD workflow (`.github/workflows/cd.yml`)

Triggered on pushes to `main`.

- authenticates to Azure using GitHub OIDC via `azure/login`
- logs into Azure Container Registry (ACR)
- builds and pushes the image with SHA and `latest` tags
- stores reusable cache layers in the registry
- updates Azure Container Apps to the new image

### Multi-architecture workflow (`.github/workflows/multi-arch.yml`)

Used when you want `linux/amd64` and `linux/arm64` images.

- `docker/setup-qemu-action` enables emulation support
- `docker/setup-buildx-action` provisions a multi-platform builder
- `docker/build-push-action` builds both architectures and pushes a manifest list
- `provenance: true` emits SLSA-style provenance attestations
- `sbom: true` emits a software bill of materials

## `docker/build-push-action`

This action wraps Buildx and supports:

- single-platform or multi-platform builds
- pushing or loading images
- BuildKit caches
- SBOM and provenance generation
- secrets and build arguments
- reproducible CI builds

Example:

```yaml
- uses: docker/build-push-action@v5
  with:
    context: ./talk-11-cicd-for-containers
    file: ./talk-11-cicd-for-containers/Dockerfile
    push: true
    tags: myregistry.azurecr.io/container-series/talk-11:${{ github.sha }}
```

## Multi-architecture builds with Buildx and QEMU

To build for both x64 and ARM64 locally:

```powershell
docker buildx create --use --name talk11builder
docker buildx inspect --bootstrap
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myregistry.azurecr.io/container-series/talk-11:latest \
  --push .
```

Why it matters:

- Apple Silicon developers need ARM64 support.
- Cloud runtimes may mix architectures.
- A single tag can point to the correct platform-specific image.

## Layer caching in CI

Two useful cache strategies are included:

### 1. GitHub Actions cache

Used in PR validation:

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

Good for repeated builds on GitHub-hosted runners.

### 2. Registry cache

Used in publish workflows:

```yaml
cache-from: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache
cache-to: type=registry,ref=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:buildcache,mode=max
```

Good when multiple workflows or environments share the same build cache.

## Tagging strategy

Use more than one tag for different jobs:

| Tag | Purpose |
| --- | --- |
| `:${{ github.sha }}` | immutable deployment reference |
| `:latest` | convenience tag for demos/dev |
| `:main` or `:feature-x` | branch tracking |
| `:1.2.3` | semver release |

Examples:

```powershell
docker tag talk-11-fastapi:dev myregistry.azurecr.io/container-series/talk-11:$(git rev-parse --short HEAD)
docker tag talk-11-fastapi:dev myregistry.azurecr.io/container-series/talk-11:latest
```

Recommendation: deploy immutable tags such as full git SHA; keep `latest` only as a convenience alias.

## Security in the pipeline

### Trivy in CI

The CI workflow scans the built image:

```yaml
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:${{ github.sha }}
    exit-code: 1
    severity: CRITICAL
```

### OIDC authentication to ACR/Azure

Prefer GitHub OIDC over long-lived service principal secrets when possible. The `azure/login` action exchanges the GitHub identity token for Azure access scoped to the federated credential.

```yaml
permissions:
  id-token: write
  contents: read
```

### Cosign signing

After push, you can sign the image:

```powershell
cosign sign myregistry.azurecr.io/container-series/talk-11:${GITHUB_SHA}
```

And verify it later:

```powershell
cosign verify myregistry.azurecr.io/container-series/talk-11:${GITHUB_SHA}
```

## Deployment to Azure Container Apps from Actions

The CD pipeline updates the deployed revision with the newly published image.

CLI equivalent:

```powershell
az containerapp update \
  --name talk-11-app \
  --resource-group <resource-group> \
  --image <registry>/container-series/talk-11:<git-sha>
```

The included `scripts/deploy-container-app.sh` script also injects runtime environment variables:

```bash
ENVIRONMENT=staging
APP_VERSION=<tag>
```

## Environment promotion: dev → staging → prod

Recommended pattern:

1. Build and test once.
2. Publish an immutable image tagged with the git SHA.
3. Deploy the same SHA to `dev`.
4. Promote the same SHA to `staging` after checks pass.
5. Promote the same SHA to `prod` with approval gates.

Promotion options:

- redeploy the same tag to a different Azure Container App
- retag in ACR without rebuilding
- maintain separate GitHub environments with approval rules

## GitOps intro: declarative state with Flux or Argo CD

GitOps moves deployment intent into version-controlled manifests.

Benefits:

- desired state lives in Git
- drift can be detected automatically
- rollbacks are commit-based
- audit history is built in

Typical flow:

1. CI builds and signs an image.
2. A deployment repo is updated with the new image tag.
3. Flux or Argo CD reconciles the cluster/app state from Git.

For Azure Container Apps, teams often start with direct CLI deployment from Actions and adopt GitOps later for more advanced promotion workflows.

## Azure DevOps comparison

GitHub Actions and Azure DevOps can both implement the same container pipeline concepts.

| Capability | GitHub Actions | Azure DevOps |
| --- | --- | --- |
| CI/CD as code | workflow YAML | pipeline YAML |
| Marketplace ecosystem | GitHub Marketplace | Azure DevOps tasks/extensions |
| OIDC cloud auth | strong native support | service connections/federated creds |
| Repo + pipeline proximity | excellent for GitHub repos | strongest in Azure DevOps-native estates |
| Environments and approvals | GitHub environments | approvals/checks/releases |

Choose GitHub Actions when your source of truth lives on GitHub and you want close integration with pull requests, checks, and GitHub security features.

## Bonus topics

### Buildx Bake

This talk includes `docker-bake.hcl` to define reusable build targets:

```powershell
docker buildx bake
```

Override variables when needed:

```powershell
docker buildx bake --set *.tags=myregistry.azurecr.io/talk-11:demo
```

### SLSA attestations

`provenance: true` in the multi-arch workflow emits provenance metadata that can support supply-chain verification.

### hadolint

Add Dockerfile linting to CI:

```powershell
docker run --rm -i hadolint/hadolint < Dockerfile
```

## Key takeaways

- Build, test, scan, and deploy containers through repeatable automation.
- Use Buildx and QEMU for multi-platform images.
- Cache layers aggressively to reduce pipeline time.
- Tag images immutably with git SHA and promote the same artifact forward.
- Prefer OIDC and signed images to improve supply-chain security.
- Azure Container Apps integrates cleanly with GitHub Actions for container delivery.
