#!/bin/bash
set -euo pipefail
# =============================================================
# Container Debugging Commands Reference — Talk 15
# =============================================================

echo "=== Basic Container Debugging ==="

# View container logs (streaming)
docker logs talk-15-app-1 --follow --tail 100

# Filter logs (structured JSON logging makes grep powerful)
docker logs talk-15-app-1 2>&1 | grep '"level":"error"'

# Execute into a running container
docker exec -it talk-15-app-1 sh

# Copy a file OUT of a container
docker cp talk-15-app-1:/app/releases/RELEASES ./extracted-releases.txt

# Copy a file INTO a container
docker cp ./debug-config.txt talk-15-app-1:/tmp/debug-config.txt

# Container stats (live resource usage)
docker stats talk-15-app-1 --no-stream

# Full container inspection
docker inspect talk-15-app-1 | jq '.[0] | {State, NetworkSettings: .NetworkSettings.IPAddress, Mounts}'

echo ""
echo "=== Container Forensics ==="

# See what files changed inside a running container (compared to image)
docker diff talk-15-app-1
# A = Added, C = Changed, D = Deleted

echo ""
echo "=== Debugging Distroless / Minimal Containers ==="
# These containers have NO shell — traditional 'docker exec -it ... sh' fails!

# Option 1: docker debug (Docker Desktop 4.27+)
# Attaches a toolbox container with full debug tools to ANY container
docker debug talk-15-app-1

# Option 2: Post-mortem debugging - commit and explore
# For a stopped container:
docker commit stopped-container-name talk-15-debug-image
docker run -it --entrypoint sh talk-15-debug-image

# Option 3: nsenter (Linux only - access container namespaces from host)
CONTAINER_PID=$(docker inspect --format '{{.State.Pid}}' talk-15-app-1)
echo "Container PID: $CONTAINER_PID"
# sudo nsenter -t $CONTAINER_PID -m -u -i -n -p

echo ""
echo "=== Kubernetes Debugging ==="

# Get logs from a pod
kubectl logs -n container-series deploy/app --follow --tail 100

# Execute into a running pod
kubectl exec -it -n container-series pod/app-xxx -- sh

# Ephemeral debug container (works even on distroless!)
# kubectl debug -it pod/app-xxx --image=busybox:1.36 --target=app -n container-series

# Debug a node
# kubectl debug node/aks-system-12345 -it --image=ubuntu

# Copy from pod
kubectl cp container-series/app-xxx:/tmp/heapdump.hprof ./heapdump.hprof

# Kubernetes events (great for diagnosing CrashLoopBackOff, ImagePullBackOff)
kubectl get events -n container-series --sort-by='.lastTimestamp' | tail -20

# Describe pod for detailed status
kubectl describe pod -n container-series app-xxx