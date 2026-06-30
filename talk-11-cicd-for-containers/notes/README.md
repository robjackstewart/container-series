# Speaker Guide — Talk 11: CI/CD for Containers

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with a small FastAPI service that can be built locally, then move the same image through pull-request validation, registry publishing, supply-chain evidence, and deployment. The big idea is that container CI/CD is not just "build and push"; it is an evidence pipeline that proves what was built, where it came from, how it was scanned, who signed it, and which environment is running it.

## Section-by-section narrative

### 1) Start with the artefact, not the pipeline
- Anchor the room on the application and Dockerfile before discussing CI. The pipeline should automate the same build, test, and scan steps a developer can reason about locally.
- Point out the multi-stage Python build: dependencies are installed in a virtual environment in the build stage, source is compiled, and the runtime stage runs as an unprivileged user.
- Treat tags as part of release design. A git SHA tag is the deployment identity; `latest` is only a convenience alias and should not be the thing an approval gate depends on.
> Expert aside: the image digest is stronger than the tag. Tags are mutable pointers; digests identify the exact manifest content that was pushed and are what signatures and attestations ultimately bind to.

### 2) GitHub Actions for container delivery
- The pull-request workflow separates application tests from image build and scan. That keeps feedback readable: first prove the app, then prove the container can be built and is not carrying critical known issues.
- The publish workflow uses GitHub OIDC with `azure/login` so the runner exchanges its short-lived identity token for Azure access rather than storing a static cloud password.
- The multi-architecture workflow adds QEMU, Buildx, SBOM generation, and provenance. This is the point where the pipeline becomes more than packaging: it emits release evidence alongside the image.
> Expert aside: OIDC does not remove the need for authorisation. It removes long-lived credentials from the repository, but the cloud-side federated credential and role assignment still define exactly which repo, branch, environment, or workflow can act.

### 3) Azure Pipelines equivalents
- Map the GitHub Actions concepts to Azure Pipelines vocabulary: workflow becomes pipeline, jobs and steps remain familiar, service connections carry cloud identity, and environments provide approval gates.
- Highlight Workload Identity Federation for Azure Resource Manager service connections as the Azure DevOps equivalent of keyless cloud authentication.
- Use the side-by-side comparison to show that the engineering principles are portable even when the YAML dialect and marketplace tasks differ.

### 4) Multi-architecture builds with Buildx and QEMU
- Explain that a multi-platform tag points to a manifest list, not one filesystem. The registry serves the correct platform-specific image when a Linux AMD64 or ARM64 host pulls the tag.
- QEMU emulation makes cross-platform builds easy on hosted runners, but it can be slower and occasionally exposes architecture-specific test gaps late.
- For production-critical ARM64 throughput, native ARM runners are often faster and more representative than emulation.
> Expert aside: Buildx can combine outputs from multiple native builders into one manifest list. Emulation is convenient for demos; native builders are the performance and fidelity answer for serious multi-arch estates.

### 5) Buildx Bake as a declarative build graph
- Introduce `docker-bake.hcl` as the build definition for teams that have outgrown long command lines. It keeps context, Dockerfile path, tags, cache policy, platforms, and attestations in one reviewable file.
- Bake is especially useful when one repository has several images or variants because targets can inherit shared settings and CI can override variables without rewriting the graph.
- In this talk the Bake target mirrors the CI multi-arch story and passes through `EXTRA_CERTS_DIR` so certificate trust behaves the same locally and in runners.
> Expert aside: Bake is not a different builder; it is a declarative front end to BuildKit. The value is repeatability and reviewability, not a new image format.

### 6) Supply-chain controls: scanning, Cosign, SBOMs, and SLSA
- Trivy is the policy gate in the sample CI: build the image, scan it, and fail the run on critical findings. Remind the room that severity alone is not risk; reachability, runtime presence, and fix availability still matter.
- Cosign answers the publisher question. In CI, keyless signing can use the workflow identity rather than a private key stored as a secret.
- SBOMs answer the contents question. Provenance attestations answer the build-origin question: which workflow, source revision, and builder produced this artefact.
- SLSA-style provenance from Buildx is a practical step towards tamper-evident releases, especially when combined with immutable tags, digests, and deployment policy.

### 7) GitOps and promotion
- Position direct deployment to Azure Container Apps as the simplest first step: the CD workflow updates the running app to the new image.
- Then introduce GitOps as the next maturity step: CI updates declarative desired state, and Flux or Argo CD reconciles the platform to match Git.
- The important promotion rule stays the same either way: build once, scan and sign once, then promote the same immutable artefact through environments.

### 8) Bonus: hadolint and pipeline hygiene
- hadolint is a cheap guardrail for Dockerfile quality. It catches common mistakes early, before they become slow CI failures or inconsistent images.
- Keep linting advisory at first if the team has legacy Dockerfiles, then tighten policy once the baseline is clean.
- Use cache deliberately. GitHub Actions cache is convenient for pull requests; registry cache is useful when multiple workflows, branches, or runners need to share layers.

## Discussion prompts (engage the room)
- Which tag would you deploy to production: `latest`, a semver tag, a git SHA, or a digest? Why?
- What would have to be true before a vulnerability scan should block a release?
- Where should signing happen: before push, after push, during deployment, or all of the above?
- When is QEMU emulation good enough, and when would native ARM64 runners be worth the cost?
- Would your team prefer direct platform deployment or GitOps reconciliation for production changes?

## Key takeaways (the close)
- Container CI/CD should produce evidence, not just images.
- OIDC and Workload Identity Federation remove long-lived cloud credentials from pipeline secrets.
- Buildx and QEMU make multi-architecture images accessible; native builders improve fidelity at scale.
- Bake turns repeatable build settings into a reviewable build graph.
- Cosign signatures, SBOMs, and SLSA provenance help teams verify what they deploy.
- GitOps keeps desired deployment state auditable and reversible.

## Bonus / niche corner
Use SLSA levels as a maturity model rather than a checklist to recite. For this talk, the practical story is provenance generation, short-lived identity, signed artefacts, and deployment of the same immutable image through environments. hadolint is the small extra quality gate that keeps Dockerfile mistakes from entering that supply-chain path.

## Netskope / corporate proxy note
This talk uses Dockerfile-based builds locally, through Buildx Bake, and inside CI. The build stage trusts optional corporate CA certificates copied from `certs/` via the `EXTRA_CERTS_DIR` build argument before `pip install` performs network I/O. The default folder is empty, so the step is a no-op on a normal laptop. Behind Netskope or another TLS-intercepting proxy, export the corporate root as PEM, rename it with a `.crt` extension if necessary, and place it in `certs/` before building.

CI needs the same distinction: the runner host must trust the corporate CA for runner-level operations such as registry login, checkout, and cloud CLI calls, while the Docker build needs `EXTRA_CERTS_DIR` so package installation inside the build container trusts the same CA. Do not hardcode certificate content in workflow YAML or pipeline variables; provide `.crt` files through the build context or runner image according to your organisation's secret-handling policy.

The FastAPI runtime in this demo does not make outbound TLS calls, so the runtime stage only carries a comment. If the application later calls HTTPS APIs at runtime, copy or install the refreshed CA bundle into the runtime image as well.
