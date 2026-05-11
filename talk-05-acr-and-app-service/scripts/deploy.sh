#!/usr/bin/env bash
set -euo pipefail

# Set deployment variables. Override these with environment variables if required.
REGISTRY_NAME="${REGISTRY_NAME:-containerseriesacr$RANDOM}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-container-series-talk05}"
LOCATION="${LOCATION:-eastus}"
APP_NAME="${APP_NAME:-container-series-talk05-$RANDOM}"
IMAGE_NAME="${IMAGE_NAME:-talk05-todo-api}"
IMAGE_TAG="${IMAGE_TAG:-v1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. Create or update the resource group that will hold ACR, App Service, and monitoring resources.
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

# 2. Create Azure Container Registry in Standard tier with the admin user disabled.
az acr create \
  --name "$REGISTRY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Standard \
  --admin-enabled false \
  --location "$LOCATION"

# 3. Authenticate the local Docker client with Azure Container Registry.
az acr login --name "$REGISTRY_NAME"
ACR_LOGIN_SERVER="$(az acr show --name "$REGISTRY_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer -o tsv)"

# 4. Build the Rust API image locally, tag it for the registry, and push it to ACR.
docker build -t "$IMAGE_NAME:$IMAGE_TAG" "$PROJECT_DIR"
docker tag "$IMAGE_NAME:$IMAGE_TAG" "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
docker push "$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# 5. Deploy Azure infrastructure with Bicep and point App Service at the pushed image.
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$PROJECT_DIR/infra/main.bicep" \
  --parameters @"$PROJECT_DIR/infra/parameters.json" \
  --parameters acrName="$REGISTRY_NAME" \
               appServicePlanName="$APP_NAME-plan" \
               webAppName="$APP_NAME" \
               location="$LOCATION" \
               imageName="$IMAGE_NAME" \
               imageTag="$IMAGE_TAG"

# 6. Retrieve the default hostname so the deployed endpoint can be tested.
DEFAULT_HOSTNAME="$(az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)"
echo "App URL: https://$DEFAULT_HOSTNAME"

# 7. Run a simple health check against the deployed application.
curl --fail --silent --show-error "https://$DEFAULT_HOSTNAME/health"
echo
