#!/bin/bash
set -euo pipefail

: "${APP_NAME:?APP_NAME is required}"
: "${RESOURCE_GROUP:?RESOURCE_GROUP is required}"
: "${REGISTRY:?REGISTRY is required}"
: "${IMAGE:?IMAGE is required}"
: "${TAG:?TAG is required}"
: "${ENVIRONMENT:?ENVIRONMENT is required}"

az containerapp update \
  --name "$APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$REGISTRY/$IMAGE:$TAG" \
  --set-env-vars "ENVIRONMENT=$ENVIRONMENT" "APP_VERSION=$TAG"
