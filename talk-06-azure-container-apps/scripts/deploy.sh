#!/bin/bash
set -euo pipefail

REGISTRY_NAME="${REGISTRY_NAME:-containerseriesacr$RANDOM}"
RESOURCE_GROUP="${RESOURCE_GROUP:-container-series-rg}"
LOCATION="${LOCATION:-uksouth}"

echo "=== Talk 06: Azure Container Apps Deployment ==="

# 1. Install Container Apps extension
az account show -o table
az extension add --name containerapp --upgrade --yes
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerRegistry

# 2. Create resource group and ACR (if not already done from Talk 05)
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az acr create --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --sku Standard --admin-enabled false 2>/dev/null || echo "ACR already exists"

ACR_SERVER=$(az acr show --name "$REGISTRY_NAME" --query loginServer -o tsv)
az acr login --name "$REGISTRY_NAME"

# 3. Build and push service image
echo "Building order service..."
DOCKER_BUILDKIT=1 docker build -f service/Dockerfile --build-arg EXTRA_CERTS_DIR=certs -t "$ACR_SERVER/order-service:latest" .
docker push "$ACR_SERVER/order-service:latest"

# 4. Build and push job image
echo "Building order processor job..."
DOCKER_BUILDKIT=1 docker build -f job/Dockerfile --build-arg EXTRA_CERTS_DIR=certs -t "$ACR_SERVER/order-job:latest" .
docker push "$ACR_SERVER/order-job:latest"

# 5. Deploy infrastructure
echo "Deploying Container Apps..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json \
  --parameters acrName="$REGISTRY_NAME" location="$LOCATION" serviceImageTag=latest jobImageTag=latest

# 6. Get service URL
SERVICE_URL=$(az containerapp show \
  --name order-service \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn -o tsv)
echo "Service URL: https://$SERVICE_URL"

# 7. Health check
curl -f "https://$SERVICE_URL/health" && echo " Service is healthy!"

# 8. Trigger job manually
echo "Triggering job manually..."
az containerapp job start \
  --name order-processor-job \
  --resource-group "$RESOURCE_GROUP"

echo "=== Deployment complete! ==="
echo "Service: https://$SERVICE_URL"
echo "Monitor logs: az containerapp logs show --name order-service --resource-group $RESOURCE_GROUP --follow"
