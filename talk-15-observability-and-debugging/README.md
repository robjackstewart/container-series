# Container Observability & Debugging

Talk 15 focuses on making containers understandable in production: what they log, how they emit metrics and traces, and how to debug them when things go wrong. The demo stack uses an Elixir / Phoenix API running in containers with Fluent Bit, Loki, OpenTelemetry, Prometheus, Jaeger, and Grafana.

## Prerequisites

- Talks 1-14 in this series
- Docker Engine / Docker Desktop with Docker Compose v2
- Elixir + Phoenix installed locally **optional** for editing or experimenting outside containers
- `curl` for generating sample traffic
- `kubectl` for the Kubernetes debugging examples

Everything in the runnable demo is designed to execute in containers.

## What this talk includes

- A Phoenix-style JSON API with health, readiness, metrics, and item endpoints
- Structured JSON request logging to stdout
- Prometheus-compatible metrics at `/metrics`
- OpenTelemetry spans exported to the OTel Collector
- Fluent Bit log forwarding into Loki
- Grafana datasources and a starter dashboard
- Command references for day-to-day container debugging and post-mortem inspection

## Talk outline (~60 minutes)

1. **Three pillars of observability: logs, metrics, traces**  
   Explain what each pillar answers: logs tell stories, metrics show trends, traces explain request flow.
2. **Container logging: stdout/stderr convention, Docker logging drivers**  
   Show why container apps should write logs to stdout/stderr and let the platform collect them.
3. **Structured logging (JSON) for machine parsing**  
   Demonstrate JSON logs that are easy to filter, aggregate, and enrich.
4. **Log aggregation: Fluent Bit -> Loki**  
   Route container logs into a searchable backend.
5. **OpenTelemetry: SDK, auto-instrumentation, OTel Collector**  
   Introduce the SDK in the app and centralize export through a collector.
6. **Distributed tracing: spans, traces, context propagation**  
   Trace requests through the Phoenix API and discuss baggage/context headers.
7. **Metrics: Prometheus scraping, custom metrics**  
   Scrape `/metrics` and graph request rate, latency, and errors.
8. **Grafana: dashboards, Loki logs, Tempo traces, Mimir metrics**  
   Use Grafana as the single glass pane. This demo ships with Prometheus + Jaeger, but the same patterns extend to Mimir and Tempo.
9. **Debugging containers: `docker exec`, `docker logs`, `docker cp`**  
   Cover the first-response tools every engineer reaches for.
10. **`docker debug`: debugging distroless containers**  
    Explain how toolbox-style debugging helps when a container has no shell.
11. **`kubectl debug`: ephemeral containers in Kubernetes**  
    Show how to attach a debug container to a live pod.
12. **Post-mortem debugging: `docker commit` on stopped container**  
    Capture state for later analysis.
13. **Container forensics: `docker diff`**  
    Inspect file-system drift and runtime changes.

## Architecture

```text
Phoenix API -> stdout JSON logs -> Fluent Bit -> Loki -> Grafana
           -> OTel spans/metrics -> OTel Collector -> Jaeger + Prometheus -> Grafana
```

## Project layout

```text
src/                     Phoenix-style Elixir application
compose.yaml             Demo stack
otel-collector-config.yaml
prometheus.yml
fluent-bit.conf
grafana/                 Datasources and dashboard provisioning
scripts/                 Setup and debugging helpers
```

## Quick start

### 1. Build and start the stack

```bash
docker compose up -d --build
```

Builds the Phoenix image, starts the OTel Collector, Prometheus, Loki, Jaeger, Grafana, and Fluent Bit, and wires them onto one network.

### 2. Confirm the API is healthy

```bash
curl http://localhost:4000/health
curl http://localhost:4000/ready
```

- `/health` confirms the process is alive.
- `/ready` is the readiness endpoint you can later map to orchestrator probes.

### 3. Generate traces, logs, and metrics

```bash
curl http://localhost:4000/items
curl -X POST http://localhost:4000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Telemetry Mug","description":"Created during the demo"}'
curl http://localhost:4000/items/1
curl http://localhost:4000/metrics
```

These requests create:

- JSON request logs on stdout
- custom Prometheus counters and histograms
- OpenTelemetry spans for the item endpoints

### 4. Open the UIs

- Grafana: <http://localhost:3000>
- Prometheus: <http://localhost:9090>
- Jaeger: <http://localhost:16686>
- App API: <http://localhost:4000>

## Commands and what they show

### Logs

```bash
docker logs app --follow --tail 100
```

Streams the latest application logs. Because the app writes structured JSON to stdout, log pipelines can parse fields like method, path, duration, and status.

### Live shell into a running container

```bash
docker exec -it app sh
```

Useful for quick inspection, checking environment variables, or confirming the release layout inside the container.

### Copy a file out of a container

```bash
docker cp app:/app/releases/0.1.0/sys.config ./extracted-sys.config
```

Helpful when you need to inspect generated runtime configuration without rebuilding the image.

### Inspect resource usage

```bash
docker stats app --no-stream
```

Shows CPU, memory, and I/O at a glance.

### Inspect container configuration

```bash
docker inspect app | jq '.[] | {State, NetworkSettings, Mounts}'
```

Shows the container state, IP/network wiring, and mounted volumes.

### Search logs in Loki from Grafana

Use the **Explore** view in Grafana with this query:

```logql
{job="container-logs"}
```

This filters to the logs sent by Fluent Bit.

### Inspect traces in Jaeger

Open Jaeger and search for the `elixir-phoenix-app` service. The `items.list`, `items.show`, `items.create`, and `items.delete` spans make request flow visible.

### Inspect raw Prometheus metrics

```bash
curl http://localhost:4000/metrics
```

Returns Prometheus exposition text, including the custom request counters and latency histogram.

## Debugging workflows

### Basic container debugging

1. `docker logs` for symptoms
2. `docker inspect` for wiring and env vars
3. `docker exec` for live investigation
4. `docker cp` for evidence collection
5. `docker stats` for quick resource triage

### Debugging minimal or distroless images

`docker exec` only works when a shell exists in the image. If your production image is distroless, use:

```bash
docker debug app
```

`docker debug` attaches a toolbox environment to the target container so you can inspect processes, files, and network state without rebuilding the image.

### Kubernetes debugging with ephemeral containers

```bash
kubectl debug -it pod/app-xxx --image=busybox --target=app
```

This starts a temporary debug container in the same pod and namespace context, which is ideal when the main container has no shell or package manager.

### Post-mortem debugging

```bash
docker commit stopped-app app-debug
docker run -it --entrypoint sh app-debug
```

Use this when a container has already crashed and you want to preserve its filesystem state for offline investigation.

### Filesystem forensics

```bash
docker diff app
```

Shows which files were added, changed, or deleted since container start.

## Monitoring flow in this demo

- **Phoenix app** emits JSON logs and spans.
- **Fluent Bit** receives Docker log events and forwards them to **Loki**.
- **OTel Collector** receives OTLP telemetry and fans out traces and metrics.
- **Prometheus** scrapes metrics.
- **Jaeger** stores traces.
- **Grafana** visualizes metrics, logs, and traces from one place.

## Key takeaways

- Containers should log to stdout/stderr and let the platform route logs.
- JSON logs are much easier to query than free-form text.
- Metrics show trends; traces explain why a single request was slow.
- The OTel Collector decouples apps from backends and simplifies routing.
- Debugging is faster when you know the escalation path: logs -> inspect -> exec/debug -> forensic tools.

## Bonus topics

### Debugging distroless images

- Prefer `docker debug` over rebuilding a special shell-enabled image.
- In Kubernetes, use `kubectl debug` with an ephemeral toolbox container.

### CRIU checkpoint / restore

Checkpoint/restore can freeze a running container, save its state, and restore it later. It is useful for advanced migrations, forensic capture, and experimentation, though support depends on the runtime, kernel, and host configuration.

### Tempo and Mimir in production

This sample uses Jaeger and Prometheus because they are easy to demo. In larger platforms, Grafana Tempo and Grafana Mimir provide horizontally scalable trace and metrics backends while keeping the same observability concepts.

## Helper scripts

- `scripts/setup-monitoring.sh` brings the stack up and generates sample traffic.
- `scripts/debug-examples.sh` is a command reference for live demos.
