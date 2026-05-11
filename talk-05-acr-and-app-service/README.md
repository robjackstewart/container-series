# Azure Container Registry & App Service Deployment

Talk 5 shows how to package a Rust + Actix-web API, publish it to Azure Container Registry (ACR), and run it on Azure App Service for Containers using production-friendly patterns such as managed identity, deployment slots, diagnostics, and Infrastructure as Code.

## Prerequisites

- Talks 1-4 completed or understood:
  - Talk 1: container fundamentals
  - Talk 2: runtime configuration
  - Talk 3: OCI artifacts and registries
  - Talk 4: Docker Compose
- [Azure CLI](https://learn.microsoft.com/cli/azure/) installed
- An active Azure subscription
- Docker installed locally for the push-based demos
- Rust toolchain (optional for local app development)

## Talk outline (~60 minutes)

1. **ACR overview**: Basic, Standard, and Premium tiers; when geo-replication matters.
2. **Authentication**: admin user vs service principal vs managed identity (**prefer managed identity**).
3. **`az acr login` and image push flow**: build locally, tag correctly, and push into ACR.
4. **ACR Tasks**: quick tasks with `az acr build`, triggered tasks on Git commits or base image updates, and scheduled tasks.
5. **Repository management and retention policies**: repos, tags, manifests, and cleanup.
6. **Deploying to Azure App Service for Containers**: run the image on a Linux web app.
7. **Continuous deployment via ACR webhook**: auto-refresh App Service when a new tag is pushed.
8. **Deployment slots**: validate in staging and swap to production with zero downtime.
9. **App Service logging and diagnostics**: container logs, app logs, live tailing, and troubleshooting.
10. **Infrastructure as Code with Bicep**: provision ACR, App Service Plan, Web App, and role assignments repeatably.

## Demo application

This talk uses a small Rust + Actix-web todo API with:

- `GET /health`
- `GET /info`
- `GET /todos`
- `POST /todos`
- `GET /todos/{id}`
- `PUT /todos/{id}`
- `DELETE /todos/{id}`

The service is intentionally simple so the focus stays on image publishing and platform deployment.

## 1) ACR overview

Azure Container Registry is Microsoft's private OCI registry service for container images and related artifacts.

### Tiers

- **Basic**: cheapest option; suitable for small demos and low-throughput scenarios.
- **Standard**: better throughput and storage; a strong default for team environments.
- **Premium**: adds advanced features such as geo-replication, private endpoints, and enterprise governance options.

### Geo-replication

Geo-replication is a Premium feature that places registry replicas in multiple Azure regions. This reduces image pull latency and improves resilience for globally distributed deployments.

Create a registry for this talk:

```bash
az acr create \
  --name containerseriesacr \
  --resource-group container-series-rg \
  --sku Standard \
  --admin-enabled false
```

Explanation:

- `az acr create` provisions a new Azure Container Registry.
- `--sku Standard` selects the tier used in this talk.
- `--admin-enabled false` disables shared username/password credentials.

Inspect the registry:

```bash
az acr show \
  --name containerseriesacr \
  --resource-group container-series-rg \
  --output table
```

Explanation:

- `az acr show` returns registry metadata.
- `--output table` makes the result easy to demo live.

## 2) Authentication: admin user vs service principal vs managed identity

There are three common ways to authenticate to ACR:

### Admin user

Easy for demos, but not recommended for production because it introduces long-lived shared credentials.

```bash
az acr update \
  --name containerseriesacr \
  --admin-enabled true
```

Explanation:

- Enables the built-in admin username/password for the registry.
- Use sparingly; avoid this for production apps.

### Service principal

Good for CI/CD systems that run outside Azure, but it still requires secret or certificate management.

```bash
ACR_ID=$(az acr show --name containerseriesacr --resource-group container-series-rg --query id -o tsv)

az ad sp create-for-rbac \
  --name sp-container-series-acr-push \
  --role AcrPush \
  --scopes "$ACR_ID"
```

Explanation:

- The first command captures the registry resource ID.
- `az ad sp create-for-rbac` creates an identity that can push images.
- `AcrPush` grants both push and pull rights.

### Managed identity (**preferred**)

Managed identity is the best option for Azure-hosted workloads such as App Service because Azure manages the identity lifecycle for you.

Assign a system-managed identity to a web app and grant it `AcrPull`:

```bash
PRINCIPAL_ID=$(az webapp identity assign \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --query principalId -o tsv)

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "$ACR_ID"
```

Explanation:

- `az webapp identity assign` enables a system-assigned managed identity.
- `az role assignment create` gives the app permission to pull from ACR.
- No registry password needs to be stored in app settings.

## 3) `az acr login` and pushing images to ACR

Log Docker into the registry:

```bash
az acr login --name containerseriesacr
```

Explanation:

- This authenticates your local Docker client against ACR using your Azure login.

Fetch the ACR login server:

```bash
ACR_LOGIN_SERVER=$(az acr show --name containerseriesacr --query loginServer -o tsv)
```

Explanation:

- `loginServer` is the fully qualified registry hostname used in image tags.

Build and push the Rust API image:

```bash
docker build -t rust-todo-api:latest .
docker tag rust-todo-api:latest "$ACR_LOGIN_SERVER/rust-todo-api:latest"
docker push "$ACR_LOGIN_SERVER/rust-todo-api:latest"
```

Explanation:

- `docker build` builds the local image.
- `docker tag` rewrites the image reference so it targets ACR.
- `docker push` uploads the image layers to the registry.

Verify repository contents:

```bash
az acr repository list \
  --name containerseriesacr \
  --output table

az acr repository show-tags \
  --name containerseriesacr \
  --repository rust-todo-api \
  --orderby time_desc \
  --output table
```

Explanation:

- `repository list` shows repos in the registry.
- `show-tags` confirms which versions are available to deploy.

## 4) ACR Tasks

ACR Tasks move builds into Azure, which is great for cloud-native workflows and CI/CD.

### Quick task: build directly in ACR

```bash
az acr build \
  --registry containerseriesacr \
  --image rust-todo-api:{{.Run.ID}} \
  --file talk-05-acr-and-app-service/Dockerfile \
  talk-05-acr-and-app-service/
```

Explanation:

- `az acr build` uploads the build context and performs the Docker build in Azure.
- `{{.Run.ID}}` tags each build with its ACR Task run ID.
- This eliminates the need for a local Docker daemon or self-hosted build agent.

### Triggered task: Git commit trigger

```bash
az acr task create \
  --registry containerseriesacr \
  --name build-on-push \
  --image rust-todo-api:{{.Run.ID}} \
  --context https://github.com/YOUR_ORG/container-series \
  --file talk-05-acr-and-app-service/Dockerfile \
  --git-access-token YOUR_PAT_TOKEN
```

Explanation:

- Creates a task linked to a Git repository.
- Each new commit can trigger a fresh image build.
- Replace `YOUR_ORG` and `YOUR_PAT_TOKEN` with real values before use.

### Triggered task: base image updates

```bash
az acr task update \
  --registry containerseriesacr \
  --name build-on-push \
  --base-image-trigger-enabled true
```

Explanation:

- Rebuilds your image when the base image publishes security or runtime updates.

### Scheduled task

```bash
az acr task create \
  --registry containerseriesacr \
  --name nightly-rebuild \
  --image rust-todo-api:nightly \
  --context https://github.com/YOUR_ORG/container-series \
  --file talk-05-acr-and-app-service/Dockerfile \
  --schedule "0 2 * * *"
```

Explanation:

- Runs a rebuild every day at 02:00.
- Useful for drift control and regular refreshes.

### View task history and logs

```bash
az acr task list-runs --registry containerseriesacr --output table

LAST_RUN=$(az acr task list-runs --registry containerseriesacr --query '[0].runId' -o tsv)
az acr task logs --registry containerseriesacr --run-id "$LAST_RUN"
```

Explanation:

- `list-runs` shows recent executions.
- `task logs` helps explain build failures during demos.

## 5) Repository management and retention policies

List repositories:

```bash
az acr repository list --name containerseriesacr --output table
```

List tags for one repository:

```bash
az acr repository show-tags \
  --name containerseriesacr \
  --repository rust-todo-api \
  --orderby time_desc \
  --output table
```

Inspect manifest metadata:

```bash
az acr manifest list-metadata \
  --registry containerseriesacr \
  --name rust-todo-api \
  --output table
```

Delete an old image tag:

```bash
az acr repository delete \
  --name containerseriesacr \
  --image rust-todo-api:old \
  --yes
```

Enable retention for untagged manifests:

```bash
az acr config retention update \
  --registry containerseriesacr \
  --status enabled \
  --days 7 \
  --type UntaggedManifests
```

Explanation:

- Repository commands help you inspect and manage published images.
- Retention policies prevent stale artifacts from accumulating indefinitely.

## 6) Deploying to Azure App Service for Containers

Create a Linux App Service plan:

```bash
az appservice plan create \
  --name container-series-plan \
  --resource-group container-series-rg \
  --sku B1 \
  --is-linux
```

Create the web app:

```bash
az webapp create \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --plan container-series-plan
```

Configure the container image:

```bash
az webapp config container set \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --docker-custom-image-name "$ACR_LOGIN_SERVER/rust-todo-api:latest"
```

Set required app settings:

```bash
az webapp config appsettings set \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --settings WEBSITES_PORT=8080 ENVIRONMENT=production APP_VERSION=latest RUST_LOG=info
```

Explanation:

- App Service runs the container as a managed web workload.
- `WEBSITES_PORT=8080` tells the platform which container port should receive traffic.
- The app settings also drive `/info` and runtime logging.

## 7) Continuous deployment via ACR webhook

Enable container continuous deployment:

```bash
az webapp deployment container config \
  --enable-cd true \
  --name container-series-talk05 \
  --resource-group container-series-rg
```

Show the continuous deployment webhook URL:

```bash
az webapp deployment container show-cd-url \
  --name container-series-talk05 \
  --resource-group container-series-rg
```

Explanation:

- App Service creates and manages the webhook integration.
- When a new image is pushed, App Service can automatically restart and pull the updated image.

## 8) Deployment slots: staging → production swap

Create a staging slot:

```bash
az webapp deployment slot create \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --slot staging
```

Deploy a candidate image to staging:

```bash
az webapp config container set \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --slot staging \
  --docker-custom-image-name "$ACR_LOGIN_SERVER/rust-todo-api:candidate"
```

Swap staging into production:

```bash
az webapp deployment slot swap \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --slot staging \
  --target-slot production
```

Explanation:

- Slots let you validate a new container before exposing it publicly.
- The swap operation supports zero-downtime releases.

## 9) App Service logging and diagnostics

Enable application and container logging:

```bash
az webapp log config \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --docker-container-logging filesystem \
  --application-logging filesystem \
  --level information
```

Tail logs live:

```bash
az webapp log tail \
  --name container-series-talk05 \
  --resource-group container-series-rg
```

Get the live hostname:

```bash
az webapp show \
  --name container-series-talk05 \
  --resource-group container-series-rg \
  --query defaultHostName -o tsv
```

Explanation:

- `az webapp log config` enables useful runtime diagnostics.
- `az webapp log tail` is great for live demos and incident triage.
- `az webapp show` returns the hostname used for `/health` and `/info` verification.

## 10) Infrastructure as Code with Bicep

Deploy the full environment from the included Bicep template:

```bash
az group create --name container-series-rg --location uksouth

az deployment group create \
  --resource-group container-series-rg \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.json \
  --parameters imageTag=latest
```

Explanation:

- `az group create` ensures the resource group exists.
- `az deployment group create` provisions ACR, the Linux App Service plan, the Web App, and the `AcrPull` role assignment.
- The template enables managed identity-based pulls from ACR.

## Suggested demo flow

1. Run the API locally with `cargo run`.
2. Build the image locally with Docker.
3. Push the image into ACR.
4. Use Bicep to create the registry, plan, app, and role assignment.
5. Browse to `https://<app>.azurewebsites.net/health`.
6. Enable continuous deployment and push a new image.
7. Validate a staging slot and perform a swap.
8. Review logs and diagnostics.

## Key takeaways

1. **ACR Tasks eliminate the need for local Docker builds.**
2. **Managed identity is the preferred authentication method for ACR.**
3. **App Service continuous deployment auto-updates on image push.**
4. **Deployment slots enable zero-downtime releases.**

## Bonus / Niche Corner: ACR Artifact Streaming

- **ACR Artifact Streaming** reduces cold start times for large images by streaming image content on demand instead of waiting for every layer to download up front.
- **Image quarantine policies** can help enforce security review or scanning gates before images are promoted for runtime use.
- **ACR Teleport integration with AKS** is worth watching for advanced startup-performance and cluster image-delivery scenarios.

## Included files

- `src/` - Rust Actix-web API
- `Dockerfile` - multi-stage production container build
- `infra/main.bicep` - ACR + App Service + managed identity deployment
- `infra/parameters.json` - sample deployment parameters
- `scripts/deploy.sh` - end-to-end deployment helper
- `scripts/acr-tasks.sh` - ACR Tasks and repository management examples