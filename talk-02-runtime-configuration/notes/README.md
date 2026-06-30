# Speaker Guide — Talk 02: Runtime Configuration

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start from the idea that an image should be boring and reusable, while the container instance receives the facts that vary by environment. Then layer in the runtime concerns that make a container usable outside a toy demo: secrets, service discovery, persistence, health, restart policy, and resource boundaries. The big idea is that containerisation is not just packaging; the runtime contract is where operations, security, and portability meet.

## Section-by-section narrative

### 1) Configuration belongs outside the image
- Open with the 12-factor principle: the same image should move through development, test, and production, while environment-specific values are supplied at container start.
- Use the Flask app to make that visible. It reads database host, port, name, user, secret key, and environment from runtime variables, and `/config` deliberately hides the secret value.
- Draw the boundary between Dockerfile defaults and deployment-time configuration. `ENV` is useful for safe defaults such as `PYTHONUNBUFFERED`, `PORT`, or a default environment name; it is not a vault.

### 2) Inline values versus env files
- Show inline `-e` flags first because they are explicit and help the room see each variable being injected.
- Then switch to `.env` via `--env-file` to show the operational version: easier to review, easier to reuse, and less error-prone than a very long run command.
- Reinforce that `.env.example` is safe sample configuration, while a real `.env` should remain local and uncommitted.

### 3) Build-time values and secret mounts
- Contrast `ARG` and `ENV` with BuildKit secrets. `ARG APP_VERSION` and `BUILD_NOTE` are acceptable because they are non-sensitive metadata; credentials would be unsafe because build metadata and image history can outlive the build.
- The Dockerfile's BuildKit secret step is deliberately a teaching prop: the secret is available only to the one build step that asks for it, then the demo removes the temporary file.
- Make the important distinction: BuildKit secrets solve build-time access, such as private package feeds; runtime secrets still need runtime delivery from the orchestrator, platform, or secret manager.
> Expert aside: BuildKit `--mount=type=secret` does not copy the secret into the build context or commit it to a layer. The risk returns if the build step writes the secret into the filesystem, logs it, or bakes it into generated artefacts.

### 4) Networking modes and service discovery
- Begin with the default mental model: a container gets its own network namespace and published ports create a host-to-container path.
- A user-defined bridge is the normal local multi-container pattern because Docker DNS resolves container names on that network. The BusyBox ping is not about ICMP; it proves name-based service discovery.
- Host networking is a platform caveat. On native Linux it shares the host network namespace directly; on Docker Desktop it is mediated by the VM, so behaviour can differ.
- `--network=none` is the isolation contrast: the process can still run, but network assumptions become obvious quickly.

### 5) Storage: bind mounts, volumes, and tmpfs
- Explain storage by ownership and lifecycle. A bind mount is a host path made visible in the container, so it is transparent but coupled to that workstation or server.
- A named volume is Docker-managed persistence. It survives container replacement without requiring the operator to remember a host directory layout.
- `tmpfs` is memory-backed scratch space. It is fast and disappears when the container stops, which is useful for transient files that should not persist.
> Expert aside: bind mounts expose a specific host path, named volumes live under the container engine's managed storage, and `tmpfs` never writes to the container writable layer. They look similar inside the container, but their ownership, backup, portability, and security characteristics are very different.

### 6) Health checks and lifecycle behaviour
- Use the image `HEALTHCHECK` to separate "the process exists" from "the application is ready to serve useful traffic".
- The `/health` endpoint validates required environment variables, so the demo shows why health checks should reflect real readiness rather than a shallow process check.
- Restart policies belong to the container engine lifecycle. `unless-stopped` is a useful local-server default, but explain that orchestrators usually replace this with their own restart and scheduling model.

### 7) Resource limits
- Resource flags are the bridge from local demos to shared hosts. `--memory` caps the container's RAM and `--cpus` constrains scheduling time.
- Explain that limits protect neighbours and also make failure modes more predictable. Without limits, one noisy container can degrade the whole host.
> Expert aside: Docker memory limits are implemented through cgroups. If a process exceeds a hard memory limit, the kernel can kill it and Docker reports an OOM-style termination; in Kubernetes the same class of event is surfaced as `OOMKilled`.

### 8) Bonus: Podman comparison
- Position Podman as familiar but architecturally different. The CLI mirrors many Docker commands, so day-to-day build and run muscle memory mostly transfers.
- The two important differences are daemonless operation and rootless containers as a first-class workflow. That changes the privilege model, especially on developer machines and shared Linux hosts.
- Pods are the Podman-specific teaching hook: grouping containers into a shared network namespace maps neatly to Kubernetes concepts and makes `podman generate kube` a useful bridge.
> Expert aside: rootless Podman reduces dependence on a privileged central daemon. It does not remove every kernel-level risk, but it narrows the impact of a compromised container process because it runs under an unprivileged user namespace.

## Discussion prompts (engage the room)
- Which configuration values in your services are safe image defaults, and which must be runtime-only?
- If a secret appears in `docker history`, what process failed: build design, review, CI policy, or all three?
- When would you choose a bind mount over a named volume, despite the host coupling?
- What does your platform use health checks for: readiness, restart decisions, load balancing, or release gates?
- How would your team explain the difference between Docker Desktop host networking and native Linux host networking during an incident?

## Key takeaways (the close)
- Build one reusable image and inject environment-specific configuration when the container starts.
- `ARG` and `ENV` are not secret stores; BuildKit secret mounts are safer for build-time credentials but do not solve runtime secret management.
- User-defined bridge networks give local containers useful DNS-based service discovery.
- Bind mounts, named volumes, and `tmpfs` are different lifecycle choices, not interchangeable syntax.
- Health checks, restart policies, and resource limits turn a running container into an operable service.
- Podman is close enough for many Docker workflows, but rootless and daemonless operation are the real architectural differences.

## Bonus / niche corner
Use `bonus/podman-comparison.sh` as a narrated comparison rather than a full second demo if time is tight. It is enough to show that `podman build` and `podman run` feel familiar, then pause on pods and `podman generate kube` because those are the concepts Docker users are less likely to have seen.

## Netskope / corporate proxy note
This talk has one Dockerfile, and the stage that runs `apt-get` and `pip install` trusts optional corporate CA certificates from `certs/` before any network package installation. The default folder contains only a placeholder, so the step is effectively harmless on a normal laptop. Behind Netskope or another TLS-intercepting proxy, export the corporate root as PEM, ensure the file has a `.crt` extension, place it in `certs/`, and rebuild.

