# RUNSHEET — Talk 15: Observability and Debugging

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — every build trusts it automatically.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] Docker Compose v2 available — `docker compose version`
- [ ] `curl` installed — `curl --version`
- [ ] Optional debugging tools available — `jq --version`, `kubectl version --client`, and `docker debug --help`
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/`
- [ ] Warm the caches — `docker compose pull; docker compose build`
- [ ] Terminal in `talk-15-observability-and-debugging`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Start the Phoenix API and the full observability stack
docker compose up -d --build
sleep 15
docker compose ps

# 2) Prove the API is alive and ready
curl -fsS http://localhost:4000/health
curl -fsS http://localhost:4000/ready

# 3) Generate traffic for traces, metrics, and logs
for i in $(seq 1 40); do
  curl -fsS http://localhost:4000/items >/dev/null
  curl -fsS -X POST http://localhost:4000/items \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Telemetry Item $i\",\"description\":\"Generated during Talk 15\"}" >/dev/null
  curl -fsS http://localhost:4000/items/1 >/dev/null
  sleep 0.2
done

# 4) Show metrics directly, then through Prometheus
curl -fsS http://localhost:4000/metrics | head -40
curl -fsS "http://localhost:9090/api/v1/query?query=app_http_requests_total"

# 5) Show logs flowing towards Loki
curl -fsS http://localhost:3100/ready
docker logs talk-15-app-1 --tail 30

# 6) Open the visual tools for the audience
echo "Grafana:    http://localhost:3000  (anonymous admin)"
echo "Jaeger:     http://localhost:16686  (service: elixir-phoenix-app)"
echo "Prometheus: http://localhost:9090   (query: app_http_requests_total)"
echo "Loki:       open Grafana Explore and query {job=\"container-logs\"}"

# 7) Live container debugging basics
docker stats talk-15-app-1 --no-stream
docker inspect --format '{{.State.Status}} {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' talk-15-app-1
docker diff talk-15-app-1 | head

# 8) Minimal-image debugging pattern with Docker Debug
docker debug talk-15-app-1 || echo "docker debug unavailable here; explain the toolbox-container pattern and continue"

# 9) Kubernetes ephemeral container pattern, if you have a real pod available
# kubectl debug -it pod/app-xxx --image=busybox:1.36 --target=app -n container-series

# 10) Bonus: CRIU checkpoint/restore pattern, only where Docker experimental support is enabled
# docker checkpoint create talk-15-app-1 before-debug
# docker start --checkpoint before-debug talk-15-app-1
```

## Beat-by-beat talking points
1. The compose stack gives us the whole local operations picture: app, Collector, Jaeger, Prometheus, Loki, Fluent Bit, and Grafana.
2. Health and readiness prove the process boundary before we talk about telemetry.
3. Load generation creates all three signals: Phoenix spans, Prometheus metrics, and JSON logs.
4. Metrics are visible as plain text first; Prometheus is a scraper and time-series query engine on top.
5. Logs start as stdout JSON, pass through Docker's fluentd driver and Fluent Bit, then land in Loki.
6. Jaeger is for following request flow; Grafana is for putting logs, metrics, and traces side by side.
7. Basic Docker inspection still matters: stats, inspect, diff, and logs are the fastest first look.
8. `docker debug` demonstrates how to attach tools without rebuilding the production image with a shell.
9. Ephemeral containers are the Kubernetes version of the same idea: bring a toolbox to the pod rather than changing the app image.
10. CRIU is the advanced teaser: freeze and restore process state when the platform supports it.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. Default `certs/` is empty = no-op.
- **Port already in use** → stop the previous stack with `docker compose down --remove-orphans`, or change host ports `4000`, `3000`, `9090`, `16686`, `3100`, and `24224` in `compose.yaml`.
- **Loki has no logs** → confirm `fluent-bit` is running with `docker compose logs fluent-bit`; then generate more API traffic.
- **Jaeger has no traces** → wait a few seconds after generating traffic, then check `docker compose logs otel-collector` for OTLP export errors.
- **`docker debug` is unavailable** → skip the live command and explain the toolbox-container pattern; Docker Desktop version and subscription features vary.
- **Kubernetes command fails** → it is optional and needs a real cluster, namespace, pod name, and permission to create ephemeral containers.

## Reset / cleanup
```bash
docker compose down --remove-orphans
```
