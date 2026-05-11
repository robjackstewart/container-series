#!/bin/bash
# ACR Tasks Examples - Build images in Azure without local Docker

REGISTRY_NAME="containerseriesacr"
RESOURCE_GROUP="container-series-rg"
GITHUB_REPO="https://github.com/YOUR_ORG/container-series"
IMAGE_NAME="rust-todo-api"

echo "=== ACR Tasks ==="

# 1. Quick task: Build directly in ACR (no local Docker needed!)
echo "Quick task: build in ACR..."
az acr build \
  --registry "$REGISTRY_NAME" \
  --image "$IMAGE_NAME:{{.Run.ID}}" \
  --file talk-05-acr-and-app-service/Dockerfile \
  talk-05-acr-and-app-service/

# 2. Create a triggered task (runs on git push)
echo "Creating git-triggered task..."
az acr task create \
  --registry "$REGISTRY_NAME" \
  --name "build-on-push" \
  --image "$IMAGE_NAME:{{.Run.ID}}" \
  --context "$GITHUB_REPO" \
  --file "talk-05-acr-and-app-service/Dockerfile" \
  --git-access-token "YOUR_PAT_TOKEN"

# 3. Create a scheduled task (e.g., nightly rebuild for base image updates)
echo "Creating scheduled task..."
az acr task create \
  --registry "$REGISTRY_NAME" \
  --name "nightly-rebuild" \
  --image "$IMAGE_NAME:nightly" \
  --context "$GITHUB_REPO" \
  --file "talk-05-acr-and-app-service/Dockerfile" \
  --schedule "0 2 * * *"  # 2 AM daily

# 4. List task runs
echo "Listing task runs..."
az acr task list-runs --registry "$REGISTRY_NAME" --output table

# 5. View logs of last run
echo "Viewing last run logs..."
LAST_RUN=$(az acr task list-runs --registry "$REGISTRY_NAME" --query '[0].runId' -o tsv)
az acr task logs --registry "$REGISTRY_NAME" --run-id "$LAST_RUN"

# 6. Enable base image update triggers
# When mcr.microsoft.com/dotnet/runtime:8.0 updates, rebuild automatically
az acr task update \
  --registry "$REGISTRY_NAME" \
  --name "build-on-push" \
  --base-image-trigger-enabled true

echo "=== Repository Management ==="

# 7. List repositories
az acr repository list --name "$REGISTRY_NAME" --output table

# 8. List tags for an image
az acr repository show-tags \
  --name "$REGISTRY_NAME" \
  --repository "$IMAGE_NAME" \
  --orderby time_desc \
  --output table

# 9. Set retention policy (delete untagged manifests after 7 days)
az acr config retention update \
  --registry "$REGISTRY_NAME" \
  --status enabled \
  --days 7 \
  --type UntaggedManifests