# Speaker Guide — Talk 07: Container Security

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with an image that looks ordinary but ships too much risk: a broad base image, non-deterministic dependency install, secrets in build metadata, and root at runtime. Then show that security is not one magic tool; it is a layered reduction in attack surface, clearer supply-chain evidence, and safer runtime defaults. The big idea is that scanners do not make containers secure by themselves — they give you evidence for better engineering decisions.

## Section-by-section narrative
### 1) Container threat model
- Frame container security around three practical risks: vulnerable components in the image, unsafe runtime permissions, and weak supply-chain trust.
- Emphasise that most real incidents are chains, not single mistakes: a vulnerable dependency becomes more serious when the container runs as root, has extra capabilities, or accepts risky host mounts.
- Use `Dockerfile.vulnerable` as an intentionally poor reference point. It keeps the teaching flaws on purpose: broad `node:18`, copied build context, non-deterministic install, build arguments promoted to environment variables, and root execution.

### 2) Vulnerability scanning
- Trivy is the fast local baseline: it scans OS packages, application dependencies, filesystems, configuration, and secrets, so it is useful before and after an image build.
- Docker Scout is useful when the audience already uses Docker Desktop because it gives readable CVE views, base-image recommendations, and image comparisons.
- Snyk is worth mentioning as another developer-friendly commercial option for organisations that want policy, monitoring, and workflow integration.
- Land the message that scan output is triage input, not a release decision by itself. Ask whether the vulnerable package is in the runtime image, whether the vulnerable code path is reachable, and whether a fixed version or safer base exists.

> Expert aside: Distroless images often show fewer CVEs not because they hide findings, but because they remove whole classes of packages such as shells, package managers, and debugging utilities. That reduces both scanner noise and post-compromise tooling available to an attacker.

### 3) Hardened image design
- Contrast the vulnerable build with `Dockerfile.hardened`: deterministic `npm ci`, a separate build stage, dev dependency pruning, a tiny distroless runtime, and a non-root user.
- Explain that multi-stage builds are a security boundary in practice: compilers, package-manager caches, and development dependencies stay in the builder instead of shipping to production.
- Distroless is deliberately inconvenient for interactive debugging. That inconvenience is part of the protection model: no shell means fewer built-in tools for an attacker after code execution.
- The app uses port `8080` in the hardened images through `PORT`, while the vulnerable image keeps the default `3000` path to make the contrast visible.

### 4) Chainguard and Wolfi
- Present `Dockerfile.chainguard` as the supply-chain-oriented alternative. The `-dev` image exists for building; the runtime image is minimal and non-root by default.
- Chainguard and Wolfi focus on small package sets, rapid rebuilds, provenance, and SBOM-friendly packaging. The point is not that any base image is magically vulnerability-free forever; it is that the maintenance model reduces the window in which known issues remain present.

> Expert aside: Chainguard images are rebuilt frequently, often nightly or when upstream fixes land. That low-CVE profile depends on continuous rebuilds and fast package publication, not on ignoring vulnerability data.

### 5) Image signing and SBOMs
- Cosign answers the identity question: who signed this image and does the signature still verify against the pushed artefact?
- Keyless Cosign signing can use OIDC identity from CI instead of long-lived private keys. Rekor adds a transparency log so signatures are discoverable and tamper-evident.
- Syft answers the contents question: what packages and versions are in the image right now?
- Explain the two common SBOM formats: SPDX is widely used for licence and package inventory exchange; CycloneDX is popular in security tooling because it models components, services, and vulnerability workflows well.

> Expert aside: Signing and SBOMs solve different problems. A signed image can still be vulnerable, and a complete SBOM does not prove provenance. Together they let you ask better release questions.

### 6) Runtime hardening
- Show that image hardening is only half the story. Runtime flags such as read-only filesystems, temporary writable mounts, dropping capabilities, and `no-new-privileges` reduce the blast radius when the application is compromised.
- Seccomp is the kernel syscall filter Docker applies by default. Calling it out explicitly helps people understand that containers are isolated by layered Linux primitives, not by a single Docker feature.
- AppArmor or equivalent LSMs can add another policy layer where the host platform supports them.

### 7) Bonus: live "hacking" contrast
- The privileged Ubuntu container is a teaching prop: it shows how quickly isolation becomes weaker when broad capabilities and device access are granted.
- Keep the demo safe and bounded. Do not attempt a real escape; use it to discuss why `--privileged`, writable roots, and unnecessary capabilities make a vulnerable workload much worse.
- Follow it immediately with the safer contrast: dropping all capabilities and blocking privilege escalation.

## Discussion prompts (engage the room)
- Which findings from a scan should block a release, and who decides that policy?
- What is worse for this service: a critical package CVE in a build-only dependency, or a high-severity runtime dependency reachable from an unauthenticated route?
- When would you choose a larger debug-friendly image over distroless, and how would you compensate?
- How would your CI prove that the image being deployed is the one that was scanned and signed?

## Key takeaways (the close)
- Smaller runtime images reduce both attack surface and vulnerability noise.
- Non-root containers and reduced capabilities are baseline controls, not advanced hardening.
- Distroless and Chainguard images improve the runtime story, but they make certificate and debugging patterns more deliberate.
- Scanners, signatures, and SBOMs are evidence. They need policy and engineering judgement to become security.
- Avoid `--privileged`, writable roots, and unnecessary Linux capabilities in real workloads.

## Bonus / niche corner
Use Docker Content Trust / Notary as historical context, then position Cosign as the modern OCI-native signing workflow most teams are likely to adopt. For SBOMs, show that the useful output is not the file itself but the ability to answer inventory and incident-response questions quickly: "Do we ship this package?", "Where?", and "Which image digest contains it?"

## Netskope / corporate proxy note
Each Dockerfile trusts optional corporate CA certificates from `certs/` via the `EXTRA_CERTS_DIR` build argument. The default folder is empty, so the step is a no-op on a normal laptop. Behind Netskope or another TLS-intercepting proxy, export the corporate root as PEM, rename it with a `.crt` extension if necessary, and place it in `certs/` before building.

The hardened and Chainguard final images are shell-less, so they cannot run certificate update commands in the runtime stage. Their build stages refresh `/etc/ssl/certs/ca-certificates.crt`, then copy that bundle into the final stage. If this application later makes outbound TLS calls from Node.js, `NODE_EXTRA_CA_CERTS` can point Node at the copied bundle when the platform does not automatically use the system trust store.

> Expert aside: The certificate needs to be trusted where network I/O happens. For this talk that is primarily the build stage running `npm ci` or `npm install`; the runtime copy is included because shell-less images need a pre-built trust store if the app later performs outbound TLS.
