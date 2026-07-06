# Speaker Guide — Talk 13: WebAssembly Containers

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with the familiar shape: a .NET minimal API packaged as a traditional Linux container. Then introduce WebAssembly as a smaller, capability-oriented runtime model and use Fermyon Spin to make that model practical for HTTP workloads. The big idea is not that Wasm replaces containers everywhere; it is that Wasm gives us another deployment primitive for fast-starting, tightly sandboxed, portable compute.

## Section-by-section narrative

### 1) What WebAssembly is outside the browser
- Explain Wasm as a compact binary instruction format with a verifier, a sandbox, and a host runtime. It is designed to start quickly and execute predictably across environments.
- Make the distinction between the module and the host: the module contains portable code; the host decides what clocks, files, networking, environment variables, and storage capabilities are exposed.
- Tie this back to containers: both are packaging and isolation models, but containers package a process plus filesystem assumptions, while Wasm packages code that depends on explicit host interfaces.
> Expert aside: a Wasm sandbox is not Linux namespace isolation. Containers isolate OS resources around a normal process; Wasm isolates at the runtime boundary and only exposes host functions that the runtime grants.

### 2) WASI: safe host access
- WASI is the standardisation effort that gives non-browser Wasm modules a controlled system interface.
- Describe it as capability-based rather than ambient authority: the component does not automatically see the host filesystem or network just because those exist.
- Use `spin.toml` as the visible teaching artefact. It declares the HTTP trigger, the compiled module path, and the outbound-host policy.
> Expert aside: WASI's security story depends on what the host grants. A module with no pre-opened directory cannot simply wander the host filesystem; it needs that capability to be passed in.

### 3) Fermyon Spin as the developer experience
- Spin turns the low-level Wasm runtime model into an application framework: route an HTTP request, invoke a component, return a response.
- In this talk, the Rust component exposes the same shape as the .NET app: a home route, health endpoint, item list, and POST response.
- Land the statelessness point carefully. The Spin handler reconstructs its base items on each request; persistent state needs an external store or Spin-provided state feature.

### 4) Docker + Wasm
- Docker can run Wasm workloads by delegating through containerd shims such as Wasmtime or Spin rather than starting a normal Linux container process.
- `--platform=wasi/wasm` tells the runtime this artefact is not a normal Linux image. The runtime flag chooses the shim that understands how to execute it.
- This is useful because teams can reuse familiar image distribution and runtime workflows while experimenting with Wasm execution.
> Expert aside: a Wasm artefact can still be distributed through OCI registries. The registry is the packaging and transport layer; the node runtime decides whether the payload becomes a Linux process or a Wasm instance.

### 5) Wasm versus traditional containers
- Compare the .NET container with the Spin app without turning it into a winner-takes-all argument.
- Wasm strengths: small artefacts, near-zero cold start, narrow host capabilities, good fit for edge, plugins, policy engines, and serverless-style request handlers.
- Container strengths: mature networking, long-running services, rich OS integration, broad language/runtime compatibility, and familiar debugging and operations.
> Expert aside: near-zero cold start is not magic; there is simply less to initialise. A Wasm runtime verifies and instantiates a module, whereas a container usually creates a process inside a prepared filesystem and starts a language runtime or application server.

### 6) SpinKube and Kubernetes
- Kubernetes can schedule Wasm workloads by using RuntimeClass to select a runtime handler other than the default OCI runtime.
- SpinKube brings Spin applications into Kubernetes by pairing cluster components with a Spin-capable runtime.
- The key teaching point is that Kubernetes remains the orchestrator, but the node runtime changes how the workload is executed.

### 7) Cold-start comparison
- Use the timing section to provoke judgement, not to claim a universal benchmark.
- A small Wasm example should start extremely quickly; the .NET container is still fast, but it carries an OS image, ASP.NET runtime, and process model.
- Remind the room that production latency also includes registry pulls, node cache state, platform scheduling, TLS, storage, and downstream dependencies.

## Discussion prompts (engage the room)
- Which of your workloads really need a full Linux userland at runtime?
- Where would capability-based host access reduce risk compared with a general-purpose container?
- Would your platform team prefer Wasm because it is safer, or resist it because the tooling is younger?
- What should be measured before claiming a Wasm migration improves user-facing latency?

## Key takeaways (the close)
- WebAssembly is a portable runtime target, not just a browser technology.
- WASI makes host access explicit and capability-oriented.
- Spin gives Wasm HTTP workloads a productive application model.
- Docker and Kubernetes can both host Wasm through alternate runtimes and shims.
- Wasm is excellent for lightweight, isolated, fast-starting compute; containers remain the default for broad OS compatibility.

## Bonus / niche corner
The Wasm Component Model is the next step beyond single modules. It defines component interfaces so separately compiled pieces can communicate through typed contracts rather than ad hoc host calls. WIT, the WebAssembly Interface Type language, describes those contracts in a language-neutral way.

This is why Wasm is compelling for polyglot plugin systems. A host can define an interface once, then accept plugins written in Rust, C#, TinyGo, JavaScript, or another supported language, provided they compile to components that implement the same WIT contract. The governance story is attractive: plugin authors get language choice, while the host keeps a tight sandbox and explicit capabilities.

## Netskope / corporate proxy note
This talk has two certificate paths. The traditional .NET Dockerfile trusts an optional corporate CA via a BuildKit secret (`--secret id=netskope_cert,src=traditional-app/certs/netskope.crt`) before `dotnet restore` runs — save the cert as `traditional-app/certs/netskope.crt` because `traditional-app/` is the Docker build context. The cert is never written to any image layer. Omit `--secret` when not behind a TLS-intercepting proxy.

Spin and Wasm registry operations are non-Dockerfile builders for this talk. `spin build`, runtime pulls, and OCI registry operations use the host trust store rather than a Dockerfile build stage. Behind Netskope or another TLS-intercepting proxy, trust the corporate CA at the operating-system level and in Docker Desktop or the container runtime used for registry pulls. If host trust is wrong, fixing `certs/` alone will not repair Spin or Wasm OCI pull failures.
