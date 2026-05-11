#!/bin/bash
set -euo pipefail

echo "Starting full observability stack..."
docker compose up -d --build

echo "Waiting for services to be ready..."
sleep 10

echo "Grafana: http://localhost:3000"
echo "Prometheus: http://localhost:9090"
echo "Jaeger: http://localhost:16686"
echo "App: http://localhost:4000"

echo "Generating some load and spans..."
for i in {1..20}; do
  curl -s http://localhost:4000/items > /dev/null
  curl -s http://localhost:4000/health > /dev/null
  curl -s -X POST http://localhost:4000/items \
    -H "Content-Type: application/json" \
    -d '{"name":"Demo Item '$i'","description":"Created by setup script"}' > /dev/null
  sleep 0.5
done

echo "Check Grafana, Prometheus, and Jaeger for logs, metrics, and traces."
