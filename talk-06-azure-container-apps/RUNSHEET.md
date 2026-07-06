# RUNSHEET — Talk 06: Azure Container Apps

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Copy your CA cert to `certs/netskope.crt` and add `--secret id=netskope_cert,src=certs/netskope.crt` to any `docker build` command below.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] Azure CLI installed — `az version`
- [ ] ACA extension available — `az extension add --name containerapp --upgrade --yes`
- [ ] Logged in — `az login` and `az account show -o table`
- [ ] Correct subscription selected — set `AZURE_SUBSCRIPTION` or run `az account set --subscription <id-or-name>`
- [ ] (if behind Netskope) corporate `.crt` saved as `certs/netskope.crt`
- [ ] Warm the caches — `docker pull maven:3.9.9-eclipse-temurin-21; docker pull eclipse-temurin:21-jre`
- [ ] Terminal in `talk-06-azure-container-apps`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Login, select subscription, and prepare variables
az login
export AZURE_SUBSCRIPTION="${AZURE_SUBSCRIPTION:-}"
if [ -n "$AZURE_SUBSCRIPTION" ]; then az account set --subscription "$AZURE_SUBSCRIPTION"; fi
az account show -o table
az extension add --name containerapp --upgrade --yes
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerRegistry

export RESOURCE_GROUP="container-series-rg"
export LOCATION="uksouth"
export ACR_NAME="${ACR_NAME:-containerseriesacr$RANDOM}"
export ENVIRONMENT_NAME="container-series-env"
export IMAGE_TAG="v1"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az acr create --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --sku Standard --admin-enabled false
export ACR_SERVER="$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)"
az acr login --name "$ACR_NAME"

# 2) Build and push the Spring Boot service and job images
DOCKER_BUILDKIT=1 docker build -f service/Dockerfile \
  ${NETSKOPE_CERT:+--secret id=netskope_cert,src="$NETSKOPE_CERT"} \
  -t "$ACR_SERVER/order-service:$IMAGE_TAG" .  # export NETSKOPE_CERT=certs/netskope.crt if behind Netskope
docker push "$ACR_SERVER/order-service:$IMAGE_TAG"
DOCKER_BUILDKIT=1 docker build -f job/Dockerfile \
  ${NETSKOPE_CERT:+--secret id=netskope_cert,src="$NETSKOPE_CERT"} \
  -t "$ACR_SERVER/order-job:$IMAGE_TAG" .
docker push "$ACR_SERVER/order-job:$IMAGE_TAG"

# 3) Deploy the ACA environment, Dapr component, service, and scheduled job
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json \
  --parameters acrName="$ACR_NAME" environmentName="$ENVIRONMENT_NAME" location="$LOCATION" serviceImageTag="$IMAGE_TAG" jobImageTag="$IMAGE_TAG"

# 4) Smoke-test ingress and create a sample order
export SERVICE_FQDN="$(az containerapp show --name order-service --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv)"
curl -fsS "https://$SERVICE_FQDN/health"
curl -fsS -X POST "https://$SERVICE_FQDN/orders" \
  -H "Content-Type: application/json" \
  -d '{"customerId":"cust-1001","product":"Azure Container Apps Workshop","quantity":2}'

# 5) Create a new revision and split traffic 90/10
az containerapp revision set-mode --name order-service --resource-group "$RESOURCE_GROUP" --mode multiple
az containerapp update --name order-service --resource-group "$RESOURCE_GROUP" --set-env-vars DAPR_ENABLED=true ENVIRONMENT=canary REVISION_LABEL=canary
mapfile -t REVISIONS < <(az containerapp revision list --name order-service --resource-group "$RESOURCE_GROUP" --query "sort_by([].{name:name,created:properties.createdTime}, &created)[].name" -o tsv)
REV_COUNT=${#REVISIONS[@]}
export OLD_REV="${REVISIONS[$((REV_COUNT-2))]}"
export NEW_REV="${REVISIONS[$((REV_COUNT-1))]}"
az containerapp ingress traffic set --name order-service --resource-group "$RESOURCE_GROUP" --revision-weight "$OLD_REV=90" "$NEW_REV=10"
az containerapp show --name order-service --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.traffic -o table

# 6) Demonstrate scale settings and generate a short burst of HTTP traffic
az containerapp show --name order-service --resource-group "$RESOURCE_GROUP" --query properties.template.scale -o json
for i in {1..40}; do curl -fsS "https://$SERVICE_FQDN/health" >/dev/null & done; wait
az containerapp replica list --name order-service --resource-group "$RESOURCE_GROUP" -o table

# 7) Start the scheduled job manually and inspect executions
az containerapp job start --name order-processor-job --resource-group "$RESOURCE_GROUP"
az containerapp job execution list --name order-processor-job --resource-group "$RESOURCE_GROUP" -o table

# 8) Bonus pointers: inspect available job and scale-rule surfaces
az containerapp job create --help | grep -E "trigger-type|scale-rule|cron" || true
az containerapp update --help | grep -E "scale-rule|replica" || true
```

## Beat-by-beat talking points
1. Login and provider registration are cloud-demo hygiene; subscription drift is the easiest way to lose five minutes.
2. The images are normal Spring Boot containers: Maven in the build stage, a JRE in runtime, and non-root users.
3. The Bicep deployment creates the environment boundary, Log Analytics, Dapr state component, service, job, identities, and ACR pull roles.
4. The health call proves ingress; the order call gives Dapr state persistence something to do.
5. Revisions make canary release a platform routing decision rather than application code.
6. Scaling is KEDA-backed: HTTP concurrency is the visible demo, but queues, cron, and custom scalers follow the same mental model.
7. The job shows a run-to-completion workload with execution history rather than a permanently running worker.
8. The bonus help output is a safe way to point at event jobs, cron, and scaling surfaces without needing a live queue.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild from the talk folder. Default `certs/` is empty = no-op.
- **`COPY certs/` fails** → build context is wrong. Use `docker build -f service/Dockerfile ... .` or `docker build -f job/Dockerfile ... .` from the talk folder, not `docker build service/`.
- **Azure auth fails** → run `az login`, then `az account show -o table`. If the wrong tenant or subscription is active, set `AZURE_SUBSCRIPTION` and re-run the first block.
- **ACR name is unavailable** → set a unique lowercase name, for example `export ACR_NAME=containerseries$RANDOM`, then re-run the create/build steps.
- **Image pull fails after deployment** → wait for ACR role assignment propagation, then restart or update the app/job.
- **Canary variables are empty** → confirm two revisions exist with `az containerapp revision list --name order-service --resource-group "$RESOURCE_GROUP" -o table`.

## Reset / cleanup
```bash
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
docker rmi "$ACR_SERVER/order-service:$IMAGE_TAG" "$ACR_SERVER/order-job:$IMAGE_TAG" 2>/dev/null || true
```
