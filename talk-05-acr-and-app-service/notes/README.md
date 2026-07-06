# Speaker Guide — Talk 05: ACR and App Service

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start where the previous talks leave off: we already know how to build an image, so now we need somewhere trustworthy to put it and somewhere managed to run it. Move from Azure Container Registry as an OCI registry, through server-side builds and managed identity, into App Service for Containers with staging slots and Bicep. The big idea is that a production container release is not just a push; it is registry governance, identity, repeatable infrastructure, and safe rollout.

## Section-by-section narrative
### 1) ACR as the Azure image control plane
- Position ACR as a private OCI registry for images and related artefacts, not merely a Docker Hub clone.
- Explain the tiers simply: Basic is suitable for small experiments, Standard is the main team default for throughput and storage, and Premium adds features such as geo-replication, private endpoints, advanced networking, and options needed by some premium scenarios.
- Use geo-replication as the example of why registry location matters: image pull latency and regional resilience become platform concerns once many services depend on the same registry.
> Expert aside: tags are mutable pointers; digests are immutable content addresses. Production release records should prefer digests when exact provenance matters, even if humans still discuss friendly tags such as `latest` or `candidate`.

### 2) Publishing images: local push versus ACR Tasks
- Show the normal local flow only as a mental model: build an image, tag it with the registry login server, and push it.
- Then favour ACR Tasks for the live demo because the build runs server-side in Azure. That avoids depending on the presenter's local Docker daemon and makes the build closer to a CI pattern.
- Cover the three useful ACR Task shapes: quick one-off builds, Git-triggered tasks, and scheduled or base-image-triggered rebuilds.
> Expert aside: ACR Tasks are useful even before a full CI system exists because they move registry authentication, build logs, and image creation into the same Azure control plane as the registry.

### 3) Authentication and pull identity
- Contrast the admin user, service principals, and managed identity.
- Be clear that the admin user is a shared long-lived credential and is disabled in this demo.
- Service principals are still useful for systems outside Azure, but they introduce secret or certificate lifecycle work.
- Managed identity is the preferred App Service pull pattern: the web app gets an Azure-managed identity and that identity receives `AcrPull` on the registry.
> Expert aside: managed identity changes the failure mode. Instead of hunting for an expired registry password in app settings, you check the resource identity, the role assignment scope, and Azure role-assignment propagation.

### 4) App Service for Containers
- Frame App Service as the managed web-hosting choice for HTTP containers when the team wants platform features without running Kubernetes.
- The container still needs to listen on the expected port; `WEBSITES_PORT` tells App Service where to route traffic inside the container.
- Use `/health` and `/info` to prove that the platform pulled the image, started the Rust process, and passed environment settings into it.
- Mention the trade-off: App Service is opinionated and convenient; teams needing sidecars, KEDA-style scale rules, or multi-container orchestration may move to Container Apps or AKS.

### 5) Deployment slots and safe release
- Introduce slots as parallel App Service environments attached to the same app.
- The staging slot can pull a candidate image, warm up, and pass smoke tests before production traffic moves.
- The swap is the release moment: configuration marked as slot-specific stays with the slot, while swappable settings and content move through the platform operation.
> Expert aside: a slot swap is not just a DNS flip. App Service applies warm-up behaviour before routing production traffic, so the presenter should validate the staging hostname before swapping and keep rollback in mind.

### 6) Bicep and repeatable infrastructure
- Walk through the template as the infrastructure version of the story: registry, Linux App Service plan, web app, managed identity, app settings, and `AcrPull` role assignment.
- Explain that Bicep keeps the identity and role assignment close to the app definition, which reduces the chance of deploying a web app that can never pull its image.
- Call out `what-if` as the safe rehearsal step before changing live resources.
> Expert aside: Bicep `what-if` is most valuable before demos because it catches accidental name, SKU, and location changes while there is still time to adjust the script instead of improvising in the Azure portal.

### 7) Repository operations and governance
- Show repository and tag listing as operational literacy: a registry is an inventory, not a black box.
- Retention of untagged manifests prevents slow, invisible storage growth after repeated rebuilds.
- Use the `candidate` tag to explain an image quarantine pattern: new images can land in ACR but remain away from production until scanning, approval, or policy checks complete.

## Discussion prompts (engage the room)
- Where does your current deployment pipeline store registry credentials, and who rotates them?
- Would your team rather build images locally in CI or use a registry-side build service? What would change operationally?
- Which release evidence matters most for this service: tag, digest, build logs, Bicep deployment output, or App Service logs?
- When is App Service for Containers enough, and when would you choose Container Apps or AKS instead?

## Key takeaways (the close)
- ACR is the Azure control point for container images, metadata, and registry-side build workflows.
- Managed identity plus `AcrPull` avoids shared registry passwords in App Service configuration.
- Bicep makes the registry, app, identity, and role assignment repeatable.
- Deployment slots let you warm and validate a candidate container before the production swap.
- Registry governance includes retention, tag discipline, optional streaming, and quarantine-style promotion controls.

## Bonus / niche corner
ACR Artifact Streaming is for large-image cold-start scenarios. It prepares an image so capable runtimes can fetch the essential parts first instead of waiting for every layer to be fully downloaded. Treat it as a Premium-registry optimisation, not a default setting for small APIs.

Image quarantine is the governance companion: publish the image, scan or approve it, then promote it by tag, digest, or deployment configuration only after it passes policy. The Rust API is intentionally small, so the value in this talk is the operating model rather than a dramatic performance improvement.

## Netskope / corporate proxy note
This talk uses a Dockerfile for image builds. The build stage trusts an optional corporate CA certificate via a BuildKit secret (`--secret id=netskope_cert,src=certs/netskope.crt`) before `apt` and Cargo perform network access. The cert is never written to any image layer — omit `--secret` when not behind a TLS-intercepting proxy.

The final image is Debian slim and the demo API does not make outbound TLS calls, so no runtime CA bundle copy is needed. If the Rust service later calls HTTPS dependencies at runtime, keep `ca-certificates` in the runtime image and confirm the platform trust path before shipping it.
