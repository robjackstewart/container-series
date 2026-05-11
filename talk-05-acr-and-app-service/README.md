# Azure Container Registry & App Service Deployment

Talk 5 focuses on packaging a Rust + Actix-web API, storing images in Azure Container Registry (ACR), and deploying them to Azure App Service for Containers with managed identity.

## Prerequisites

- Talks 1-4 completed or understood
- Azure CLI installed and signed in with `az login`
- Docker installed locally
- An Azure subscription with permission to create ACR, App Service, and monitoring resources
- Basic familiarity with Rust and Actix-web

## Project contents

- `src/` - Actix-web todo API
- `Dockerfile` - multi-stage Rust container build
- `infra/` - Bicep deployment for ACR + App Service + monitoring
- `scripts/` - helper scripts for deployment and ACR Tasks demos

## 60-minute talk outline

### 1) ACR overview (Basic / Standard / Premium)

Azure Container Registry is a private OCI registry for images and other artifacts.

- **Basic**: lowest cost, smaller storage and throughput, fine for demos and low-volume dev workloads.
- **Standard**: higher throughput and storage, good default for team environments.
- **Premium**: adds advanced networking and enterprise features such as geo-replication and private endpoints.
- **Geo-replication**: Premium feature that keeps replicas close to the regions where you deploy, reducing pull latency and improving resiliency.

Create a Standard registry:

```bash
az acr create \
  --name mycontainerseriesacr \
  --resource-group rg-container-series \
  --sku Standard \
  --admin-enabled false
```

- `--sku Standard` picks the middle tier used in this talk.
- `--admin-enabled false` avoids shared registry credentials.

Check registry details:

```bash
az acr show \
  --name mycontainerseriesacr \
  --resource-group rg-container-series \
  --output table
```

This confirms the login server, SKU, and provisioning status.

### 2) Authentication: admin user vs service principal vs managed identity

You have three common ways to authenticate to ACR:

1. **Admin user** - easy for demos, but it creates long-lived username/password credentials. Avoid for production.
2. **Service principal** - better than admin user for automation, but still requires secret or certificate management.
3. **Managed identity** - preferred for Azure-hosted workloads because Azure manages identity lifecycle and you assign roles directly.

Enable the admin user only if you absolutely need it for a lab:

```bash
az acr update \
  --name mycontainerseriesacr \
  --admin-enabled true
```

Create a service principal with AcrPush:

```bash
ACR_ID=$(az acr show --name mycontainerseriesacr --query id -o tsv)

az ad sp create-for-rbac \
  --name sp-acr-push \
  --role AcrPush \
  --scopes "$ACR_ID"
```

Recommended App Service pattern: enable a managed identity on the web app and grant `AcrPull` on the registry:

```bash
PRINCIPAL_ID=$(az webapp identity assign \
  --name my-todo-api \
  --resource-group rg-container-series \
  --query principalId -o tsv)

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "$ACR_ID"
```

This removes the need to store registry passwords in app settings.

### 3) `az acr login` and pushing images

Authenticate Docker to the registry:

```bash
az acr login --name mycontainerseriesacr
```

Get the registry login server:

```bash
ACR_LOGIN_SERVER=$(az acr show \
  --name mycontainerseriesacr \
  --query loginServer -o tsv)
```

Build, tag, and push the Rust API image:

```bash
docker build -t talk05-todo-api:v1 .
docker tag talk05-todo-api:v1 "$ACR_LOGIN_SERVER/talk05-todo-api:v1"
docker push "$ACR_LOGIN_SERVER/talk05-todo-api:v1"
```

- `docker build` produces the local image.
- `docker tag` rewrites the image reference to the ACR login server.
- `docker push` uploads the image layers to ACR.

List repositories and tags:

```bash
az acr repository list \
  --name mycontainerseriesacr \
  --output table

az acr repository show-tags \
  --name mycontainerseriesacr \
  --repository talk05-todo-api \
  --output table
```

### 4) ACR Tasks

ACR Tasks let Azure build images for you in the cloud.

#### Quick task

```bash
az acr build \
  --registry mycontainerseriesacr \
  --image talk05-todo-api:latest \
  .
```

This uploads the current directory to Azure and runs the container build in ACR.

#### Triggered task on Git commits

```bash
az acr task create \
  --registry mycontainerseriesacr \
  --name talk05-commit-build \
  --context https://github.com/your-org/your-repo.git \
  --file Dockerfile \
  --image talk05-todo-api:{{.Run.ID}} \
  --branch main \
  --git-access-token <git-token> \
  --commit-trigger-enabled true \
  --base-image-trigger-enabled true
```

- `--commit-trigger-enabled true` rebuilds on source changes.
- `--base-image-trigger-enabled true` rebuilds when the base image publishes updates.

#### Scheduled task

```bash
az acr task create \
  --registry mycontainerseriesacr \
  --name talk05-nightly-build \
  --context https://github.com/your-org/your-repo.git \
  --file Dockerfile \
  --image talk05-todo-api:nightly \
  --schedule "0 2 * * *"
```

This runs every day at 02:00 UTC.

Inspect runs and logs:

```bash
az acr task list-runs \
  --registry mycontainerseriesacr \
  --output table

az acr task logs \
  --registry mycontainerseriesacr \
  --run-id <run-id>
```

### 5) Repository management and retention policies

List repositories:

```bash
az acr repository list \
  --name mycontainerseriesacr \
  --output table
```

Show manifests for a repository:

```bash
az acr manifest list-metadata \
  --registry mycontainerseriesacr \
  --name talk05-todo-api \
  --output table
```

Delete an old tag:

```bash
az acr repository delete \
  --name mycontainerseriesacr \
  --image talk05-todo-api:old \
  --yes
```

Retention policies help clean up untagged manifests automatically. They are most relevant in Premium-tier governance conversations:

```bash
az acr config retention update \
  --registry mycontainerseriesacr \
  --status Enabled \
  --days 7 \
  --type UntaggedManifests
```

### 6) Deploying to Azure App Service for Containers

Create a Linux App Service plan:

```bash
az appservice plan create \
  --name talk05-plan \
  --resource-group rg-container-series \
  --sku B1 \
  --is-linux
```

Create the web app:

```bash
az webapp create \
  --name my-todo-api \
  --resource-group rg-container-series \
  --plan talk05-plan
```

Configure the container image:

```bash
az webapp config container set \
  --name my-todo-api \
  --resource-group rg-container-series \
  --container-image-name "$ACR_LOGIN_SERVER/talk05-todo-api:v1"
```

Configure the app to listen on port 8080:

```bash
az webapp config appsettings set \
  --name my-todo-api \
  --resource-group rg-container-series \
  --settings WEBSITES_PORT=8080 ENVIRONMENT=production APP_VERSION=v1
```

When managed identity is used for image pulls, the platform authenticates to ACR without registry secrets.

### 7) Continuous deployment via ACR webhook

Enable container continuous deployment:

```bash
az webapp deployment container config \
  --enable-cd true \
  --name my-todo-api \
  --resource-group rg-container-series
```

App Service creates an ACR webhook so a new image push can trigger an app restart and image refresh.

Check deployment webhook state:

```bash
az webapp deployment container show-cd-url \
  --name my-todo-api \
  --resource-group rg-container-series
```

### 8) Deployment slots: staging -> production swap

Create a staging slot:

```bash
az webapp deployment slot create \
  --name my-todo-api \
  --resource-group rg-container-series \
  --slot staging
```

Point the slot at a candidate image:

```bash
az webapp config container set \
  --name my-todo-api \
  --resource-group rg-container-series \
  --slot staging \
  --container-image-name "$ACR_LOGIN_SERVER/talk05-todo-api:v2"
```

Swap staging into production:

```bash
az webapp deployment slot swap \
  --name my-todo-api \
  --resource-group rg-container-series \
  --slot staging \
  --target-slot production
```

Slots reduce risk by letting you validate before the production cutover.

### 9) App Service logging and diagnostics

Enable filesystem logging:

```bash
az webapp log config \
  --name my-todo-api \
  --resource-group rg-container-series \
  --docker-container-logging filesystem \
  --application-logging filesystem \
  --level information
```

Tail logs live:

```bash
az webapp log tail \
  --name my-todo-api \
  --resource-group rg-container-series
```

Query the app URL:

```bash
az webapp show \
  --name my-todo-api \
  --resource-group rg-container-series \
  --query defaultHostName -o tsv
```

Use Application Insights for request tracing, dependency tracking, failures, and live metrics.

### 10) Infrastructure as Code with Bicep

Deploy everything in one shot:

```bash
az deployment group create \
  --resource-group rg-container-series \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.json \
  --parameters acrName=mycontainerseriesacr \
               appServicePlanName=talk05-plan \
               webAppName=my-todo-api \
               location=eastus \
               imageName=talk05-todo-api \
               imageTag=v1
```

This template creates:

- Azure Container Registry (Standard)
- Linux App Service Plan (B1)
- Web App for Containers
- System-assigned managed identity
- `AcrPull` role assignment on the registry
- Log Analytics + Application Insights
- Required app settings such as `WEBSITES_PORT`, `ENVIRONMENT`, and `APP_VERSION`

## Demo flow suggestion

1. Run the API locally with `cargo run`.
2. Build and test the container with `docker build`.
3. Create ACR and push the image.
4. Deploy infra with Bicep.
5. Verify `https://<app>.azurewebsites.net/health`.
6. Push a new image and show continuous deployment.
7. Use a staging slot, validate `/info`, then swap.

## Key takeaways

- ACR is the secure home for private container images in Azure.
- Prefer **managed identity** over admin users and long-lived secrets.
- `az acr build` is a great option when you do not want local Docker builds in CI.
- App Service for Containers gives a simple PaaS path for containerized web apps.
- Deployment slots and diagnostics help you ship safely.
- Bicep keeps the environment repeatable and reviewable.

## Bonus: ACR Artifact Streaming

ACR Artifact Streaming reduces cold-start pull time by streaming image data on demand instead of waiting for every layer to download before start-up. It is useful for large images, scale-out events, and globally distributed workloads. If you need faster startup for containerized apps, it is worth tracking as an advanced ACR capability alongside geo-replication and tasks.

## Helpful scripts

- `scripts/deploy.sh` - end-to-end resource group, ACR, push, Bicep deploy, and health check
- `scripts/acr-tasks.sh` - quick build, Git-triggered task, scheduled task, run listing, and log lookup
