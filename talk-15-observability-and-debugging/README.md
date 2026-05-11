# Container Observability & Debugging

Talk 15 focuses on making containerised systems observable and debuggable in production. The demo stack uses an Elixir / Phoenix JSON API, OpenTelemetry, Prometheus, Fluent Bit, Loki, Jaeger, and Grafana.

## Prerequisites

- Talks 1-14 in this series
- Docker Compose v2
- `curl` for generating traffic
- `jq` for a few inspection examples (optional)
- `kubectl` for the Kubernetes debugging examples (optional)

## Talk Outline (~60 mins)

1. **Three pillars of observability: logs, metrics, traces**  
   Logs explain what happened, metrics show trends, and traces reveal request flow.
2. **Container logging: stdout/stderr convention, Docker logging drivers**  
   Use stdout/stderr as the contract and let the platform route logs with drivers like `json-file`, `syslog`, and `fluentd`.
3. **Structured JSON logging for machine parsing**  
   Emit JSON logs so tools can search by status code, request id, path, duration, and custom fields.
4. **Log aggregation: Fluent Bit -> Loki**  
   Forward container logs into Loki for centralised search and correlation.
5. **OpenTelemetry: SDK, traces, metrics, OTel Collector**  
   Instrument the app once, export through the collector, and keep your backend choice flexible.
6. **Distributed tracing: spans, traces, context propagation across services**  
   Model each request as a trace made up of spans, and carry context between services.
7. **Metrics: Prometheus scraping, custom metrics with Telemetry**  
   Scrape `/metrics` and emit application-specific measurements.
8. **Grafana: Loki (logs), Jaeger (traces), Prometheus (metrics) dashboards**  
   Use Grafana as the shared operations console.
9. **Debugging running containers: `docker exec`, `docker logs`, `docker cp`, `docker stats`**  
   Start with the core runtime inspection commands.
10. **`docker debug`: debug distroless containers without a shell**  
    Attach a toolbox environment to minimal images.
11. **`kubectl debug`: ephemeral debug containers in Kubernetes**  
    Add a temporary helper container to a live pod.
12. **Post-mortem: `docker commit` on stopped container for forensics**  
    Preserve state after a failure for later analysis.
13. **`docker diff`: see what changed at runtime**  
    Inspect filesystem drift inside a container.

## Demo Architecture

```text
Phoenix API -> stdout JSON logs -> Fluent Bit -> Loki -> Grafana
           -> OTel traces/metrics -> OTel Collector -> Jaeger + Prometheus -> Grafana
```

## Project Layout

```text
src/                     Elixir / Phoenix application
compose.yaml             Full observability stack
otel-collector-config.yaml
prometheus.yml
fluent-bit.conf
grafana/                 Datasource and dashboard provisioning
scripts/                 Setup and debugging helpers
```

## Quick Start

### 1. Start the stack

```bash
docker compose up -d --build
```

Builds the Phoenix image, starts the observability services, and wires everything onto one bridge network.

### 2. Check health endpoints

```bash
curl http://localhost:4000/health
curl http://localhost:4000/ready
```

- `/health` confirms the process is alive.
- `/ready` is the readiness endpoint for orchestrators.

### 3. Generate demo traffic

```bash
curl http://localhost:4000/items
curl -X POST http://localhost:4000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Telemetry Mug","description":"Created during the demo"}'
curl http://localhost:4000/items/1
curl http://localhost:4000/metrics
```

These requests generate:

- structured logs in stdout
- spans in Jaeger
- metrics for Prometheus and Grafana

### 4. Open the dashboards

- Grafana: <http://localhost:3000>
- Jaeger: <http://localhost:16686>
- Prometheus: <http://localhost:9090>
- App API: <http://localhost:4000>

## Commands and Explanations

### `docker compose up -d --build`
Builds the application image and starts the complete observability stack in detached mode.

### `docker logs talk-15-app-1 --follow --tail 100`
Streams the latest app logs. Because the app emits JSON to stdout, you can filter and parse fields reliably.

### `docker logs talk-15-app-1 2>&1 | grep '"level":"error"'`
Searches for error-level entries. Structured logging makes this simple and predictable.

### `docker exec -it talk-15-app-1 sh`
Opens a shell in the running app container. Useful for verifying the release layout, env vars, and runtime files.

### `docker cp talk-15-app-1:/app/releases/RELEASES ./extracted-releases.txt`
Copies a file out of the container for offline inspection.

### `docker cp ./debug-config.txt talk-15-app-1:/tmp/debug-config.txt`
Copies a file into the container for temporary debugging experiments.

### `docker stats talk-15-app-1 --no-stream`
Shows CPU, memory, network, and block I/O for a quick resource triage.

### `docker inspect talk-15-app-1 | jq '.[0] | {State, NetworkSettings: .NetworkSettings.IPAddress, Mounts}'`
Prints key runtime metadata: state, IP address, and mounted volumes.

### `docker diff talk-15-app-1`
Shows filesystem changes since the container started. `A` = added, `C` = changed, `D` = deleted.

### `docker debug talk-15-app-1`
Attaches Docker's toolbox container to a running container, which is ideal for distroless or ultra-minimal images that do not contain a shell.

### `kubectl logs -n container-series deploy/app --follow --tail 100`
Streams logs from a Kubernetes deployment.

### `kubectl exec -it -n container-series pod/app-xxx -- sh`
Executes a shell in a pod when a shell exists in the image.

### `kubectl debug -it pod/app-xxx --image=busybox:1.36 --target=app -n container-series`
Adds an ephemeral debug container to the pod. This is the Kubernetes equivalent of toolbox-style debugging.

### `docker commit stopped-container-name talk-15-debug-image`
Preserves the filesystem of a stopped container for post-mortem investigation.

### `docker run -it --entrypoint sh talk-15-debug-image`
Starts a shell in the committed image so you can inspect the preserved state.

## Logging Drivers in Context

- **`json-file`**: Docker's default local log storage. Good for simple local debugging.
- **`syslog`**: Forward logs to a syslog receiver. Common in traditional infrastructure.
- **`fluentd`**: Send logs straight to collectors like Fluent Bit or Fluentd for enrichment and shipping.

This demo uses the `fluentd` logging driver for the app container and Fluent Bit forwards those logs into Loki.

## OpenTelemetry Flow

1. Phoenix handlers create spans around requests.
2. Controller actions add attributes such as item ids and item counts.
3. The OpenTelemetry Collector receives telemetry over OTLP.
4. Jaeger stores traces and Prometheus scrapes metrics.
5. Grafana visualises logs, traces, and metrics side by side.

## Key Takeaways

1. Always log to stdout/stderr - let the platform handle routing.
2. OpenTelemetry provides vendor-neutral instrumentation.
3. `docker debug` and `kubectl debug` enable debugging even distroless containers.
4. Structured logging + distributed tracing = fast incident resolution.

## Bonus / Niche Corner: Debugging Distroless & Ephemeral Containers

- **`docker debug` (Docker Desktop)**: attach a toolbox to a running container without rebuilding it.
- **`nsenter` on Linux**: join a container's namespaces directly from the host for deeper investigation.
- **Container forensics with `docker diff`**: identify files added, changed, or deleted at runtime.
- **CRIU checkpoint/restore (experimental)**: capture and restore container state for advanced troubleshooting workflows.

## Helpful Scripts

- `scripts/setup-monitoring.sh` starts the stack and generates sample load.
- `scripts/debug-examples.sh` is a reference sheet of day-to-day debugging commands.