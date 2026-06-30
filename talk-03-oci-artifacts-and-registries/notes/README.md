# Speaker Guide — Talk 03: OCI Artifacts and Registries

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with a familiar container image: a small R / Plumber API that serves predictions from a trained model. Then zoom out from Docker commands to the registry data model: manifests, blobs, descriptors, tags, digests, indexes, and referrers. The big idea is that an OCI registry is a content-addressable distribution system, not merely a place where Docker images live.

## Section-by-section narrative
### 1) OCI is a family of specifications
- Frame OCI as three related contracts: the image specification describes the shape of images and artifacts; the distribution specification describes push, pull, and discovery through registries; the runtime specification describes how a bundle becomes a running container.
- Use the R / Plumber image as the concrete anchor: Docker builds it, the registry stores it, and the runtime eventually executes it.
- Keep the distinction sharp: a registry does not run containers; it stores manifests and blobs that other tools can verify, copy, and execute elsewhere.
> Expert aside: OCI descriptors are deliberately small records containing a media type, size, and digest. That descriptor pattern is why a registry can link images, SBOMs, signatures, policy bundles, and other payloads without understanding the payload contents.

### 2) Build the R / Plumber image before discussing registries
- The Dockerfile starts from a Rocker R base image, installs Plumber and JSON support, trains a simple linear model during the build, and copies only the model plus API into the runtime stage.
- The API gives the room something tangible to tag and push: health, model metadata, and prediction endpoints make the image feel like a real workload rather than a registry-only toy.
- Point out that the image is intentionally small enough to understand, but realistic enough to discuss dependency restore, model files, and runtime process boundaries.

### 3) Tags are names; digests are identity
- Explain that tags such as `1.0.0`, `latest`, `dev`, or `git-abc123` are mutable pointers. They are useful for humans and workflows, but they are not immutable proof of content.
- Digests are content-addressed identities. If the manifest bytes change, the digest changes; that is the property signing, policy, and reproducible deployment rely on.
- Recommend pairing a human release tag with a commit-specific tag, and using `latest` only as a convenience pointer for demos or carefully controlled channels.
> Expert aside: The digest identifies the manifest, not the friendly tag. Two tags can point at the same digest, and one tag can later be moved to a different digest. That is why production evidence should record the digest that was deployed.

### 4) ORAS makes generic OCI artifacts visible
- Introduce ORAS as the tool that removes the “container image only” mental model. It can push and pull arbitrary files as OCI artifacts as long as each blob has a media type.
- The standalone SBOM push demonstrates that the registry can store a JSON document without any runnable container layers.
- Pulling the artifact back proves the round trip: the registry is storing typed content, not just Docker-specific image metadata.

### 5) Attach and discover supply-chain metadata
- Move from standalone artifacts to related artifacts. An SBOM is most useful when it refers to the image it describes, so ORAS can attach it to the image manifest as a referrer.
- `oras discover` is the teaching moment: the image becomes the subject, and related artifacts such as SBOMs, signatures, attestations, and policies become discoverable metadata around it.
- Mention that registry support for the referrers API is still an ecosystem detail to verify when choosing a platform.
> Expert aside: The OCI artifact manifest has an `artifactType` field for the artifact as a whole and descriptors for each blob it carries. The referrers API lets clients ask “what points at this digest?” without inventing tag naming conventions such as `sha256-...sbom`.

### 6) Registry choices and promotion paths
- Compare Docker Hub, GitHub Container Registry, and Azure Container Registry through practical delivery concerns: authentication model, organisation ownership, private networking, retention, replication, and integration with CI/CD.
- Skopeo is useful because it can inspect and copy registry content without first pulling it into the local Docker daemon.
- Stress that promotion should move known content between environments; retagging or rebuilding casually can destroy traceability.

### 7) Manifest lists and multi-architecture images
- A single image reference can point at an OCI index, also known in Docker terminology as a manifest list. The index then points at platform-specific manifests for `linux/amd64`, `linux/arm64`, and other variants.
- This explains why `docker pull alpine:latest` can select the right architecture for different machines while the user types the same reference.
- For this talk, inspection is enough. Building a multi-arch R image is a separate engineering topic involving Buildx builders, cross-platform base images, and native package availability.
> Expert aside: An index is not a bigger image; it is a routing table of descriptors. The runtime chooses a child manifest matching the platform, then pulls that manifest's config and layers by digest.

### 8) Bonus: arbitrary artifacts, Wasm modules, and ML models
- The bonus script shows a Wasm module stored as an OCI artifact and pulled back for execution with a Wasm runtime when available.
- The model-file bonus is deliberately relevant to this R API: the trained `model.rds` can be extracted and stored as its own versioned OCI artifact, close to the image that serves it.
- Use this to broaden the audience's imagination: registries can carry Helm charts, policy bundles, SBOMs, signatures, Wasm modules, ML models, static configuration, and environment promotion bundles.

## Discussion prompts (engage the room)
- Which artifacts in your current delivery process should be attached to the image digest rather than stored in a separate wiki or file share?
- When would you deploy by tag, and when would you insist on deploying by digest?
- What registry capabilities matter most for your team: access control, retention, replication, referrers, private networking, or audit logs?
- How would you prove that the SBOM, signature, and policy decision all refer to the exact image that reached production?

## Key takeaways (the close)
- OCI is a set of interoperable specifications for image shape, registry distribution, and runtime execution.
- Registries store content-addressed manifests and blobs; container images are only one kind of OCI content.
- ORAS is the easiest way to demonstrate push, pull, attach, and discover for non-image artifacts.
- Tags are convenient pointers; digests are immutable identities.
- Manifest lists and OCI indexes let one reference serve multiple platforms.
- Arbitrary artifacts such as Wasm modules and ML models can share registry authentication, retention, and versioning with container images.

## Bonus / niche corner
Use the Wasm path to show a runtime-neutral binary travelling through the same registry as the API image. Use the ML-model path to ask whether models should be baked into images, shipped separately as artifacts, or promoted as a matched image-and-model pair. The best answer depends on release cadence, rollback needs, model size, and whether the serving image can safely fetch model content at startup.

## Netskope / corporate proxy note
This talk uses a Dockerfile based on Debian-style Rocker images. Optional corporate CA certificates are copied from `certs/` through the `EXTRA_CERTS_DIR` build argument before `apt-get` and R package installation perform outbound TLS. The files must be PEM-encoded `.crt` files; if Netskope exports a `.pem`, rename it to `.crt` after confirming it is PEM text.

The final runtime stage inherits the trusted CA bundle from the base stage. If the running Plumber API later makes outbound TLS calls, it will use that Debian trust store; leave `certs/` empty for normal machines where no interception certificate is required.
