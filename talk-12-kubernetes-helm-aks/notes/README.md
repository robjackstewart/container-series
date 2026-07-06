# Speaker Guide — Talk 12: Kubernetes, Helm & AKS

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with a small Ktor API and show that Kubernetes is a set of explicit runtime contracts: what runs, how it is reached, how it proves health, and how it scales. Then replace hand-written repetition with a Helm chart so the same workload becomes parameterised, upgradeable, testable, and rollback-friendly. The close is AKS and Bicep: the application model stays portable, while Azure supplies the managed control plane, registry integration, identity, and monitoring.

## Section-by-section narrative

### 1) The API as the workload
- Keep the application intentionally simple: health, readiness, and item endpoints are enough to make Kubernetes behaviour visible without turning the talk into a Kotlin session.
- Point out the runtime inputs: `PORT`, `APP_VERSION`, and `LOG_LEVEL`. These become Kubernetes configuration rather than image rebuilds.
- The image runs as a non-root user, so the platform story starts before Kubernetes: the container should already have sensible defaults.

### 2) Pods, init containers, and sidecars
- A Pod is the scheduling boundary. The application container, init container, sidecar, and shared volumes move together and share a network identity.
- The init container prepares the shared log directory before the app starts. This is a good place to explain that init containers run to completion, in order, and gate the app containers.
- The sidecar demonstrates the pattern without adding a real log system: it tails the same shared file so the audience can see how helper containers extend a Pod.
> Expert aside: Deployment ownership is layered. A Deployment owns ReplicaSets, ReplicaSets own Pods, and Pods own their containers. When you roll out a new image, Kubernetes creates a new ReplicaSet rather than mutating old Pods in place.

### 3) Deployments and rollout safety
- The Deployment asks for multiple replicas, declares the selector, and defines the Pod template. Changing that template creates rollout activity.
- Liveness probes answer “should this container be restarted?” while readiness probes answer “should this Pod receive traffic?” Mixing them up creates noisy restarts or traffic to cold instances.
- Resource requests reserve scheduling capacity; limits cap runtime consumption. The HPA later depends on CPU request data to interpret utilisation.

### 4) Services and Ingress
- The Service gives the Deployment a stable virtual endpoint even though Pods are disposable and have changing IP addresses.
- The example uses `ClusterIP` because Ingress is responsible for the external HTTP entry point.
- Ingress shows host-based routing, TLS intent, and the dependency on an ingress controller such as NGINX plus cert-manager for automated certificates.
> Expert aside: Service traffic is implemented by kube-proxy or an equivalent dataplane programming rules from Service and EndpointSlice objects. A `LoadBalancer` Service asks the cloud provider for an external load balancer, while `ClusterIP` stays inside the cluster.

### 5) Configuration, Secrets, and environment
- The ConfigMap carries non-sensitive runtime values such as version, environment, and log level.
- The Secret is deliberately placeholder material. Use it to discuss the difference between Kubernetes Secret encoding and a real secret-management strategy.
- Tie this back to container design: the image is immutable, while configuration is injected at deployment time.

### 6) Horizontal Pod Autoscaling
- The HPA watches resource metrics and adjusts the Deployment replica count between the declared minimum and maximum.
- It is not magic capacity. It reacts after metrics exist, and it still needs enough node capacity or cluster autoscaling to place new Pods.
- Make the scaling demo conversational: show the object, explain desired versus current metrics, then scale or generate load depending on the environment.
> Expert aside: CPU-based HPA requires metrics-server and meaningful CPU requests. Without metrics-server the HPA exists but reports unknown metrics; without requests the utilisation percentage is not meaningful.

### 7) Helm charts, templates, and values
- Helm turns a directory of templates plus `values.yaml` into concrete Kubernetes manifests.
- The chart demonstrates common knobs: replica count, image repository and tag, service port, ingress host and TLS, resource limits, autoscaling, and runtime config.
- Values let teams keep one chart shape while changing environment-specific details. Avoid presenting templating as string substitution only; the release lifecycle is the bigger win.

### 8) Helm releases, tests, upgrades, and rollbacks
- A Helm release is an installed instance of a chart in a namespace. It has history, status, and revision numbers.
- The chart includes a Helm test Pod that calls the health endpoint through the Service. That makes “deployed” slightly stronger than “the YAML applied”.
- Rollbacks are a release operation. They are fast because Helm stores prior rendered revisions, but they do not replace database or external-system migration planning.
> Expert aside: Helm rollback returns the Kubernetes objects to a previous rendered revision; it does not undo side effects outside Kubernetes, and it does not guarantee the old image still exists unless your registry retention policy keeps it.

### 9) AKS and Bicep infrastructure
- AKS gives the managed Kubernetes control plane, Azure identity integration, Azure networking, and managed node pools while preserving the Kubernetes APIs used earlier.
- ACR is the registry dependency for the image. The Bicep template grants AcrPull to the AKS kubelet identity so Pods can pull without registry passwords in manifests.
- Log Analytics and the monitoring add-on show the operational path: production clusters need visibility, not just schedulability.
- Bicep keeps the cluster, registry, monitoring, and role assignment reviewable and repeatable. It also makes environment drift easier to spot.

### 10) Bonus: Kustomize and Helmfile
- Kustomize is strongest when the base YAML is already the source of truth and environments are expressed as overlays and patches.
- Helm is stronger when you need a reusable package, typed release lifecycle, chart dependencies, tests, and rollback history.
- Helmfile becomes useful when a platform team coordinates many Helm releases across environments and wants one declarative entry point for ordering and values.

## Discussion prompts (engage the room)
- Which Kubernetes object would you inspect first if traffic reaches the cluster but not the Pod?
- What should be a Helm value, and what should stay fixed inside the chart template?
- When is a raw manifest clearer than a chart?
- What operational risk remains even if a Helm rollback succeeds?
- How would you separate application teams from platform teams around AKS, ingress, certificates, and monitoring?

## Key takeaways (the close)
- Kubernetes separates desired state into small, composable API objects.
- Pods are disposable; Deployments, Services, and Ingress provide the stable operational shape around them.
- Probes, resource requests, and HPA are production basics, not advanced extras.
- Helm adds packaging, parameterisation, release history, tests, upgrades, and rollbacks.
- AKS and Bicep make the same deployment model repeatable on Azure with managed infrastructure and registry integration.

## Bonus / niche corner
Use the Helm test to show that charts can carry operational checks, not just workload definitions. Use Kustomize as the honest comparison: overlays are often simpler for small environment-specific patches, while Helm is better when teams need a distributable package and release lifecycle. Mention Helmfile only as the orchestration layer for estates with many charts; it is not needed for one small service.

## Netskope / corporate proxy note
This talk has one Dockerfile. The Gradle build stage uses keytool to import an optional corporate CA certificate into the JDK `cacerts` keystore via a BuildKit secret (`--secret id=netskope_cert,src=certs/netskope.crt`) before Gradle resolves dependencies or builds the jar, then removes it — all in one RUN. The cert is never written to any image layer. Omit `--secret` when not behind a TLS-intercepting proxy.

The runtime image is an Alpine JRE with a shell, not distroless, and the demo API does not make outbound TLS calls at runtime. If the application later calls HTTPS services from inside the JVM, trust must also be available to the runtime JVM trust path; for shell-less or distroless JRE images, copy the refreshed CA bundle from the build stage into the final image and verify how that JRE reads system certificates.
