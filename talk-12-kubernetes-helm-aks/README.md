# Kubernetes, Helm & Azure Kubernetes Service (AKS)

Talk 12 in the Container Series builds on Talks 1-11 and shows how to package, deploy, scale, and operate a Kotlin/Ktor API on Kubernetes with Helm and Azure Kubernetes Service (AKS).

## Prerequisites

- Talks 1-11 completed or understood
- `kubectl`
- Helm 3
- Azure CLI
- Docker (recommended for building and pushing the demo image)
- Access to an Azure subscription with permission to create AKS and ACR resources

## What is in this talk?

This talk includes:

- A Ktor REST API with health and item endpoints
- Raw Kubernetes manifests in `k8s/`
- A Helm chart in `helm/container-series-app/`
- AKS infrastructure as code in `infra/main.bicep`
- A deployment script in `scripts/deploy.sh`

## Talk outline (~60 mins)

1. **Kubernetes concepts**: Pods, Deployments, Services, Namespaces, ConfigMaps, Secrets, Ingress
2. **AKS**: create cluster, integrate with ACR, node pools
3. **kubectl**: `apply`, `get`, `describe`, `logs`, `exec`
4. **Liveness and readiness probes**
5. **Resource requests and limits**
6. **HPA**: horizontal pod autoscaler
7. **Init containers and sidecar containers**
8. **Helm**: charts, releases, repositories
9. **Creating a Helm chart from scratch**
10. **`values.yaml` parametrisation**
11. **`helm install`, `upgrade`, `rollback`**
12. **Ingress with NGINX and TLS/cert-manager**
13. **Bicep for AKS**

## Project structure

```text
.
├── build.gradle.kts
├── Dockerfile
├── helm/
│   └── container-series-app/
├── infra/
│   ├── main.bicep
│   └── parameters.json
├── k8s/
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── namespace.yaml
│   ├── secret.yaml
│   └── service.yaml
├── scripts/
│   └── deploy.sh
└── src/
    └── main/kotlin/com/example/
```

## Running the Ktor API locally

```bash
gradle run
```

Environment variables used by the app:

- `PORT` (default `8080`)
- `APP_VERSION` (default `unknown` on `/health`)
- `LOG_LEVEL` (default `INFO`)

API endpoints:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/items
curl -X POST http://localhost:8080/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Thing","description":"Created locally"}'
```

## Build the container image

```bash
docker build -t myacr.azurecr.io/talk-12:latest .
```

## Kubernetes concepts covered

### Pods
Pods are the smallest deployable unit in Kubernetes. In this talk, the application pod contains:

- The main Ktor container
- An init container
- A sidecar container

### Deployment
The Deployment in `k8s/deployment.yaml` manages 3 replicas, rolling updates, probes, and resource limits.

### Service
The Service exposes the Deployment internally inside the cluster using `ClusterIP`.

### Namespace
All demo resources are placed in the `container-series` namespace.

### ConfigMaps and Secrets
- ConfigMap: non-sensitive runtime configuration such as `APP_VERSION`, `LOG_LEVEL`, and `ENVIRONMENT`
- Secret: placeholder sensitive values encoded in base64

### Ingress
Ingress routes external HTTP(S) traffic to the application and demonstrates TLS with cert-manager.

## AKS walkthrough

### Create the resource group

```bash
az group create --name rg-container-series --location uksouth
```

### Create Azure Container Registry (ACR)

```bash
az acr create \
  --resource-group rg-container-series \
  --name myacr \
  --sku Basic
```

### Create an AKS cluster and attach ACR

```bash
az aks create \
  --resource-group rg-container-series \
  --name aks-container-series \
  --node-count 2 \
  --generate-ssh-keys \
  --attach-acr myacr
```

### Retrieve cluster credentials

```bash
az aks get-credentials \
  --resource-group rg-container-series \
  --name aks-container-series
```

### Add a user node pool (optional demo)

```bash
az aks nodepool add \
  --resource-group rg-container-series \
  --cluster-name aks-container-series \
  --name userpool \
  --mode User \
  --node-count 1 \
  --node-vm-size Standard_B2s
```

## kubectl commands used in the talk

### Apply manifests

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
```

### Inspect resources

```bash
kubectl get namespaces
kubectl get all -n container-series
kubectl get deployments -n container-series
kubectl get pods -n container-series
kubectl get services -n container-series
kubectl get ingress -n container-series
kubectl get configmaps -n container-series
kubectl get secrets -n container-series
kubectl get hpa -n container-series
```

### Describe resources

```bash
kubectl describe deployment talk-12-api -n container-series
kubectl describe pod <pod-name> -n container-series
kubectl describe ingress talk-12-api -n container-series
```

### View logs

```bash
kubectl logs deployment/talk-12-api -n container-series
kubectl logs deployment/talk-12-api -n container-series -c talk-12-api
kubectl logs deployment/talk-12-api -n container-series -c log-forwarder
```

### Exec into a container

```bash
kubectl exec -it deployment/talk-12-api -n container-series -c talk-12-api -- sh
```

### Rollout operations

```bash
kubectl rollout status deployment/talk-12-api -n container-series
kubectl rollout restart deployment/talk-12-api -n container-series
kubectl scale deployment talk-12-api --replicas=5 -n container-series
```

### Troubleshooting helpers

```bash
kubectl top pods -n container-series
kubectl port-forward svc/talk-12-api 8080:8080 -n container-series
```

## Probes and resources

The deployment demonstrates:

- **Liveness probe** on `/health`
- **Readiness probe** on `/ready`
- **CPU/memory requests** to reserve capacity
- **CPU/memory limits** to prevent noisy-neighbour problems

## Horizontal Pod Autoscaler

Apply the HPA after metrics-server is available:

```bash
kubectl apply -f k8s/hpa.yaml
kubectl get hpa -n container-series
```

## Init and sidecar containers

The Deployment demonstrates two common pod design patterns:

- **Init container**: prepares the runtime environment before the app starts
- **Sidecar container**: tails a shared log file for forwarding/inspection

## Helm concepts

### Chart, release, and repository

- **Chart**: a packaged application definition
- **Release**: a deployed instance of a chart
- **Repository**: a collection of charts

### Useful Helm commands

```bash
helm create container-series-app
helm lint ./helm/container-series-app
helm template container-series-app ./helm/container-series-app
helm install container-series-app ./helm/container-series-app \
  --namespace container-series --create-namespace
helm upgrade container-series-app ./helm/container-series-app \
  --namespace container-series --set image.tag=1.0.1
helm rollback container-series-app 1 --namespace container-series
helm history container-series-app --namespace container-series
helm uninstall container-series-app --namespace container-series
```

### Helm repositories

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm search repo ingress-nginx
```

### Install NGINX ingress controller

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

### Install cert-manager

```bash
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set crds.enabled=true
```

## Create and deploy the Helm chart from this talk

### Render templates locally

```bash
helm template container-series-app ./helm/container-series-app
```

### Install the chart

```bash
helm upgrade --install container-series-app ./helm/container-series-app \
  --namespace container-series --create-namespace \
  --set image.repository=myacr.azurecr.io/talk-12 \
  --set image.tag=latest
```

### Upgrade the chart

```bash
helm upgrade container-series-app ./helm/container-series-app \
  --namespace container-series \
  --set image.tag=v2
```

### Roll back the chart

```bash
helm rollback container-series-app 1 --namespace container-series
```

## values.yaml parametrisation

The chart exposes common settings through `values.yaml`:

- replica count
- image repository and tag
- service port configuration
- ingress enablement, hostnames, and TLS
- CPU and memory resources
- autoscaling thresholds
- runtime config values

Override examples:

```bash
helm upgrade --install container-series-app ./helm/container-series-app \
  --namespace container-series --create-namespace \
  --set replicaCount=4 \
  --set config.environment=staging \
  --set image.tag=2025.04.01
```

## Ingress with NGINX and TLS

The sample ingress includes:

- `ingressClassName: nginx`
- `cert-manager.io/cluster-issuer: letsencrypt-prod`
- TLS secret `talk-12-tls`
- host `talk-12.example.com`

After deployment:

```bash
kubectl get ingress -n container-series
kubectl describe ingress talk-12-api -n container-series
```

## Bicep for AKS

Deploy the infrastructure template:

```bash
az deployment group create \
  --resource-group rg-container-series \
  --template-file infra/main.bicep \
  --parameters @infra/parameters.json
```

The Bicep template provisions:

- Log Analytics workspace
- User-assigned managed identity
- AKS cluster with a system node pool
- Monitoring addon
- AcrPull role assignment for ACR integration

## End-to-end deployment script

Run the full deployment flow:

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

The script will:

1. Create a resource group
2. Create an ACR instance
3. Create an AKS cluster with ACR attached
4. Fetch cluster credentials
5. Build and push the Docker image
6. Apply Kubernetes manifests
7. Install/upgrade the Helm release
8. List pods
9. Run Helm tests

## Bonus topics

### Helm testing

```bash
helm test container-series-app --namespace container-series
```

### Kustomize comparison

Kustomize is strong for patch-based environment overlays, while Helm is stronger when you need reusable packaging, templating, and release lifecycle commands.

### Helmfile

Helmfile becomes useful when you need to coordinate multiple Helm releases across environments and teams with a single declarative entry point.

## Key takeaways

- Kubernetes objects map cleanly to application runtime concerns
- AKS reduces operational overhead while integrating well with Azure services such as ACR and Log Analytics
- Probes, limits, and autoscaling are foundational for production workloads
- Helm is the standard way to package and parameterise Kubernetes applications
- Bicep makes AKS infrastructure repeatable and reviewable
- A small Ktor API is enough to demonstrate real-world deployment patterns such as ingress, config injection, init containers, and sidecars
