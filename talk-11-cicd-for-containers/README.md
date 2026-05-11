# CI/CD Pipelines for Containerised Applications

This talk shows how to build, test, scan, publish, and deploy a small Python/FastAPI container image with modern CI/CD practices.

> Note: GitHub only discovers workflows from the repository root `.github/workflows/` directory. The workflow files in this talk folder are teaching artifacts; copy them to the root `.github/workflows/` directory to activate them in GitHub.

## Prerequisites

- Completed Talks 1-10 in this series
- A GitHub account **and/or** an Azure DevOps organisation
- An Azure subscription
- Docker Desktop or another Docker Engine runtime
- Python 3.12+
- Azure CLI

## Talk outline (~60 minutes)

1. **CI/CD principles for containers** (4 mins)
2. **GitHub Actions: build + push on PR/merge** (5 mins)
3. **Azure Pipelines: stages, jobs, tasks** (5 mins)
4. **`docker/build-push-action` vs `Docker@2` task** (4 mins)
5. **Multi-architecture builds: Buildx + QEMU** (5 mins)
6. **Layer caching in CI: GitHub Actions cache and registry cache** (5 mins)
7. **Tagging strategy: git SHA, semver, branch** (4 mins)
8. **Security: Trivy in CI, OIDC auth to ACR, Cosign signing** (7 mins)
9. **Deployment to Azure Container Apps** (5 mins)
10. **Environment promotion: dev → staging → prod** (5 mins)
11. **GitOps: declarative state, Flux/ArgoCD intro** (5 mins)
12. **Side-by-side comparison and when to choose each** (6 mins)

## Project structure

```text
.
├── .github/workflows/
│   ├── cd.yml
│   ├── ci.yml
│   └── multi-arch.yml
├── azure-pipelines/
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

## Azure Pipelines

Azure Pipelines is Microsoft's cloud-hosted CI/CD service inside Azure DevOps. It supports the same containerisation patterns as GitHub Actions and integrates natively with Azure services.

### Core concepts

| Concept | Azure Pipelines | GitHub Actions equivalent |
| --- | --- | --- |
| Pipeline definition | YAML file in the repo | workflow YAML file |
| `trigger` / `pr` | branch/path filters | `on: push` / `on: pull_request` |
| `stages` | ordered groups of jobs | not a first-class concept (use jobs) |
| `jobs` | parallel work units inside a stage | `jobs:` |
| `steps` | ordered tasks or scripts inside a job | `steps:` |
| `task: Docker@2` | built-in Docker task | `docker/build-push-action` |
| `task: AzureCLI@2` | built-in Azure CLI task | `azure/login` + `run: az ...` |
| `task: PublishTestResults@2` | publishes JUnit/NUnit results | `actions/upload-artifact` |
| Variable groups | secrets shared across pipelines | GitHub Actions secrets |
| Service connections | authenticated links to registries/clouds | GitHub Actions secrets + OIDC |
| Environments | deployment targets with approval gates | GitHub Environments |

### Pipeline structure

A typical Azure Pipelines YAML file looks like this:

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: ubuntu-latest

variables:
  - group: talk-11-secrets      # variable group defined in Azure DevOps

stages:
  - stage: Build
    jobs:
      - job: BuildAndPush
        steps:
          - task: Docker@2
            inputs:
              command: buildAndPush
              containerRegistry: acr-connection   # service connection name
              repository: container-series/talk-11
              tags: $(Build.SourceVersion)

  - stage: Deploy
    dependsOn: Build
    jobs:
      - deployment: DeployToACA
        environment: production                   # triggers approval gate
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureCLI@2
                  inputs:
                    azureSubscription: azure-connection
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az containerapp update --name talk-11-app ...
```

### Azure Pipelines workflows in this talk

#### CI pipeline (`azure-pipelines/ci.yml`)

Triggered on pull requests to `main`.

**Stage 1: Test**
- installs Python 3.12 with `UsePythonVersion@0`
- installs runtime and test dependencies
- runs `pytest tests/ --junitxml=test-results.xml`
- publishes JUnit results with `PublishTestResults@2` (visible in the Azure DevOps test tab)

**Stage 2: BuildAndScan**
- builds the image without pushing using `Docker@2`
- runs Trivy via a Docker-in-Docker script step
- fails the pipeline on CRITICAL vulnerabilities

#### CD pipeline (`azure-pipelines/cd.yml`)

Triggered on pushes to `main`.

**Stage 1: Build**
- authenticates to ACR via a Docker Registry service connection
- builds and pushes with `Docker@2` (`buildAndPush` command)
- exports the commit SHA as an output variable for downstream stages

**Stage 2: Deploy**
- targets the `production` Azure DevOps Environment
- any approval gates configured on that environment must pass before deployment runs
- updates the Azure Container App with `AzureCLI@2`
- polls the revision health status to verify the rollout succeeded

#### Multi-arch pipeline (`azure-pipelines/multi-arch.yml`)

Triggered on semver tags (`v*`).

- installs QEMU and registers binfmt handlers
- creates a Buildx builder with the `docker-container` driver
- logs into ACR using an Azure service connection
- runs `docker buildx build --platform linux/amd64,linux/arm64` with provenance and SBOM

### Setting up service connections

Service connections are the Azure DevOps equivalent of GitHub OIDC or stored secrets.

**Docker Registry service connection (`acr-connection`)**

1. In Azure DevOps → Project Settings → Service connections → New.
2. Select **Docker Registry** → **Azure Container Registry**.
3. Choose your subscription and registry; name it `acr-connection`.
4. Grant it to the pipeline.

**Azure Resource Manager service connection (`azure-connection`)**

1. In Azure DevOps → Project Settings → Service connections → New.
2. Select **Azure Resource Manager**.
3. Choose **Workload Identity Federation (automatic)** — this is the OIDC equivalent; no long-lived secret is stored.
4. Scope to your subscription or resource group; name it `azure-connection`.

### Variable groups

Variable groups store secrets and config values that multiple pipelines can share.

1. In Azure DevOps → Pipelines → Library → + Variable group.
2. Name it `talk-11-secrets`.
3. Add variables: `ACR_LOGIN_SERVER`, `ACR_NAME`, `RESOURCE_GROUP`.
4. Mark sensitive values as secret (padlock icon).
5. In the pipeline YAML reference with `- group: talk-11-secrets`.

### Environments and approval gates

Azure DevOps Environments let you require human approval before a deployment stage runs.

1. In Azure DevOps → Pipelines → Environments → New environment.
2. Name it `production`.
3. Click **Approvals and checks** → Add an **Approvals** check.
4. Add required approvers.

When the CD pipeline reaches the `Deploy` stage it pauses and sends an approval request. Only after approval does the deployment run.

### Predefined variables

Azure Pipelines provides equivalent variables to GitHub Actions:

| GitHub Actions | Azure Pipelines |
| --- | --- |
| `${{ github.sha }}` | `$(Build.SourceVersion)` |
| `${{ github.ref_name }}` | `$(Build.SourceBranchName)` |
| `${{ github.run_id }}` | `$(Build.BuildId)` |
| `${{ github.repository }}` | `$(Build.Repository.Name)` |
| `${{ github.workspace }}` | `$(Build.SourcesDirectory)` |

### GitHub Actions vs Azure Pipelines — side by side

| Capability | GitHub Actions | Azure Pipelines |
| --- | --- | --- |
| CI/CD as code | workflow YAML | pipeline YAML |
| Docker build task | `docker/build-push-action` | `Docker@2` |
| Azure login | `azure/login` (OIDC) | Workload Identity Federation service connection |
| Secrets | GitHub repository/org secrets | Variable groups + Key Vault link |
| Test result publishing | upload artifact + third-party | `PublishTestResults@2` (native) |
| Approval gates | GitHub Environments | Azure DevOps Environments |
| Marketplace | GitHub Marketplace (Actions) | Azure DevOps Extensions (tasks) |
| Self-hosted runners | GitHub self-hosted runners | Azure DevOps self-hosted agents + VMSS |
| Pipeline templates | reusable workflows (`workflow_call`) | pipeline templates (`extends:`) |
| Best fit | GitHub-native repos | Azure DevOps-native estates or mixed |

Choose **GitHub Actions** when your source of truth is GitHub and you want tight integration with pull requests, GitHub security features, and the Actions marketplace.

Choose **Azure Pipelines** when your organisation already uses Azure DevOps, needs advanced release management, or requires VMSS-based elastic agent pools.

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
