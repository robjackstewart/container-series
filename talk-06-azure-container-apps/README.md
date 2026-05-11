# Azure Container Apps — Services & Jobs

This talk introduces Azure Container Apps (ACA) as a managed container platform for long-running services and event/schedule-driven jobs. The examples use Java 21 and Spring Boot 3.2, with one HTTP service and one background job that map cleanly to ACA's core deployment models. The Bicep deployment also provisions a simple in-memory Dapr state store component for demo purposes.

## Prerequisites

- Completed or reviewed Talks 1-5 in this series
- Azure subscription with permission to create resource groups, Container Apps, ACR, Log Analytics, and managed identities
- Azure CLI installed
- Azure CLI `containerapp` extension installed (or let the deployment script install it)
- Bash-compatible shell for running `scripts/deploy.sh` (for example Git Bash, WSL, or Linux/macOS shell)
- Optional: Docker for local image builds (the provided script uses `az acr build` instead)
- Optional: Dapr familiarity for service invocation, pub/sub, and state management demos

## Talk goals

By the end of the session, you should be able to:

- Explain where Azure Container Apps fits between App Service and AKS
- Deploy HTTP services with ingress, revisions, traffic splitting, and scale-to-zero
- Deploy scheduled or event-driven jobs
- Add Dapr, managed identity, and secrets to containerized workloads
- Read logs and reason about scaling behavior in a managed environment

## 60-minute outline

1. **ACA overview vs App Service vs AKS** (10 min)
2. **Container Apps Environment: shared boundary, VNet** (5 min)
3. **Services: ingress, revisions, traffic splitting** (8 min)
4. **KEDA scaling rules: HTTP, Azure Queue, cron** (7 min)
5. **Scale to zero** (3 min)
6. **Container Apps jobs: manual, scheduled, event-driven** (7 min)
7. **Dapr integration: service invocation, state management, pub/sub** (7 min)
8. **Managed identity** (4 min)
9. **Secrets in ACA** (4 min)
10. **Observability: Log Analytics** (5 min)

## ACA vs App Service vs AKS

| Capability | Azure Container Apps | Azure App Service | Azure Kubernetes Service |
| --- | --- | --- | --- |
| Primary abstraction | Containerized apps and jobs | Managed web apps / APIs | Full Kubernetes cluster |
| Operational complexity | Low | Low | High |
| Kubernetes access | Hidden/managed for you | Not exposed | Full control |
| Scale to zero | Yes | Limited / workload-specific | Possible, but you design it |
| Event-driven scaling | Built-in via KEDA | Limited | Possible with KEDA / custom setup |
| Revisions & traffic split | Built-in | Deployment slots | Manual / service mesh / ingress tooling |
| Best fit | Microservices, APIs, workers, jobs | Traditional web apps, APIs | Platform teams needing cluster control |
| Trade-off | Less control than AKS | Less container-native flexibility | More power, more responsibility |

### Simple positioning

- **Choose App Service** when you want the easiest path for classic web apps and APIs.
- **Choose ACA** when you want container packaging, autoscaling, jobs, Dapr, and minimal platform management.
- **Choose AKS** when you need Kubernetes APIs, custom controllers, advanced networking, or multi-cluster platform patterns.

## Container Apps Environment

A **Container Apps Environment** is the shared boundary for one or more container apps and jobs.

It provides:

- Shared networking boundary
- Shared observability integration
- Internal service discovery between apps in the same environment
- Optional VNet integration for private connectivity and enterprise network controls

Think of it as the logical runtime home for a related set of services and jobs.

## Services in ACA

The `service/` example in this talk is an `order-service` Spring Boot API.

Key ACA service concepts:

- **Ingress** exposes an app externally or internally
- **Revisions** create immutable deployment versions
- **Traffic splitting** lets you route traffic across revisions for blue/green or canary rollout
- **Scale rules** define how replicas increase or decrease
- **Scale to zero** reduces cost for idle workloads

### Revisions and deployment strategies

- **Blue/green**: create a new revision, send 0% traffic initially, then switch traffic to the new revision
- **Canary**: split traffic across revisions, for example 90% old / 10% new
- **Rollback**: route traffic back to the known-good revision

## KEDA scaling rules

ACA uses **KEDA** under the hood for autoscaling.

### HTTP scaling

- Trigger based on concurrent HTTP requests
- Great for APIs and web front ends
- This talk's service scales up to 10 replicas when concurrency increases

### Azure Queue scaling

- Trigger based on queue depth
- Ideal for worker-style services or jobs reacting to messages

### Cron scaling

- Time-based behavior for predictable workloads
- Common for batch windows, reporting, cleanup, or data sync workflows

## Scale to zero

One of ACA's most compelling features is the ability to run with `minReplicas: 0`.

Benefits:

- Pay less for idle workloads
- Fit bursty APIs and internal tools well
- Use on-demand execution patterns without maintaining always-on compute

Trade-offs:

- Cold start latency
- Be thoughtful about readiness, startup time, and JVM warm-up

## Container Apps jobs

ACA jobs are designed for work that should **start, run, and exit**.

Job modes:

- **Manual**: triggered on demand
- **Scheduled**: triggered by cron expression
- **Event-driven**: triggered by external events such as queue depth

The `job/` example in this talk is an `order-processor` that simulates processing pending orders and can optionally read from Azure Storage Queue.

## Dapr integration

ACA has first-class Dapr integration.

Useful building blocks:

- **Service invocation**: call services by app ID instead of hostnames
- **State management**: read/write state through Dapr components
- **Pub/sub**: publish or subscribe to events without binding directly to broker SDKs

This talk's service includes optional Dapr state store writes when `DAPR_ENABLED=true`. The included Bicep template wires a demo-friendly in-memory component named `statestore` by default.

## Managed identity

Use managed identity instead of embedding credentials.

Common ACA use cases:

- Pull images from Azure Container Registry with identity-based access
- Access Azure Storage, Key Vault, Service Bus, or other Azure resources
- Remove password rotation burden from application configuration

## Secrets in ACA

ACA secrets can be referenced by containers without hard-coding values in images.

Typical secret use cases:

- API keys
- Connection strings
- Dapr component credentials
- Application-specific tokens

Best practice:

- Prefer **managed identity** where possible
- Use **secrets** only when identity is not supported or when third-party credentials are required

## Observability with Log Analytics

ACA integrates with Log Analytics for:

- Console logs
- Revision and replica diagnostics
- Troubleshooting startup and scaling behavior
- Monitoring job execution history

Demo ideas:

- Show logs for the service after a health request
- Show logs for the job after a manual trigger
- Correlate a new revision rollout with logs and traffic changes

## Repository structure

```text
service/  -> Spring Boot HTTP API
job/      -> Spring Boot batch-style processor
infra/    -> Bicep + parameters
scripts/  -> Deployment automation
```

## Core Azure CLI workflow

### Install and verify ACA tooling

```bash
az extension add --name containerapp --upgrade --yes
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.ContainerRegistry
az extension show --name containerapp
```

### Resource group and ACR

```bash
az group create --name rg-container-series-talk06 --location eastus
az acr create --name mytalk06acr --resource-group rg-container-series-talk06 --sku Basic --admin-enabled false
az acr show --name mytalk06acr --resource-group rg-container-series-talk06 --query loginServer -o tsv
```

### Build and push images with ACR Tasks

```bash
az acr build --registry mytalk06acr --image order-service:v1 ./service
az acr build --registry mytalk06acr --image order-processor:v1 ./job
```

### Deploy the environment and workloads with Bicep

```bash
az deployment group create \
  --resource-group rg-container-series-talk06 \
  --template-file ./infra/main.bicep \
  --parameters @./infra/parameters.json \
  --parameters acrName=mytalk06acr \
               containerRegistryServer=mytalk06acr.azurecr.io \
               serviceImage=mytalk06acr.azurecr.io/order-service:v1 \
               jobImage=mytalk06acr.azurecr.io/order-processor:v1
```

### Create a Container Apps environment directly with CLI (alternative to Bicep)

```bash
az monitor log-analytics workspace create \
  --resource-group rg-container-series-talk06 \
  --workspace-name log-talk06

WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-container-series-talk06 \
  --workspace-name log-talk06 \
  --query customerId -o tsv)

WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group rg-container-series-talk06 \
  --workspace-name log-talk06 \
  --query primarySharedKey -o tsv)

az containerapp env create \
  --name aca-talk06-env \
  --resource-group rg-container-series-talk06 \
  --location eastus \
  --logs-workspace-id "$WORKSPACE_ID" \
  --logs-workspace-key "$WORKSPACE_KEY"
```

### Create the service with external ingress and scale-to-zero

```bash
az containerapp create \
  --name order-service \
  --resource-group rg-container-series-talk06 \
  --environment aca-talk06-env \
  --image mytalk06acr.azurecr.io/order-service:v1 \
  --target-port 8080 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 10 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --registry-server mytalk06acr.azurecr.io
```

### Configure an HTTP scale rule

```bash
az containerapp update \
  --name order-service \
  --resource-group rg-container-series-talk06 \
  --scale-rule-name http-concurrency \
  --scale-rule-type http \
  --scale-rule-metadata concurrentRequests=100
```

### Enable managed identity and registry access

```bash
az containerapp identity assign \
  --name order-service \
  --resource-group rg-container-series-talk06 \
  --system-assigned

PRINCIPAL_ID=$(az containerapp show \
  --name order-service \
  --resource-group rg-container-series-talk06 \
  --query identity.principalId -o tsv)

ACR_ID=$(az acr show \
  --name mytalk06acr \
  --resource-group rg-container-series-talk06 \
  --query id -o tsv)

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "$ACR_ID"
```

### Set secrets and environment variables

```bash
az containerapp secret set \
  --name order-service \
  --resource-group rg-container-series-talk06 \
  --secrets app-secret="super-secret-value"

az containerapp update \
  --name order-service \
  --resource-group rg-container-series-talk06 \
  --set-env-vars DAPR_ENABLED=true APP_SECRET=secretref:app-secret
```

### Revisions, labels, and traffic splitting

```bash
az containerapp revision list --name order-service --resource-group rg-container-series-talk06 -o table
az containerapp revision copy --name order-service --resource-group rg-container-series-talk06
az containerapp revision set-mode --name order-service --resource-group rg-container-series-talk06 --mode multiple
az containerapp ingress traffic set \
  --name order-service \
  --resource-group rg-container-series-talk06 \
  --revision-weight order-service--rev1=90 order-service--rev2=10
az containerapp revision activate --name order-service --resource-group rg-container-series-talk06 --revision order-service--rev2
az containerapp revision deactivate --name order-service --resource-group rg-container-series-talk06 --revision order-service--rev1
```

### Logs and troubleshooting

```bash
az containerapp logs show --name order-service --resource-group rg-container-series-talk06 --follow
az containerapp exec --name order-service --resource-group rg-container-series-talk06 --command sh
az containerapp show --name order-service --resource-group rg-container-series-talk06 -o yaml
az containerapp replica list --name order-service --resource-group rg-container-series-talk06 -o table
```

### Create and run a job

```bash
az containerapp job create \
  --name order-processor \
  --resource-group rg-container-series-talk06 \
  --environment aca-talk06-env \
  --trigger-type Schedule \
  --cron-expression "0 */6 * * *" \
  --image mytalk06acr.azurecr.io/order-processor:v1 \
  --registry-server mytalk06acr.azurecr.io \
  --cpu 0.5 \
  --memory 1.0Gi \
  --replica-timeout 300

az containerapp job start --name order-processor --resource-group rg-container-series-talk06
az containerapp job show --name order-processor --resource-group rg-container-series-talk06 -o yaml
az containerapp job execution list --name order-processor --resource-group rg-container-series-talk06 -o table
```

### Event-driven job pattern (example)

```bash
az containerapp job create \
  --name queue-order-processor \
  --resource-group rg-container-series-talk06 \
  --environment aca-talk06-env \
  --trigger-type Event \
  --scale-rule-name queue-orders \
  --scale-rule-type azure-queue \
  --scale-rule-metadata queueName=pending-orders queueLength=5 accountName=mystorageaccount
```

## Demo flow suggestion

1. Deploy the environment, service, and scheduled job.
2. Call `GET /health` to show the app is reachable.
3. Create a few sample orders with `POST /orders`.
4. Discuss how scale-to-zero affects cost and cold starts.
5. Show revision history and explain traffic splitting.
6. Trigger the job manually.
7. Review logs in Log Analytics or via CLI.
8. Explain how Dapr state writes would work with a configured `statestore` component.

## Example API usage

### Health

```bash
curl https://<service-fqdn>/health
```

### Create an order

```bash
curl -X POST https://<service-fqdn>/orders \
  -H "Content-Type: application/json" \
  -d '{
        "customerId": "cust-1001",
        "product": "Azure Container Apps Workshop",
        "quantity": 2
      }'
```

### Update order status

```bash
curl -X PUT https://<service-fqdn>/orders/<order-id>/status \
  -H "Content-Type: application/json" \
  -d '{"status":"COMPLETED"}'
```

## Key takeaways

- Azure Container Apps gives you container-native deployment without cluster management.
- Services and jobs cover the majority of API + background processing scenarios.
- KEDA-based scaling, including scale-to-zero, is one of ACA's strongest differentiators.
- Revisions and traffic splitting enable safe deployment strategies without Kubernetes complexity.
- Dapr, managed identity, secrets, and Log Analytics round out a production-ready platform story.

## Bonus topics

- **KEDA custom scalers** for advanced event sources or custom trigger logic
- **ACA session pools** for specialized scenarios that need fast warm capacity or pooled sessions

## Next step

Use `scripts/deploy.sh` to deploy the sample service and job, then extend the examples with a real Dapr state store and an Azure Queue-backed processing workflow.
