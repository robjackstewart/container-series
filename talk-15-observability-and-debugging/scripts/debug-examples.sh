#!/bin/bash
set -euo pipefail

# Container debugging commands reference for Talk 15.

echo "=== Basic Container Debugging ==="
echo "Follow the latest structured logs from the Phoenix app"
docker logs app --follow --tail 100

echo "Open a shell inside the running container"
docker exec -it app sh

echo "Copy the generated release config out of the container"
docker cp app:/app/releases/0.1.0/sys.config ./extracted-sys.config

echo "Show one-shot container resource usage"
docker stats app --no-stream

echo "Inspect state, networking, and mounts"
docker inspect app | jq '.[] | {State, NetworkSettings, Mounts}'

echo "=== Debugging Distroless/Minimal Containers ==="
echo "Attach Docker's debug toolbox (great when the image has no shell)"
docker debug app

echo "Alternative namespace entry for Linux hosts"
PID=$(docker inspect --format '{{.State.Pid}}' app)
sudo nsenter -t "$PID" -m -u -i -n -p

echo "=== Container Forensics ==="
echo "Show file changes since the container started"
docker diff app

echo "Capture a stopped container for post-mortem analysis"
docker commit stopped-app app-debug
docker run -it --entrypoint sh app-debug

echo "=== Kubernetes Debugging ==="
echo "Stream logs from the deployment"
kubectl logs -n container-series deployment/app --follow

echo "Open a shell in a running pod"
kubectl exec -it -n container-series pod/app-xxx -- sh

echo "Launch an ephemeral debug container targeting the main app container"
kubectl debug -it pod/app-xxx --image=busybox --target=app

echo "Copy config or artifacts out of a pod"
kubectl cp container-series/app-xxx:/app ./app-copy

echo "Inspect recent cluster events (useful for CrashLoopBackOff)"
kubectl get events -n container-series --sort-by='.lastTimestamp'
