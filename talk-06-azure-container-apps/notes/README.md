# Speaker Guide — Talk 06: Azure Container Apps

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start by positioning Azure Container Apps as the point where teams keep the container packaging model but stop owning Kubernetes control-plane operations. Then show the two core workload shapes: a long-running Spring Boot HTTP service and a run-to-completion Spring Boot job. The big idea is that ACA packages Kubernetes, KEDA, Dapr, Envoy-style ingress, identity, secrets, and observability into a developer-facing abstraction without pretending that platform trade-offs disappear.

## Section-by-section narrative
### 1) ACA positioning: App Service, ACA, and AKS
- Frame the choice as an operating-model decision, not a maturity ladder. App Service is still the simplest place for many web apps; AKS is right when teams need Kubernetes APIs and deep platform control; ACA is for container-native services and workers where the team wants managed scaling, revisions, jobs, and Dapr without cluster ownership.
- Point at `service/`, `job/`, `infra/`, and `scripts/` to show that the application shape stays familiar: Dockerfiles, a registry, infrastructure as code, and CLI operations.
- Emphasise that ACA environments are the shared boundary for networking, logs, Dapr components, and internal service discovery.

> Expert aside: ACA is not “Kubernetes lite” exposed to developers. It is a managed abstraction built on Kubernetes-era building blocks: KEDA for event-driven scaling, Dapr for sidecars and bindings, and managed ingress in front of revisions. You get the patterns without receiving direct cluster-admin responsibility.

### 2) Building the Spring Boot service and job images
- The service image is a multi-stage Java 21 build: Maven resolves dependencies and packages the jar, then a smaller JRE runtime runs as a non-root user.
- The job image uses the same pattern but deliberately has no exposed port because ACA jobs start, run, and exit.
- Use this to reinforce that ACA does not remove image hygiene concerns. Base images, cached dependency layers, non-root runtime users, and predictable build contexts still matter.
- The Dockerfiles trust optional corporate CA certificates from `certs/` before Maven dependency resolution, so dependency restore works behind TLS-intercepting proxies.

### 3) Deploying the ACA environment and service
- The Bicep file creates a Log Analytics workspace, Container Apps Environment, Dapr state component, HTTP service, scheduled job, system-assigned identities, and ACR pull role assignments.
- Explain ingress as a platform feature rather than an application feature: the Spring Boot app still listens on port 8080, while ACA decides whether the app is externally reachable and how traffic reaches active revisions.
- Show `/health` first because it lets the audience separate platform reachability from business behaviour.

### 4) Revisions and traffic splitting
- Revisions are immutable snapshots of a container app template. Changing a revision-scoped setting, such as an image or environment variable, creates a new revision instead of mutating the running one in place.
- Use the canary split to make blue/green concrete: one revision remains known-good while the new revision receives a small percentage of traffic.
- Make rollback feel boring. The platform-level traffic command is the rollback mechanism; the image does not need to be rebuilt and the application does not need deployment-slot logic.

> Expert aside: Revision traffic splitting is ACA’s deployment-safety primitive. It gives small teams a blue/green or canary workflow without asking them to operate an ingress controller, service mesh, or Kubernetes rollout controller directly.

### 5) KEDA scaling and scale-to-zero
- ACA scaling rules are KEDA rules expressed through the Container Apps model. HTTP concurrency is the easiest service demo, but the same idea extends to queues, Service Bus, Kafka, Prometheus metrics, cron schedules, and custom scalers.
- Scale-to-zero is compelling for internal tools, bursty APIs, and occasional workers because idle capacity can disappear.
- Be honest about the trade-off: a JVM service can cold start more slowly than a tiny native binary, so readiness, heap sizing, dependency initialisation, and first-request latency are part of the design conversation.

> Expert aside: KEDA is broader than CPU autoscaling. CPU tells you a replica is busy after work has arrived; event scalers can react to backlog, queue depth, lag, schedules, or external metrics before users feel the pressure.

### 6) Container Apps jobs
- Jobs are for work that should finish: nightly clean-up, report generation, queue draining, import/export, or operational maintenance.
- Scheduled jobs use cron; manual jobs are useful for operations and demos; event-driven jobs wake on external signals such as queue depth.
- The `job/` sample currently processes sample orders unless an Azure Storage connection string is present. Treat that as the seam where a real Azure Queue SDK implementation would go.
- Contrast jobs with always-on workers: a job has execution history, retry and timeout settings, and a run-to-completion mental model.

### 7) Dapr, identity, secrets, and observability
- Dapr is enabled for the service and the Bicep deployment includes a demo `statestore` component. The service writes order state through the Dapr sidecar when `DAPR_ENABLED` is true, which keeps the application code separate from a concrete state store SDK.
- Managed identity should be the default answer for Azure resource access. Use ACA secrets only when identity is not available or when third-party credentials are unavoidable.
- Log Analytics is the platform lens for startup, scale behaviour, revision rollout, and job execution history.

### 8) Bonus / niche corner
- Event-driven jobs are the natural extension from scheduled jobs: instead of running every six hours, a job can run when queue depth, lag, or another KEDA scaler says there is work.
- Session pools are worth mentioning for workloads that need fast warm capacity or isolated per-session execution, such as interactive agents or code execution patterns.
- Custom KEDA scalers let specialist teams scale on domain-specific signals when built-in scalers are not enough.

## Discussion prompts (engage the room)
- Which of your workloads are genuinely always-on, and which are bursty enough to benefit from scale-to-zero?
- Would your team rather own Kubernetes flexibility or a narrower managed abstraction with fewer operational responsibilities?
- What signal should scale a worker: CPU, queue depth, request concurrency, schedule, or a business metric?
- How would you decide whether to use Dapr, a direct Azure SDK, or a message broker abstraction?

## Key takeaways (the close)
- ACA is a managed container platform for services and jobs, not just a place to “run Docker”.
- Revisions and traffic splitting give a practical deployment-safety story without AKS-level operations.
- KEDA makes event-driven scaling and scale-to-zero first-class, but cold starts are an engineering trade-off.
- Dapr, managed identity, secrets, and Log Analytics round out the platform story, but they still need deliberate design.
- Container basics still matter: small images, non-root runtimes, clear build contexts, and trusted dependency restore are not optional.

## Bonus / niche corner
If time allows, describe how the scheduled job could become an event-driven order processor backed by Azure Storage Queue, Service Bus, or Kafka. The strongest teaching point is that the scaling signal should match the business backlog. For advanced audiences, mention that KEDA custom scalers can encode specialist signals, and ACA session pools can keep warm capacity for session-oriented or latency-sensitive workloads.

## Netskope / corporate proxy note
Both Dockerfiles use the shared `EXTRA_CERTS_DIR` pattern before Maven resolves dependencies. The default `certs/` folder is present but contains no real certificates, so normal builds behave the same. Behind Netskope or another TLS-intercepting proxy, export the corporate root as PEM, rename it with a `.crt` extension if necessary, and place it in `certs/` before building from the talk folder.

The Maven build runs on a Debian-based JDK image and updates the system CA bundle before dependency resolution. The runtime images are JRE images rather than shell-less distroless images, so no distroless bundle copy is needed. Java normally uses the JVM trust configuration derived from the image; if you later add outbound HTTPS calls that must trust a private CA, keep the system store updated or explicitly set `-Djavax.net.ssl.trustStore` to the intended trust store.
