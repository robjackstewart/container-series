# Speaker Guide — Talk 15: Observability and Debugging

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with a service that already runs in containers, then make its behaviour visible through traces, metrics, and logs. Route that telemetry through an OpenTelemetry Collector into Jaeger, Prometheus, Loki, and Grafana, then switch from observing the system to debugging it while it is still running. The big idea is that production support improves when instrumentation and debugging are designed into the container workflow instead of improvised during an incident.

## Section-by-section narrative
### 1) Observability is more than monitoring
- Open by separating monitoring from observability. Monitoring answers whether known checks are healthy; observability helps you ask new questions when the failure mode is not yet understood.
- Frame the three signals: logs describe discrete events, metrics describe aggregate behaviour over time, and traces describe the path and timing of a request through the system.
- The Phoenix API is intentionally small so the audience can see the signal flow rather than getting lost in business logic.

> Expert aside: The useful correlation key across the three signals is usually the trace id. Metrics show that latency changed, traces identify the slow request path, and logs explain what the code did at the same point in time when that trace context is propagated into log records.

### 2) Instrumenting the Phoenix application
- Point out the app-level instrumentation before opening the dashboards: Phoenix and Cowboy are wired into OpenTelemetry, controller actions create named spans, and the structured logger emits JSON to standard output.
- The `/metrics` endpoint exposes Prometheus-format counters and histograms for HTTP request count, errors, and duration. This keeps the metrics story concrete: the chart is not magic; it is a scrape of this text endpoint.
- Emphasise the stdout/stderr logging contract. The app does not know about Loki directly; Docker routes container logs to Fluent Bit, which then ships them to Loki.

### 3) The OpenTelemetry Collector as the telemetry boundary
- The Collector receives OTLP from the application and exports traces to Jaeger and metrics for Prometheus scraping. This is the same pattern teams use in production, even when the backend is commercial rather than local.
- Explain processors briefly: batching smooths export overhead and the memory limiter protects the collector from becoming the next incident.
- Use the collector configuration as the architectural map: receivers define what comes in, processors define what happens in the middle, and exporters define where telemetry leaves.

> Expert aside: The Collector decouples application code from observability vendors. Changing the backend should usually be a collector configuration change, not a redeploy of every service that emits telemetry.

### 4) Jaeger, Prometheus, Loki, and Grafana
- Jaeger is the trace store and trace explorer. Search for the Phoenix service, open a trace, and use spans to talk about request flow, timings, and attributes.
- Prometheus is the metrics engine. It scrapes the app and collector, stores time series, and lets you ask questions such as request rate, error count, and latency percentiles.
- Loki stores logs with labels rather than indexing every field. That keeps the mental model close to Prometheus while still giving operators fast log search.
- Grafana is the shared console. It is not the source of truth for every signal; it is the place where the signals meet during triage.

### 5) Debugging live containers
- Start with the basic tools: logs for recent behaviour, stats for resource pressure, inspect for runtime metadata, diff for filesystem drift, and exec when the image actually contains a useful shell.
- Then introduce `docker debug` as the modern answer for slim or distroless images. The point is not to rebuild production images with shells; the point is to attach a separate toolbox when you need one.
- Keep the tone pragmatic: debugging commands are powerful and should be audited, but they are sometimes the fastest safe path to understanding a live failure.

### 6) Kubernetes ephemeral debug containers
- `kubectl debug` adds a temporary helper container to an existing pod. This is the Kubernetes equivalent of attaching a toolbox without changing the application image.
- The teaching contrast matters: `kubectl exec` needs a shell inside the target container, while an ephemeral container can bring its own tools.
- Mention realistic uses: network checks from the pod namespace, DNS investigation, reading mounted files, and comparing environment assumptions without mutating the workload image.

> Expert aside: Ephemeral debug containers share selected namespaces with the pod, commonly the network namespace and, when targeted, the process namespace. They do not magically change the original container image; they give you a sidecar-style troubleshooting view of the same runtime environment.

### 7) Debugging minimal images and post-mortem workflows
- Minimal images are an operational trade-off. They reduce attack surface and CVE noise, but the team needs a deliberate debugging plan before the incident.
- For stopped or unhealthy containers, discuss post-mortem patterns such as preserving filesystem state, comparing runtime drift, and extracting artefacts for offline analysis.
- CRIU checkpoint/restore is the niche bonus: it can freeze a container's process state and restore it later on compatible systems, which is fascinating for forensics, migration, and research even if it is not a mainstream daily workflow.

> Expert aside: CRIU works at the process-state level, not at the image-build level. It captures running state such as memory, open files, and process metadata, so compatibility between kernel, runtime, and workload matters much more than it does for a normal image rebuild.

## Discussion prompts (engage the room)
- Which signal do you usually reach for first during an incident, and what does it fail to tell you?
- Where should trace ids be added in your services so logs, traces, and metrics can be correlated quickly?
- Would your production policy allow `docker debug` or ephemeral containers, and what audit trail would you require?
- When would you accept a larger debug-friendly runtime image instead of a slim or distroless image?

## Key takeaways (the close)
- OpenTelemetry gives you vendor-neutral instrumentation, but the Collector is what makes that instrumentation operationally flexible.
- Logs, metrics, and traces answer different questions; incident response improves when they can be correlated.
- Containers should log to stdout/stderr and let the platform route those logs to central storage.
- `docker debug` and `kubectl debug` let you keep production images small without giving up live troubleshooting.
- Minimal images, distroless images, and CRIU-style workflows are most useful when the team has agreed the debugging pattern before the outage.

## Bonus / niche corner
Use the bonus to stretch the audience beyond day-to-day commands. Distroless and slim images deliberately remove shells and package managers, so a separate toolbox is safer than shipping debug tools in production. CRIU checkpoint/restore is worth showing conceptually because it changes the unit of recovery from filesystem contents to process state, but caveat it heavily: host support, runtime support, kernel compatibility, and workload behaviour all decide whether it is practical.

## Netskope / corporate proxy note
This talk builds the Phoenix application from a Dockerfile. Optional corporate CA certificates are copied from `certs/` through the `EXTRA_CERTS_DIR` build argument before dependency restore runs, so package downloads can work behind Netskope or another TLS-intercepting proxy. The files must be PEM-encoded `.crt` files; if the proxy exports `.pem`, rename it to `.crt` after confirming it is PEM text.

The runtime image is Alpine-based and shell-capable, and the demo communicates with the local observability stack over HTTP. If the released application later makes outbound TLS calls, add the runtime CA trust step deliberately rather than assuming the build-stage trust store is enough.
