# Speaker Guide — Talk 14: Buildpacks and Alternative Builds

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with the pain of hand-maintained Dockerfiles: every team repeats runtime selection, dependency installation, cache ordering, users, health checks, and patching decisions. Then show that modern builders turn source code into OCI images by encoding those decisions into tooling. The big idea is not that Dockerfiles are obsolete; it is that platform teams can choose where they want control and where they want safe, repeatable defaults.

## Section-by-section narrative

### 1) Why move beyond Dockerfiles?
- Open with the familiar Dockerfile problem: flexibility is valuable, but copied templates drift and small mistakes become fleet-wide problems.
- The Ruby/Sinatra app is deliberately ordinary. That keeps the focus on build strategy rather than application complexity.
- Position the comparison Dockerfile as the control sample: transparent and powerful, but every good practice must be written and maintained by somebody.

> Expert aside: Dockerfiles are an imperative build recipe, while most alternative builders are policy engines wrapped around source detection. The image is still OCI; the difference is who owns the build policy.

### 2) Cloud Native Buildpacks and the CNB lifecycle
- Explain the Cloud Native Buildpacks model: a builder image contains buildpacks, a lifecycle, and stack/run image metadata.
- Detection decides which buildpacks apply from files such as `Gemfile`, `package.json`, or Maven descriptors. Build then creates language/runtime layers, dependency layers, and launch metadata.
- Launch layers are deliberately separate from build-only work. This is why buildpacks are attractive for platform teams: the same source tree can inherit organisation-wide defaults without a Dockerfile in every repo.

> Expert aside: Buildpacks detect and build without a Dockerfile, but they are not magic. Detection is a contract between the application shape and buildpack order; changing files such as `Gemfile.lock` or `Procfile` changes what the lifecycle can infer.

### 3) `pack` for the Ruby/Sinatra app
- Use `pack` as the local doorway into CNB. The presenter should emphasise that Docker Desktop is still useful here because `pack` uses a local daemon for the demo image.
- Call out the `Procfile`, Rack entry point, `PORT`, and `0.0.0.0` binding as the application-side signals that make the Ruby app buildpack-friendly.
- Compare builders as a policy choice. Paketo, Heroku, and Google builders package different stacks, language versions, base images, and security opinions.
- Mention SBOM metadata as a built-in supply-chain advantage: the builder can describe what it installed instead of forcing security teams to reverse engineer the final filesystem.

### 4) Rebase as the CNB operations story
- Rebase is the moment that usually makes buildpacks click for operations-minded audiences. The application layers can remain intact while the run image layers are swapped for patched equivalents.
- Make the distinction between rebuilding app code and replacing base runtime layers. Rebase is most powerful when the stack/run image relationship is managed consistently across many services.
- Use it as a security patching story, not just a speed trick.

> Expert aside: `pack rebase` swaps the run image underneath compatible app layers. It does not re-run dependency installation, so it is fast; the trade-off is that stack compatibility matters and must be managed deliberately.

### 5) `ko` for Go
- Introduce `ko` as the most opinionated path in the talk: Go source becomes a container image with very little ceremony.
- It is a strong fit for small Go services because the build output is a single binary and the runtime can be very small.
- Emphasise that `ko` can build daemonless for registry workflows, which is attractive in locked-down CI where Docker-in-Docker is undesirable.

> Expert aside: `ko` builds Go images daemonless and commonly targets distroless-style bases. That removes a Dockerfile and a lot of runtime userland, but it also means debugging and certificate trust have to be planned rather than improvised inside a shell.

### 6) Jib for Java
- Jib belongs in the Java build lifecycle. Maven or Gradle already understands dependencies, classes, resources, and packaging, so Jib uses that knowledge to create image layers.
- Highlight why its layering matters: third-party dependencies change less often than application classes, so rebuilds and pulls become more cache-efficient.
- Jib can build to a local Docker daemon for the demo or push straight to a registry in CI without requiring Docker.

> Expert aside: Jib layers dependencies, resources, and classes separately. That is a better fit for JVM change patterns than a generic `COPY target/app.jar` layer, especially when only application classes change.

### 7) Nixpacks for multi-language convenience
- Present Nixpacks as a developer-experience tool: it detects the app, produces a build plan, and creates an image without the presenter writing a Dockerfile.
- It feels familiar to teams that have used Heroku-style build flows, especially for prototypes, internal platforms, and mixed-language repositories.
- Be clear about the trade-off: convenience and broad detection are useful, but highly regulated or unusual runtimes may still need the explicitness of a Dockerfile or custom build policy.

### 8) Comparison and decision guide
- Compare the tools on control, daemon requirements, stack fit, cache efficiency, and supply-chain evidence.
- Dockerfiles maximise control and are still the right choice for unusual OS packages, exotic runtimes, or very deliberate hardening.
- Buildpacks suit platform standardisation and fast patching. `ko` suits Go services. Jib suits JVM teams. Nixpacks suits fast multi-language onboarding.
- The right decision is often per platform tier rather than per developer preference.

## Discussion prompts (engage the room)
- Which parts of your current Dockerfiles are genuinely application-specific, and which are copy-pasted platform policy?
- Who should own base image patching: every application team, or the platform that provides builders and run images?
- When would you accept less Dockerfile control in exchange for rebase, SBOMs, and consistent defaults?
- Which CI environments in your organisation forbid Docker daemon access, and which builders become more attractive there?

## Key takeaways (the close)
- Alternative builders still produce normal OCI images; they change the build workflow, not the deployment target.
- Cloud Native Buildpacks are strongest when an organisation wants shared build policy, metadata, and rebase.
- `ko`, Jib, and Nixpacks each remove Dockerfile work by leaning into their ecosystem's source and dependency model.
- Reproducibility improves when base images, dependency inputs, layer ordering, and timestamps are controlled.
- Dockerfiles remain the escape hatch when explicit control matters more than standardised convenience.

## Bonus / niche corner
Reproducible builds are worth a short aside because image digests are only meaningful when the inputs are controlled. Buildpacks and Jib help by standardising layer order and metadata; Go builds can be made more repeatable with pinned modules; Node and Ruby still depend heavily on lockfiles. `SOURCE_DATE_EPOCH` is the common convention for removing wall-clock time from build artefacts when the toolchain honours it.

Custom buildpacks are the enterprise extension point. A platform team can package internal certificates, agents, compliance checks, or launch conventions into a buildpack rather than asking every service team to copy another Dockerfile snippet. Keep the message balanced: custom buildpacks are powerful, but they become platform software that must be versioned, tested, and supported.

Revisit `pack rebase` if there is time. It is the operational superpower of CNB because it separates app changes from run-image patching, but it only works safely when builders, run images, and stack IDs are managed as a compatible set.

## Netskope / corporate proxy note
This talk is mostly non-Dockerfile builders, so do not invent Dockerfiles just to solve certificate trust. The certificate needs to be trusted where network I/O happens: dependency download, builder pulls, registry pushes, and package manager access.

- **Buildpacks / `pack`** — trust the corporate CA on the host running Docker and `pack`. For build-time network calls, use `--volume hostcerts:/etc/ssl/certs/extra:ro` with a real host cert directory, or set trust-related environment such as `SSL_CERT_FILE` and relevant buildpack `BP_*` environment when the selected buildpack supports it.
- **`ko`** — trust registry and module downloads from the host process. Use host OS trust and `SSL_CERT_FILE` for custom CA bundles where needed.
- **Jib** — Maven and Jib run inside a JVM, so use the JVM trust store route for intercepted TLS, including `-Djavax.net.ssl.trustStore` and the matching password/type options when a custom trust store is required.
- **Nixpacks** — treat it as host-driven builder orchestration. Install the corporate CA into the host trust store used by Docker/Nixpacks and the package managers it invokes.
- **Comparison Dockerfile** — the only Dockerfile in this talk is `comparison/Dockerfile.ruby`. The demo builds it with `ruby-app/` as the Docker build context, so pass `--secret id=netskope_cert,src=ruby-app/certs/netskope.crt` and save the cert as `ruby-app/certs/netskope.crt`. The cert is never written to any image layer; the talk-root `certs/` folder remains the course-level placeholder.
