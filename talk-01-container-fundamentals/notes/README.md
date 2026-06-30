# Speaker Guide — Talk 01: Container Fundamentals

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with the mental model: a container is not a tiny virtual machine, it is a process with isolation and packaged dependencies. Then build a deliberately straightforward image so the mechanics are visible, inspect the layers, and finish by reshaping the same app into a production-friendly multi-stage image. The big idea is that container quality is mostly about boundaries: what enters the build context, what becomes a layer, what stays in the final image, and what is supplied at runtime.

## Section-by-section narrative

### 1) Containers are packaged processes, not lightweight VMs
- Land the distinction clearly: a VM virtualises hardware and carries a guest operating system; a Linux container shares the host kernel and isolates processes with kernel primitives.
- Namespaces give the process its own view of things such as process IDs, networking, mounts, host names, and users. cgroups constrain resources such as CPU and memory.
- Emphasise the trade-off: containers start quickly and distribute efficiently, but they do not have the same isolation boundary as a full virtual machine.
> Expert aside: an image is inert data; a container is a running process created from that data plus runtime configuration. That distinction explains why rebuilding an image and restarting a container are different operational actions.

### 2) Docker architecture and the build context
- Introduce the Docker client, Docker daemon, image registry, image, and container as separate moving parts.
- The build context is the set of files sent to the builder. It is not automatically “the repo”; it is whatever the chosen context path includes after `.dockerignore` is applied.
- Use this to motivate context hygiene early. A noisy context slows builds and can accidentally make local artefacts available to Dockerfile instructions.
> Expert aside: OCI image layers are tar archives addressed by cryptographic digest. Registries and runtimes can deduplicate them because the digest represents the layer content, not the local file name or tag you happened to use.

### 3) The first Dockerfile: readable, useful, intentionally imperfect
- Walk through the single-stage Dockerfile as the first principles version: choose a base image, set a working directory, copy source, restore, publish, document the port, and define the process.
- Be honest that it works but is not how we would ship most production services. The SDK, build tooling, and source tree remain in the final image.
- Use the single-stage image to explain `FROM`, `WORKDIR`, `COPY`, `RUN`, `EXPOSE`, `ENV`, and `ENTRYPOINT` without overloading the room.
> Expert aside: broad copy steps such as `COPY . .` are convenient, but Docker cache keys include the copied content. A README edit or local artefact can invalidate an expensive restore layer unless the Dockerfile first copies only stable dependency descriptors.

### 4) Layers, cache reuse, and why ordering matters
- `docker history` is the bridge from Dockerfile text to image reality: each instruction contributes metadata or filesystem changes.
- Good Dockerfiles put stable, expensive work early and volatile source changes later. For .NET, that means restoring after the project file is copied, then copying the rest of the source before publish.
- Explain that caching is not just about speed. It also makes builds more predictable, easier to reason about, and cheaper in CI.

### 5) Build-time values versus runtime configuration
- `ARG` is for the build. It can stamp the image or choose build-time behaviour, but it is not a reliable runtime configuration mechanism.
- `ENV` is part of the image configuration and becomes visible to the application process unless overridden when the container starts.
- Use `APP_VERSION` as the simple example: CI can stamp it at build time, and the container can expose it at runtime through the API.

### 6) Multi-stage builds: the default production shape
- The build stage uses the SDK because compilation needs the compiler, restore tooling, and publish tooling.
- The runtime stage uses the ASP.NET Core runtime image because the application only needs the published output and the runtime.
- Highlight the security and operations wins: smaller image, fewer packages to scan, clearer responsibility, faster pulls, and a non-root user.
> Expert aside: smaller images are not automatically secure, but they reduce the inventory of things that can be vulnerable. The better question is “does the final image contain only what the process needs to run?”

### 7) BuildKit cache mounts and developer feedback
- BuildKit cache mounts keep the NuGet package cache outside the final image while still speeding up repeated restores.
- This is a good example of separating build acceleration from runtime contents. The cache helps the builder; it does not become part of the deployed artefact.
- Reinforce that modern Docker Desktop enables BuildKit by default, but the Dockerfile syntax line makes the advanced mount syntax explicit.

### 8) `.dockerignore`, ports, logs, and operational basics
- `.dockerignore` prevents build output, editor folders, Git metadata, local secrets, and diagnostics from entering the context.
- `EXPOSE` is documentation for humans and tooling; publishing a port happens when the container is run.
- Logs should go to standard output and standard error. Containers are easier to operate when the platform can collect logs without entering the container.

## Discussion prompts (engage the room)
- What files in your current projects would accidentally enter a Docker build context if `.dockerignore` were missing?
- When would a VM still be a better boundary than a container?
- Which is riskier: a large image with familiar tools inside, or a tiny image that makes live debugging harder?
- What should be decided at image build time, and what must remain runtime configuration?
- If a source edit forces dependency restore every time, what Dockerfile ordering mistake would you suspect first?

## Key takeaways (the close)
- Containers package an application and its dependencies while sharing the host kernel.
- Dockerfile ordering matters because images are layered and cache keys are content-sensitive.
- `ARG` is build-time input; `ENV` and run arguments shape runtime behaviour.
- `.dockerignore` is part of the security and performance story, not housekeeping.
- Multi-stage builds are the normal production pattern for compiled applications.
- Running as a non-root user is a small change with a meaningful security benefit.
- BuildKit cache mounts can improve feedback loops without bloating runtime images.

## Bonus / niche corner
Use `dive` if the room is curious about what actually changed in each layer. It makes the “images are content-addressed filesystem changes” idea visible and helps people spot wasted space quickly.

The `scratch` example is deliberately extreme: a static Go binary copied into an empty filesystem. It is useful because it strips the model down to the minimum possible final image — no shell, no package manager, no libc, and no operating-system userland. The trade-off is equally important: if it fails in production, you cannot exec into a shell to poke around, and you must explicitly provide anything the binary needs, such as CA certificates for outbound TLS.

## Netskope / corporate proxy note
This talk uses Dockerfiles for all image builds. The SDK build stages trust optional corporate CA certificates copied into `certs/` through the `EXTRA_CERTS_DIR` build argument before NuGet restore runs. The files must be PEM-encoded `.crt` files; if a proxy exports `.pem`, rename it to `.crt` after confirming it is PEM text.

The final ASP.NET Core runtime image in the multi-stage example does not make outbound TLS calls during the demo, so no additional CA bundle is copied there. The `scratch` bonus image has no CA trust store at all; copy `ca-certificates.crt` from a builder only if the binary itself needs outbound TLS.
