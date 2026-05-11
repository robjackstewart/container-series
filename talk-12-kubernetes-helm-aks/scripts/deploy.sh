#!/bin/bash
set -euo pipefail

CLUSTER_NAME="container-series-aks"
REGISTRY_NAME="containerseriesacr"
RESOURCE_GROUP="container-series-rg"
LOCATION="uksouth"
NAMESPACE="container-series"
IMAGE_NAME="talk-12"
IMAGE_TAG="${1:-1.0.0}"
HELM_RELEASE="container-series-app"

echo "=== Talk 12: Kubernetes, Helm & AKS Deployment ==="

# 1. Create infrastructure
echo "Deploying AKS + ACR infrastructure..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters infra/parameters.json

ACR_SERVER=$(az acr show --name "$REGISTRY_NAME" --query loginServer -o tsv)

# 2. Build and push image
echo "Building and pushing Kotlin/Ktor image..."
az acr login --name "$REGISTRY_NAME"
docker build -t "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG" .
docker push "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# 3. Get AKS credentials
echo "Getting AKS credentials..."
az aks get-credentials --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --overwrite-existing

# 4. Apply raw k8s manifests (for educational demo)
echo "Applying raw Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

echo "Pods status (raw k8s):"
kubectl get pods -n "$NAMESPACE"

# 5. Install via Helm (the proper way)
echo "Installing via Helm..."
helm upgrade --install "$HELM_RELEASE" ./helm/container-series-app \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --set image.repository="$ACR_SERVER/$IMAGE_NAME" \
  --set image.tag="$IMAGE_TAG" \
  --set config.appVersion="$IMAGE_TAG" \
  --wait \
  --timeout 5m

echo "Helm release status:"
helm status "$HELM_RELEASE" -n "$NAMESPACE"

# 6. Run Helm tests
echo "Running Helm tests..."
helm test "$HELM_RELEASE" --namespace "$NAMESPACE"

echo "=== Deployment complete! ==="
kubectl get all -n "$NAMESPACE"
