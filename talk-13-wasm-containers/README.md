# WebAssembly Containers — The Future of Lightweight Compute

This talk introduces WebAssembly (Wasm) as a new packaging and runtime model for lightweight compute, then compares it with traditional Linux containers. The demo uses a Rust HTTP component compiled to the `wasm32-wasi` target with [Fermyon Spin](https://developer.fermyon.com/spin/), plus a .NET 8 minimal API for comparison.

## Prerequisites

- Completion of Talks 1-12 in this series
- Rust toolchain installed
- `wasm32-wasi` Rust target available
- [Spin CLI](https://developer.fermyon.com/spin/install)
- Docker Desktop with Wasm support enabled
- Optional: a Kubernetes cluster with SpinKube installed for the RuntimeClass demo

## Talk outline (~60 minutes)

1. **What is WebAssembly (Wasm)?**  
   Origins in the browser, the binary format, sandboxing, portability, and design goals such as fast startup and deterministic execution.
2. **WASI: giving Wasm access to the OS safely**  
   Explain how WASI provides controlled capabilities for filesystem, clocks, environment variables, and standard I/O.
3. **The famous Solomon Hykes quote about Docker and Wasm**  
   > "If WASM+WASI existed in 2008, we wouldn’t have needed to create Docker. That’s how important it is. Webassembly on the server is the future of computing. A standardized system interface was the missing link. Let’s hope WASI is up to the task!"
4. **Docker + Wasm: containerd shims**  
   Show how Docker can delegate Wasm workloads to runtimes such as Wasmtime, WasmEdge, and Spin via containerd shims.
5. **Running Wasm workloads with `docker run --runtime=io.containerd.wasmtime.v1`**  
   Demonstrate the Docker runtime flag and explain why `--platform=wasi/wasm` matters.
6. **Fermyon Spin: building HTTP handlers in Rust targeting Wasm**  
   Walk through `spin.toml`, the Rust component, and the local `spin up` development loop.
7. **Comparing Wasm vs traditional containers**  
   Compare startup time, binary or image size, attack surface, distribution model, and operational trade-offs.
8. **Wasm in Kubernetes: RuntimeClass, SpinKube**  
   Introduce RuntimeClass and explain how SpinKube schedules Wasm workloads differently from standard OCI workloads.
9. **Use cases**  
   Edge compute, plugins, untrusted code execution, policy engines, extensibility points, and serverless-style handlers.
10. **Limitations**  
   No raw sockets in many runtimes, immature threading support, filesystem restrictions, capability-based access, and a younger tooling ecosystem.

## Repository layout

```text
spin-app/         Rust + Spin HTTP component targeting wasm32-wasi
traditional-app/  .NET 8 minimal API for traditional container comparison
scripts/          Build and runtime helper scripts
k8s/              Kubernetes RuntimeClass and deployment examples
```

## Spin app commands

### 1. Install the Wasm target

```bash
rustup target add wasm32-wasi
```

Adds the Rust compilation target used to produce a WASI-compatible `.wasm` module.

### 2. Build the Rust Wasm component

```bash
cd spin-app
cargo build --target wasm32-wasi --release
```

Compiles the Spin HTTP component into a WebAssembly module at:

```text
target/wasm32-wasi/release/hello_spin.wasm
```

### 3. Run locally with Spin

```bash
spin up
```

Reads `spin.toml`, builds the component if needed, and hosts the HTTP trigger locally.

### 4. Test the HTTP endpoints

```bash
curl http://127.0.0.1:3000/
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/items
curl -X POST http://127.0.0.1:3000/items \
  -H "content-type: application/json" \
  -d '{"name":"Ephemeral item"}'
```

These commands show the Wasm app returning a welcome message, health JSON, a hard-coded item list, and a stateless POST response.

## Traditional container commands

### 1. Build the .NET app locally

```bash
cd traditional-app
dotnet build
```

Builds the full ASP.NET Core process-based application.

### 2. Run it locally

```bash
dotnet run
```

Starts the app on port `8080` so you can compare behavior with the Spin app.

### 3. Build the Docker image

```bash
docker build -t talk-13-traditional .
```

Packages the .NET application into a traditional OCI image using a multi-stage Dockerfile.

### 4. Run the traditional container

```bash
docker run -p 8080:8080 talk-13-traditional
```

Launches the full Linux userspace container image for comparison with the Wasm runtime.

## Docker + Wasm commands

### 1. Check Docker Wasm support

```bash
docker info | grep -i wasm
```

Confirms that Docker Desktop is configured with Wasm-capable runtimes.

### 2. Run a Wasm workload with Wasmtime

```bash
docker run --runtime=io.containerd.wasmtime.v1 --platform=wasi/wasm \
  ghcr.io/containerd/runwasi/wasi-demo-app:latest
```

Demonstrates the generic Wasmtime-based containerd shim path.

### 3. Run a Spin workload with Docker

```bash
docker run --runtime=io.containerd.spin.v2 --platform=wasi/wasm \
  ghcr.io/fermyon/spin-hello-world:latest
```

Uses the Spin shim instead of the Wasmtime shim, which is useful for HTTP-triggered Spin apps.

## Helper scripts

### Build everything

```bash
./scripts/build-wasm.sh
```

This script:
- adds the `wasm32-wasi` target,
- builds the Rust Wasm module,
- shows the resulting `.wasm` file size,
- builds the traditional Docker image,
- prints Docker image information for size comparison.

### Run Docker Wasm examples

```bash
./scripts/run-docker-wasm.sh
```

This script:
- checks Docker for Wasm support,
- runs a public Spin Wasm example,
- runs the traditional container,
- performs a basic cold-start timing comparison.

## Kubernetes example

### Apply the RuntimeClass

```bash
kubectl apply -f k8s/runtime-class.yaml
```

Registers a RuntimeClass that maps pods to a Spin-backed Wasm runtime.

### Deploy the Wasm workload

```bash
kubectl apply -f k8s/wasm-deployment.yaml
```

Creates a small deployment using the RuntimeClass so the workload is executed by the Wasm runtime instead of the default OCI runtime.

## Wasm vs traditional containers

| Topic | Wasm workload | Traditional container |
| --- | --- | --- |
| Startup | Usually milliseconds | Often slower due to full process and image startup |
| Artifact size | Single `.wasm` module can be tiny | OCI images often include runtime + filesystem layers |
| Isolation model | Sandboxed with capability-based access | Namespaces, cgroups, seccomp, AppArmor, etc. |
| OS assumptions | Minimal, via WASI | Full userland and process model |
| Best fit | Edge, plugins, serverless, untrusted code | General apps, long-running services, rich OS integration |

## Key takeaways

- Wasm is not just for browsers; it is becoming a practical server-side runtime model.
- WASI gives Wasm modules controlled access to host capabilities without exposing a full OS surface.
- Docker and Kubernetes are both evolving to support Wasm workloads using alternate runtimes.
- Spin provides a productive Rust-first developer experience for building Wasm HTTP handlers.
- Wasm excels when startup time, isolation, and small artifact size matter most.
- Traditional containers still win when applications need mature networking, threads, and deep OS integration.

## Bonus topics

### Component Model

The Wasm Component Model aims to standardize interfaces between modules so components written in different languages can interoperate more easily.

### Polyglot plugins

Wasm is compelling for plugin systems because plugins can be shipped in different languages while still executing inside a constrained sandbox.

### Cold start comparison

A strong demo is to compare:
- `spin up` or a Wasm Docker runtime startup,
- versus starting the `.NET 8` container,
- then discuss what those numbers mean for edge and serverless workloads.

## Suggested demo flow

1. Build and run the Spin app.
2. Hit `/`, `/health`, and `/items`.
3. POST a new item and explain why it is not persisted across requests.
4. Build and run the .NET app.
5. Compare artifact size and startup characteristics.
6. Show the RuntimeClass and Wasm deployment manifests.
7. Close with use cases, limitations, and the Component Model roadmap.
