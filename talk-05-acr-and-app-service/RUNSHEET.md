# RUNSHEET — Talk 05: ACR and App Service

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — every build trusts it automatically.

## Pre-flight (before you walk in)
- [ ] Azure CLI installed — `az version`
- [ ] Logged in — `az login`
- [ ] Correct subscription selected — `az account show --query "{name:name, id:id, tenant:tenantId}" -o table`
- [ ] Docker Desktop running for the optional local push path — `docker version`
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/`
- [ ] Warm the caches — `az provider register --namespace Microsoft.ContainerRegistry; az provider register --namespace Microsoft.Web`
- [ ] Terminal in `talk-05-acr-and-app-service`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Confirm Azure auth and set deterministic demo variables
az login
az account show --query "{name:name, id:id, tenant:tenantId}" -o table
RESOURCE_GROUP="container-series-rg"
LOCATION="uksouth"
UNIQUE_SUFFIX="$(date +%H%M%S)$RANDOM"
ACR_NAME="cs05${UNIQUE_SUFFIX}"
PLAN_NAME="container-series-plan"
APP_NAME="container-series-talk05-${UNIQUE_SUFFIX}"
IMAGE_NAME="rust-todo-api"
IMAGE_TAG="latest"

# 2) Create the resource group and preview the Bicep deployment
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az deployment group what-if \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters acrName="$ACR_NAME" appServicePlanName="$PLAN_NAME" webAppName="$APP_NAME" imageName="$IMAGE_NAME" imageTag="$IMAGE_TAG"

# 3) Deploy ACR, App Service, managed identity, and AcrPull role assignment
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters acrName="$ACR_NAME" appServicePlanName="$PLAN_NAME" webAppName="$APP_NAME" imageName="$IMAGE_NAME" imageTag="$IMAGE_TAG"
ACR_LOGIN_SERVER="$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)"
ACR_ID="$(az acr show --name "$ACR_NAME" --query id -o tsv)"

# 4) Build and push in Azure with ACR Tasks
az acr build \
  --registry "$ACR_NAME" \
  --image "$IMAGE_NAME:$IMAGE_TAG" \
  --file Dockerfile \
  .
az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --orderby time_desc -o table

# 5) Restart App Service and smoke-test production
az webapp restart --name "$APP_NAME" --resource-group "$RESOURCE_GROUP"
APP_URL="https://$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)"
sleep 30
curl -fsS "$APP_URL/health"
curl -fsS "$APP_URL/info"

# 6) Optional local build-and-push path for contrast
az acr login --name "$ACR_NAME"
docker build --build-arg EXTRA_CERTS_DIR=certs -t "$ACR_LOGIN_SERVER/$IMAGE_NAME:local" .
docker push "$ACR_LOGIN_SERVER/$IMAGE_NAME:local"

# 7) Build a candidate image, deploy it to staging, then swap
az acr build --registry "$ACR_NAME" --image "$IMAGE_NAME:candidate" --file Dockerfile .
az webapp deployment slot create \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --slot staging \
  --configuration-source "$APP_NAME"
SLOT_PRINCIPAL_ID="$(az webapp identity assign --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --slot staging --query principalId -o tsv)"
az role assignment create \
  --assignee-object-id "$SLOT_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "$ACR_ID"
az webapp config container set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --slot staging \
  --docker-custom-image-name "$ACR_LOGIN_SERVER/$IMAGE_NAME:candidate"
az webapp restart --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --slot staging
sleep 30
curl -fsS "https://${APP_NAME}-staging.azurewebsites.net/health"
az webapp deployment slot swap \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --slot staging \
  --target-slot production
curl -fsS "$APP_URL/info"

# 8) Bonus: Artifact Streaming and quarantine-style promotion
az acr update --name "$ACR_NAME" --sku Premium
az acr artifact-streaming create --name "$ACR_NAME" --image "$IMAGE_NAME:$IMAGE_TAG"
az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --orderby time_desc -o table
```

## Beat-by-beat talking points
1. Azure login and subscription checks prevent the most common cloud-demo mistake: deploying into the wrong tenant or subscription.
2. `what-if` makes Bicep safe to discuss before changing anything live.
3. The deployment creates the registry, Linux App Service plan, web app identity, and `AcrPull` role assignment as one repeatable unit.
4. ACR Tasks move the build into Azure and remove the dependency on the presenter's local Docker daemon.
5. The health checks prove image pull, port wiring, environment settings, and the Rust process.
6. The local push path is optional; use it only if you want to contrast Docker credential flow with server-side builds.
7. Staging gets the candidate tag first, warms up, then swaps into production.
8. Artifact Streaming is a Premium optimisation for larger images; quarantine is the release discipline of not promoting a candidate until checks pass.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. Default `certs/` is empty = no-op.
- **Azure auth fails** → run `az login`, then `az account show`; if the wrong subscription is selected, run `az account set --subscription "<name-or-id>"`.
- **ACR name already exists** → set a new lowercase alphanumeric `ACR_NAME`; registry names are globally unique.
- **App Service cannot pull the image** → wait a minute for `AcrPull` role propagation, then restart the web app.
- **Slot commands fail** → confirm the plan is Standard or higher; deployment slots are not available on the Basic tier.
- **Artifact Streaming fails** → confirm the registry has been upgraded to Premium and the Azure CLI has the `az acr artifact-streaming` command.

## Reset / cleanup
```bash
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
docker image rm "$ACR_LOGIN_SERVER/$IMAGE_NAME:local" 2>/dev/null || true
```
