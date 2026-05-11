#!/bin/bash
set -euo pipefail

# Configuration
REGISTRY_NAME="containerseriesacr"
RESOURCE_GROUP="container-series-rg"
LOCATION="uksouth"
APP_NAME="container-series-talk05"
IMAGE_NAME="rust-todo-api"
IMAGE_TAG="${1:-latest}"

echo "=== Talk 05: ACR & App Service Deployment ==="
echo "Registry: $REGISTRY_NAME"
echo "Image: $IMAGE_NAME:$IMAGE_TAG"

# 1. Create resource group
echo "Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# 2. Deploy Bicep (creates ACR + App Service)
echo "Deploying infrastructure..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json \
  --parameters imageTag="$IMAGE_TAG"

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name "$REGISTRY_NAME" --query loginServer -o tsv)

# 3. Login to ACR
echo "Logging in to ACR..."
az acr login --name "$REGISTRY_NAME"

# 4. Build and push image
echo "Building and pushing image..."
docker build -t "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG" .
docker push "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# 5. Update App Service to use new image
echo "Updating App Service..."
az webapp config container set \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --docker-custom-image-name "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# 6. Get the app URL
APP_URL=$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)
echo "App deployed to: https://$APP_URL"

# 7. Health check
echo "Running health check..."
sleep 30
curl -f "https://$APP_URL/health" && echo " Health check passed!"