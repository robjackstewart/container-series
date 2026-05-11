#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-containerseriesacr12345}"
IMAGE_NAME="${IMAGE_NAME:-myapp}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/your-org/your-repo.git}"
GIT_ACCESS_TOKEN="${GIT_ACCESS_TOKEN:-replace-me}"
QUICK_TASK_NAME="${QUICK_TASK_NAME:-talk05-commit-build}"
SCHEDULED_TASK_NAME="${SCHEDULED_TASK_NAME:-talk05-nightly-build}"
RUN_ID="${RUN_ID:-}"

# 1. Quick task: send the current source context to Azure and let ACR build the image remotely.
az acr build \
  --registry "$REGISTRY" \
  --image "$IMAGE_NAME:latest" \
  .

# 2. Triggered task: automatically rebuild when a commit lands in the Git repository.
#    The access token can be a GitHub PAT stored in an environment variable.
az acr task create \
  --registry "$REGISTRY" \
  --name "$QUICK_TASK_NAME" \
  --context "$GIT_REPO_URL" \
  --file Dockerfile \
  --image "$IMAGE_NAME:{{.Run.ID}}" \
  --branch main \
  --git-access-token "$GIT_ACCESS_TOKEN" \
  --commit-trigger-enabled true \
  --base-image-trigger-enabled true

# 3. Scheduled task: rebuild on a cron schedule, useful for nightly validation or cache warming.
az acr task create \
  --registry "$REGISTRY" \
  --name "$SCHEDULED_TASK_NAME" \
  --context "$GIT_REPO_URL" \
  --file Dockerfile \
  --image "$IMAGE_NAME:nightly" \
  --schedule "0 2 * * *"

# 4. List task runs so you can inspect recent build history.
az acr task list-runs \
  --registry "$REGISTRY" \
  --output table

# 5. Show logs for a specific run when RUN_ID is provided.
if [[ -n "$RUN_ID" ]]; then
  az acr task logs \
    --registry "$REGISTRY" \
    --run-id "$RUN_ID"
else
  echo "Set RUN_ID to inspect logs for a specific task run."
fi

# 6. Base image update trigger note:
#    --base-image-trigger-enabled true tells ACR Tasks to rebuild automatically when a parent image changes,
#    helping you pick up security patches from rust:1.75-slim or debian:bookworm-slim without waiting for app code changes.
