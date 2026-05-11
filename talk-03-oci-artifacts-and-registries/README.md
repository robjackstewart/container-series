# OCI Artifacts & Container Registries

Talk 3 moves beyond "just build an image" and focuses on what registries can store, how the OCI specifications fit together, and how an R / Plumber API can be published, inspected, tagged, and extended with extra artifacts such as SBOMs.

## Learning goals

By the end of this talk you should be able to:

- explain the difference between the OCI image, distribution, and runtime specifications
- describe what OCI artifacts are and why registries now store more than container images
- build, tag, inspect, and push an R / Plumber API image
- use ORAS to push, pull, discover, and attach non-container artifacts
- compare registry options such as Docker Hub, GitHub Container Registry, and Azure Container Registry
- choose sane image tagging strategies for demos and real delivery pipelines

## Prerequisites

Complete the material from **Talk 1** and **Talk 2** first.

You should also have:

- a Docker Hub account
- Docker installed and working
- ORAS CLI installed (`oras version`)
- optional but recommended: `skopeo`, Docker Buildx, and access to `ghcr.io` or Azure Container Registry

## Project layout

```text
.
├── Dockerfile
├── oci-artifacts-demo.sh
├── src
│   ├── api.R
│   └── train_model.R
├── sample-artifact
│   ├── policy.rego
│   └── sbom.json
└── bonus
    └── wasm-artifact-demo.sh
```

## The demo application

The main application is a tiny **R / Plumber API** backed by a pre-trained linear model. The model is generated during the image build with `train_model.R`, which writes `model.rds` into the container filesystem.

### Build and run locally

```bash
# Build the image for the talk demo.
docker build -t talk03-r-plumber:local .

# Run the API on port 8000.
docker run --rm -p 8000:8000 talk03-r-plumber:local
```

Explanation:

- `docker build` reads the `Dockerfile`, installs R packages, trains the model, and packages the API.
- `-t talk03-r-plumber:local` gives the image a human-friendly local tag.
- `docker run --rm -p 8000:8000` starts the API and maps container port 8000 to your host.

### Test the endpoints

```bash
# Health check.
curl "http://localhost:8000/health"

# Inspect model metadata.
curl "http://localhost:8000/model-info"

# Get a prediction for x = 12.5.
curl "http://localhost:8000/predict?value=12.5"
```

Explanation:

- `/health` confirms the service is running and whether the model loaded.
- `/model-info` returns coefficients and summary metrics from the trained linear model.
- `/predict?value=12.5` sends a query parameter into the model and returns a JSON prediction.

## Talk outline (~60 mins)

### 1. OCI spec overview

OCI is a family of related specifications rather than one single document.

- **Image Spec**: defines manifests, configs, layers, annotations, and how an image is described.
- **Distribution Spec**: defines how clients push and pull content from registries.
- **Runtime Spec**: defines how a container runtime should execute a bundle on a host.

Useful mental model:

- image spec = what the thing looks like
- distribution spec = how the thing moves around
- runtime spec = how the thing is run

Inspect an image manifest:

```bash
docker manifest inspect talk03-r-plumber:local
```

Explanation:

- `docker manifest inspect` shows the manifest document that points at config and layer blobs.
- This is the bridge between the image you build and the registry object you later push.

### 2. What are OCI artifacts?

Registries are now general content-addressable stores for OCI descriptors, not just container images.

Examples of OCI artifacts beyond containers:

- Helm charts
- SBOMs
- signatures and attestations
- WebAssembly modules
- ML models
- policy bundles
- static configuration blobs

Why this matters:

- the same auth, replication, retention, and access controls can apply to more than images
- related artifacts can be attached to an image as referrers
- supply-chain metadata can travel alongside the deployable workload

### 3. ORAS CLI: push, pull, discover, attach

ORAS makes registry interaction explicit and artifact-friendly.

Push a JSON artifact:

```bash
oras push docker.io/<your-user>/talk03-artifacts:sbom-demo \
  ./sample-artifact/sbom.json:application/vnd.example.sbom.v1+json
```

Explanation:

- `oras push` uploads a file as an OCI artifact.
- `docker.io/<your-user>/talk03-artifacts:sbom-demo` is the target artifact reference.
- `file:mediaType` tells ORAS how to label the blob in the manifest.

Pull it back:

```bash
oras pull docker.io/<your-user>/talk03-artifacts:sbom-demo -o ./pulled-sbom
```

Explanation:

- `oras pull` downloads the artifact contents from the registry.
- `-o ./pulled-sbom` writes the retrieved files into a local directory.

Attach an SBOM to an existing image:

```bash
oras attach docker.io/<your-user>/talk03-r-plumber:1.0.0 \
  ./sample-artifact/sbom.json:application/vnd.cyclonedx+json \
  --artifact-type application/vnd.cyclonedx+json
```

Explanation:

- `oras attach` creates a new artifact that refers to an existing image manifest.
- `--artifact-type` gives the referrer itself a meaningful type.
- This is a common pattern for SBOMs, signatures, and attestations.

Discover referrers:

```bash
oras discover docker.io/<your-user>/talk03-r-plumber:1.0.0
```

Explanation:

- `oras discover` asks the registry for artifacts attached to the subject image.
- In modern OCI workflows, this is how you find supply-chain metadata related to an image.

### 4. Working with registries: Docker Hub, ghcr.io, ACR

Common registry choices:

- **Docker Hub**: easiest for public demos and learning.
- **ghcr.io**: good fit when your source code already lives on GitHub.
- **Azure Container Registry (ACR)**: enterprise registry with Azure identity and networking controls.

Example tags for the same image in different registries:

```bash
# Docker Hub
docker tag talk03-r-plumber:local docker.io/<your-user>/talk03-r-plumber:1.0.0

# GitHub Container Registry
docker tag talk03-r-plumber:local ghcr.io/<your-org>/talk03-r-plumber:1.0.0

# Azure Container Registry
docker tag talk03-r-plumber:local <your-acr>.azurecr.io/talk03-r-plumber:1.0.0
```

Explanation:

- `docker tag` does not copy layers; it adds another reference to the same local image.
- Registry hostnames become part of the full image name.

### 5. Authentication

Most registry auth starts with a login flow.

```bash
# Docker Hub or any OCI-compatible registry supported by Docker.
docker login

# GitHub Container Registry.
docker login ghcr.io

# Azure Container Registry.
docker login <your-acr>.azurecr.io
```

Explanation:

- `docker login` stores credentials so later `push` and `pull` operations succeed.
- On developer machines, credential helpers keep secrets out of plain text when configured.
- CI pipelines should prefer short-lived tokens or platform-managed identities.

Credential helpers matter because they move stored registry credentials into safer backends such as:

- macOS Keychain
- Windows Credential Manager
- pass / secretservice on Linux

### 6. Image tagging strategies

Good tags help humans and automation answer "what exactly is deployed?"

Common strategies:

- **semver**: `1.4.2`
- **git SHA**: `git-9f2c1d4`
- **date-based**: `2025-01-15`
- **channel tags**: `dev`, `staging`, `prod`

Recommended pattern:

```bash
# Immutable release tag.
docker tag talk03-r-plumber:local docker.io/<your-user>/talk03-r-plumber:1.0.0

# Commit-specific tag for traceability.
docker tag talk03-r-plumber:local docker.io/<your-user>/talk03-r-plumber:git-$(git rev-parse --short HEAD)

# Convenience tag for demos only.
docker tag talk03-r-plumber:local docker.io/<your-user>/talk03-r-plumber:latest
```

Why `latest` is risky:

- it is mutable
- it hides exactly what changed
- it makes rollback and debugging harder
- many users assume it means newest or safest, which is not guaranteed

### 7. docker tag, docker push, docker pull

A normal registry workflow:

```bash
# Tag the local image.
docker tag talk03-r-plumber:local docker.io/<your-user>/talk03-r-plumber:1.0.0

# Upload it.
docker push docker.io/<your-user>/talk03-r-plumber:1.0.0

# Pull it on another machine.
docker pull docker.io/<your-user>/talk03-r-plumber:1.0.0
```

Explanation:

- `docker push` uploads manifests and any missing blobs.
- `docker pull` retrieves the manifest first, then downloads layers the client does not already have.
- OCI registries are content-addressed, so shared blobs are reused.

### 8. Inspecting images: docker manifest inspect, skopeo

`docker manifest inspect` gives raw manifest data:

```bash
docker manifest inspect docker.io/<your-user>/talk03-r-plumber:1.0.0
```

Use `skopeo` for richer remote inspection without pulling the image locally:

```bash
skopeo inspect docker://docker.io/<your-user>/talk03-r-plumber:1.0.0
```

Explanation:

- `docker://` tells skopeo to read from a registry transport.
- `skopeo inspect` is great for CI, policy checks, and metadata inspection.

Copy an image between registries:

```bash
skopeo copy \
  docker://docker.io/<your-user>/talk03-r-plumber:1.0.0 \
  docker://ghcr.io/<your-org>/talk03-r-plumber:1.0.0
```

Explanation:

- `skopeo copy` moves artifacts registry-to-registry without a local `docker pull` + `docker push` round trip.
- This is useful for promotion pipelines and air-gap staging workflows.

### 9. Manifest lists and multi-arch images (intro)

A multi-arch image is typically a manifest list (OCI index) that points at platform-specific manifests.

Inspect a multi-arch reference:

```bash
docker buildx imagetools inspect docker.io/library/alpine:latest
```

Explanation:

- `docker buildx imagetools inspect` shows the platforms available under a single tag.
- This is the entry point to talking about `linux/amd64`, `linux/arm64`, and why one tag can serve many runtimes.

## End-to-end registry workflow for this talk

```bash
# 1. Build the R API image.
docker build -t talk03-r-plumber:local .

# 2. Tag it for Docker Hub.
docker tag talk03-r-plumber:local docker.io/<your-user>/talk03-r-plumber:1.0.0

# 3. Log in.
docker login

# 4. Push the image.
docker push docker.io/<your-user>/talk03-r-plumber:1.0.0

# 5. Inspect the remote image metadata.
skopeo inspect docker://docker.io/<your-user>/talk03-r-plumber:1.0.0

# 6. Attach an SBOM.
oras attach docker.io/<your-user>/talk03-r-plumber:1.0.0 \
  ./sample-artifact/sbom.json:application/vnd.cyclonedx+json \
  --artifact-type application/vnd.cyclonedx+json

# 7. Discover related artifacts.
oras discover docker.io/<your-user>/talk03-r-plumber:1.0.0
```

## Key takeaways

- OCI is a set of complementary specs: image, distribution, and runtime.
- Registries are increasingly artifact stores, not only image stores.
- ORAS is the easiest way to demonstrate generic OCI artifacts.
- Good tagging strategy matters as much as the image build itself.
- `skopeo` is excellent for remote inspection and registry-to-registry copy.
- Multi-arch support builds on indexes / manifest lists that point at per-platform images.

## Bonus: storing weird things in registries

Registries are surprisingly useful for non-traditional payloads.

Examples worth showing in discussion or labs:

- **Wasm modules**: ship a runtime-neutral binary with registry auth and versioning.
- **ML models**: store model files close to the images that serve them.
- **config CDN**: distribute versioned JSON or YAML config blobs through a registry.
- **policy bundles**: publish OPA/Rego content as OCI artifacts.
- **SBOMs and attestations**: keep supply-chain metadata attached to the image it describes.

See:

- `oci-artifacts-demo.sh` for the main ORAS and registry workflow
- `bonus/wasm-artifact-demo.sh` for Wasm and local OCI layout examples
- `sample-artifact/` for artifact payloads used in the demos
