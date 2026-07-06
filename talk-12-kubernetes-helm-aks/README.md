# Talk 12 — Kubernetes, Helm & AKS

Deploy a Kotlin/Ktor API to Kubernetes first as raw manifests, then as a reusable Helm chart, with optional Azure Kubernetes Service infrastructure. Language: Kotlin / Ktor.

## What you'll learn
- How Pods, Deployments, Services, Ingress, probes, and HPA fit together for a real API.
- How Helm templates, values, releases, tests, upgrades, and rollbacks package Kubernetes workloads.
- How AKS, ACR, and Bicep turn the same deployment model into repeatable cloud infrastructure.

## Prerequisites
- Docker Desktop installed and running.
- `kubectl` installed and pointed at a cluster.
- Helm 3 installed.
- Azure CLI and an Azure subscription for the optional AKS/ACR path.
- Optional: metrics-server, NGINX ingress, and cert-manager in the target cluster.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`src/`** — the Kotlin/Ktor API.
- **`k8s/`** — raw Namespace, ConfigMap, Secret, Deployment, Service, Ingress, and HPA manifests.
- **`helm/container-series-app/`** — the Helm chart for the same workload.
- **`infra/`** — Bicep for AKS, ACR, monitoring, and registry pull access.
- **`scripts/`** — optional end-to-end AKS deployment helper.
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
helm upgrade --install container-series-app ./helm/container-series-app --namespace container-series --create-namespace --set image.repository=myacr.azurecr.io/talk-12 --set image.tag=1.0.0
```

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`certs/netskope.crt`**. Build with `--secret id=netskope_cert,src=certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Omit `--secret` when not behind a proxy. See the repo root README for the full explanation.

## Next in the series
Talk 13 moves from Kubernetes orchestration into WebAssembly containers and Spin/Wasm packaging.
