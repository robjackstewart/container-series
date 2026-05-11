#!/bin/bash
set -euo pipefail

REGISTRY_NAME="containerseriesacr"
RESOURCE_GROUP="container-series-rg"
LOCATION="uksouth"

echo "=== Talk 06: Azure Container Apps Deployment ==="

# 1. Install Container Apps extension
az extension add --name containerapp --upgrade --yes

# 2. Create resource group and ACR (if not already done from Talk 05)
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az acr create --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --sku Standard --admin-enabled false 2>/dev/null || echo "ACR already exists"

ACR_SERVER=$(az acr show --name "$REGISTRY_NAME" --query loginServer -o tsv)
az acr login --name "$REGISTRY_NAME"

# 3. Build and push service image
echo "Building order service..."
docker build -t "$ACR_SERVER/order-service:latest" service/
docker push "$ACR_SERVER/order-service:latest"

# 4. Build and push job image
echo "Building order processor job..."
docker build -t "$ACR_SERVER/order-job:latest" job/
docker push "$ACR_SERVER/order-job:latest"

# 5. Deploy infrastructure
echo "Deploying Container Apps..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json

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
