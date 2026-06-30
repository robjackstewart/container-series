# RUNSHEET — Talk 13: WebAssembly Containers

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` and `traditional-app/certs/` first, and trust it on the host for Spin/Wasm registry pulls.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running with Wasm support enabled — `docker version`
- [ ] Rust installed — `rustc --version`
- [ ] Wasm target available — `rustup target list --installed | grep wasm32-wasi`
- [ ] Spin CLI installed — `spin --version`
- [ ] .NET 8 SDK installed — `dotnet --version`
- [ ] Optional SpinKube cluster selected — `kubectl config current-context`
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/` and `traditional-app/certs/`, and trusted by the host OS / Docker Desktop
- [ ] Warm the caches — `docker pull mcr.microsoft.com/dotnet/sdk:8.0; docker pull mcr.microsoft.com/dotnet/aspnet:8.0; docker pull ghcr.io/containerd/runwasi/wasi-demo-app:latest; docker pull ghcr.io/fermyon/spin-hello-world:latest`
- [ ] Terminal in `talk-13-wasm-containers`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Build and run the traditional .NET container app
docker build -t talk-13-traditional ./traditional-app
docker run --rm -d --name talk-13-traditional -p 8080:8080 talk-13-traditional
sleep 3
curl -fsS http://127.0.0.1:8080/health; echo
curl -fsS http://127.0.0.1:8080/items; echo
docker stop talk-13-traditional

# 2) Build the Rust Spin app as a Wasm component
rustup target add wasm32-wasi
(cd spin-app && spin build)

# 3) Run the Spin app locally and hit the same HTTP shape
(cd spin-app && spin up --listen 127.0.0.1:3000) &
SPIN_PID=$!
sleep 3
curl -fsS http://127.0.0.1:3000/; echo
curl -fsS http://127.0.0.1:3000/health; echo
curl -fsS http://127.0.0.1:3000/items; echo
curl -fsS -X POST http://127.0.0.1:3000/items -H 'content-type: application/json' -d '{"name":"Ephemeral item"}'; echo
kill $SPIN_PID
wait $SPIN_PID 2>/dev/null || true

# 4) Run Wasm through Docker/containerd instead of a normal Linux container
docker run --rm --runtime=io.containerd.wasmtime.v1 --platform=wasi/wasm ghcr.io/containerd/runwasi/wasi-demo-app:latest
docker run --rm -d --name talk-13-docker-spin -p 3001:80 --runtime=io.containerd.spin.v2 --platform=wasi/wasm ghcr.io/fermyon/spin-hello-world:latest
sleep 3
curl -fsS http://127.0.0.1:3001/; echo
docker stop talk-13-docker-spin

# 5) Cold-start comparison: tiny Wasm process versus HTTP readiness for the .NET container
time docker run --rm --runtime=io.containerd.wasmtime.v1 --platform=wasi/wasm ghcr.io/containerd/runwasi/wasi-demo-app:latest
time sh -c 'docker run --rm -d --name talk-13-cold -p 8081:8080 talk-13-traditional >/dev/null && until curl -fsS http://127.0.0.1:8081/health >/dev/null; do sleep 0.1; done; docker stop talk-13-cold >/dev/null'

# 6) SpinKube / Kubernetes RuntimeClass demo (requires a SpinKube-enabled cluster)
kubectl apply -f k8s/runtime-class.yaml
kubectl apply -f k8s/wasm-deployment.yaml
kubectl get pods -l app=hello-spin
kubectl describe pod -l app=hello-spin | grep -i runtime
kubectl delete -f k8s/wasm-deployment.yaml
kubectl delete -f k8s/runtime-class.yaml

# 7) Bonus: point at Component Model and WIT contracts
sed -n '1,80p' spin-app/spin.toml
sed -n '1,120p' spin-app/src/lib.rs
```

## Beat-by-beat talking points
1. The .NET build is the baseline: familiar OCI image, ASP.NET runtime, full process model, and standard Docker networking.
2. The Spin build compiles Rust to a `wasm32-wasi` module and lets Spin provide the HTTP trigger host.
3. The HTTP checks show the two apps have comparable API shape, but different runtime assumptions and state models.
4. Docker + Wasm keeps the registry and Docker workflow while swapping the execution runtime underneath containerd.
5. The cold-start numbers are illustrative, not a benchmark; discuss what each path initialises before serving useful work.
6. RuntimeClass is the Kubernetes bridge: the scheduler still creates pods, but the node runtime handles Wasm differently from OCI containers.
7. The bonus files set up the Component Model conversation: typed interfaces and polyglot plugins are where Wasm becomes a platform primitive.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/` and `traditional-app/certs/`, then rebuild. For Spin builds, Docker + Wasm pulls, and Wasm OCI registry operations, also trust the same CA in the host OS and Docker Desktop trust store.
- **`COPY certs/` fails** → ensure `traditional-app/certs/.gitkeep` exists; the Docker build context for the .NET app is `traditional-app/`, not the talk root.
- **Port already in use** → stop old demo containers with `docker rm -f talk-13-traditional talk-13-cold talk-13-docker-spin`, or change host ports `8080` and `3000`.
- **Docker says the Wasm runtime is unknown** → enable Docker Desktop Wasm/containerd support, or skip the Docker + Wasm section and use local Spin.
- **SpinKube deployment does not start** → confirm the cluster has SpinKube installed and that the RuntimeClass handler name matches the cluster runtime configuration.

## Reset / cleanup
```bash
docker rm -f talk-13-traditional talk-13-cold talk-13-docker-spin 2>/dev/null || true
docker image rm talk-13-traditional 2>/dev/null || true
kubectl delete -f k8s/wasm-deployment.yaml 2>/dev/null || true
kubectl delete -f k8s/runtime-class.yaml 2>/dev/null || true
```

