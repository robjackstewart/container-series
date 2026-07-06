# RUNSHEET — Talk 12: Kubernetes, Helm & AKS

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Copy your CA cert to `certs/netskope.crt` and add `--secret id=netskope_cert,src=certs/netskope.crt` to any `docker build` command below.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] Kubernetes context selected — `kubectl config current-context`
- [ ] Helm 3 installed — `helm version`
- [ ] Azure CLI logged in for the AKS path — `az account show`
- [ ] Optional cluster add-ons ready — metrics-server, NGINX ingress, and cert-manager
- [ ] (if behind Netskope) corporate `.crt` saved as `certs/netskope.crt`
- [ ] Warm the caches — `docker pull gradle:8.5-jdk21; docker pull eclipse-temurin:21-jre-alpine; docker pull busybox:1.36`
- [ ] Terminal in `talk-12-kubernetes-helm-aks`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Set the demo values
export RESOURCE_GROUP=container-series-rg
export LOCATION=uksouth
export CLUSTER_NAME=container-series-aks
export ACR_NAME=containerseriesacr
export ACR_SERVER="${ACR_NAME}.azurecr.io"
export NAMESPACE=container-series
export IMAGE_NAME=talk-12
export IMAGE_TAG=1.0.0
export HELM_RELEASE=container-series-app

# 2) Optional AKS/ACR infrastructure with Bicep
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
az deployment group create --resource-group "$RESOURCE_GROUP" --template-file infra/main.bicep --parameters @infra/parameters.json
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing

# 3) Build and push the Ktor image
az acr login --name "$ACR_NAME"
docker build --secret id=netskope_cert,src=certs/netskope.crt -t "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG" .
# Omit --secret if not behind Netskope.
docker push "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG"

# 4) Raw manifest path: apply and point the Deployment at this image
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/
kubectl set image deployment/talk-12-api talk-12-api="$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG" -n "$NAMESPACE"
kubectl rollout status deployment/talk-12-api -n "$NAMESPACE"

# 5) Inspect Pods, Service, Ingress, logs, and HPA
kubectl get pods -n "$NAMESPACE" -o wide
kubectl get service talk-12-api -n "$NAMESPACE"
kubectl get ingress talk-12-api -n "$NAMESPACE"
kubectl logs deployment/talk-12-api -n "$NAMESPACE" -c talk-12-api --tail=20
kubectl get hpa -n "$NAMESPACE"

# 6) Scale manually, then return control to HPA
kubectl scale deployment talk-12-api --replicas=5 -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE"
kubectl apply -f k8s/hpa.yaml
kubectl get hpa talk-12-api -n "$NAMESPACE"

# 7) Helm path: render, install or upgrade, inspect release history
helm lint ./helm/container-series-app
helm template "$HELM_RELEASE" ./helm/container-series-app --namespace "$NAMESPACE" --set image.repository="$ACR_SERVER/$IMAGE_NAME" --set image.tag="$IMAGE_TAG"
helm upgrade --install "$HELM_RELEASE" ./helm/container-series-app --namespace "$NAMESPACE" --create-namespace --set image.repository="$ACR_SERVER/$IMAGE_NAME" --set image.tag="$IMAGE_TAG" --set config.appVersion="$IMAGE_TAG" --wait
helm status "$HELM_RELEASE" -n "$NAMESPACE"
helm history "$HELM_RELEASE" -n "$NAMESPACE"

# 8) Bonus: Helm test, Kustomize contrast, and Helmfile mention
helm test "$HELM_RELEASE" -n "$NAMESPACE"
kubectl kustomize k8s 2>/dev/null || echo "No kustomization.yaml here: compare Kustomize overlays conceptually with Helm templating."
helmfile --version 2>/dev/null || echo "Helmfile is optional: mention it for coordinating multiple releases."
```

## Beat-by-beat talking points
1. The variables make the moving parts explicit: resource group, cluster, registry, namespace, image, and release.
2. The optional Bicep step proves infrastructure as code before application deployment; skip it if a cluster already exists.
3. Building and pushing shows that Kubernetes pulls immutable image artefacts from a registry, not from your laptop.
4. Raw manifests make the object model visible: Namespace, ConfigMap, Secret, Deployment, Service, Ingress, and HPA.
5. The inspection commands map directly to the teaching model: Pods run, Services route internally, Ingress exposes HTTP, HPA watches metrics.
6. Manual scaling is immediate and visible; HPA is policy-driven and depends on metrics-server plus resource requests.
7. Helm shows the same workload as a package with templating, values, release status, history, upgrades, and rollbacks.
8. The bonus section lands the distinction: Helm tests validate the release, Kustomize patches YAML, Helmfile coordinates many releases.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. Default `certs/` is empty = no-op.
- **Wrong cluster or namespace** → check `kubectl config current-context`, then rerun `az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing`.
- **Azure auth or subscription error** → run `az login`, then confirm `az account show` is the intended subscription before creating AKS resources.
- **Image pull fails** → confirm `ACR_SERVER`, image tag, and AKS AcrPull role assignment; rerun the Bicep deployment if the cluster was recreated.
- **HPA metrics stay unknown** → install or fix metrics-server and confirm the Deployment has CPU requests.
- **Ingress has no address** → confirm an ingress controller exists and that DNS for `talk-12.example.com` points at the controller address.
- **Helm install reuses existing objects** → either uninstall the old release or delete the raw manifest deployment before reinstalling the chart.

## Reset / cleanup
```bash
helm uninstall "$HELM_RELEASE" -n "$NAMESPACE" 2>/dev/null || true
kubectl delete -f k8s/ --ignore-not-found=true
docker rmi "$ACR_SERVER/$IMAGE_NAME:$IMAGE_TAG" 2>/dev/null || true

# Optional cloud cleanup
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
```
