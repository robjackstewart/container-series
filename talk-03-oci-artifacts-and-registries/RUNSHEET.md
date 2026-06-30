# RUNSHEET — Talk 03: OCI Artifacts and Registries

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — every build trusts it automatically.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] ORAS installed — `oras version`
- [ ] `curl` available — `curl --version`
- [ ] Logged in to a writable registry namespace — `docker login`
- [ ] Optional registry tools installed — `skopeo --version`, `wasmtime --version`, and `wat2wasm --version`
- [ ] Export a registry namespace — `export NAMESPACE=<your-dockerhub-username-or-org>`
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/`
- [ ] Warm the caches — `docker pull rocker/r-ver:4.3.0 && docker pull docker.io/library/alpine:latest`
- [ ] Terminal in `talk-03-oci-artifacts-and-registries`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Set registry coordinates for this run
export REGISTRY="${REGISTRY:-docker.io}"
: "${NAMESPACE:?Set NAMESPACE to your registry namespace before running this cue card}"
export IMAGE_TAG="1.0.0"
export IMAGE_REF="${REGISTRY}/${NAMESPACE}/talk03-r-plumber:${IMAGE_TAG}"
export GIT_REF="${REGISTRY}/${NAMESPACE}/talk03-r-plumber:git-$(git rev-parse --short HEAD 2>/dev/null || echo demo)"
export LATEST_REF="${REGISTRY}/${NAMESPACE}/talk03-r-plumber:latest"
export ARTIFACT_REF="${REGISTRY}/${NAMESPACE}/talk03-artifacts:sbom-demo"
export MODEL_REF="${REGISTRY}/${NAMESPACE}/talk03-ml-model:linear-regression"

# 2) Build and smoke-test the R / Plumber image
docker build -t talk03-r-plumber:local .
docker run --rm -d --name talk03-r-plumber -p 8000:8000 talk03-r-plumber:local
sleep 5
curl -fsS http://localhost:8000/health
curl -fsS http://localhost:8000/model-info
curl -fsS "http://localhost:8000/predict?value=12.5"
docker logs --tail 20 talk03-r-plumber
docker stop talk03-r-plumber

# 3) Tag and push immutable, traceable, and convenience references
docker login "${REGISTRY}"
docker tag talk03-r-plumber:local "${IMAGE_REF}"
docker tag talk03-r-plumber:local "${GIT_REF}"
docker tag talk03-r-plumber:local "${LATEST_REF}"
docker push "${IMAGE_REF}"
docker push "${GIT_REF}"
docker push "${LATEST_REF}"

# 4) Inspect registry metadata and manifest-list behaviour
docker manifest inspect "${IMAGE_REF}"
docker buildx imagetools inspect "${IMAGE_REF}" || docker buildx imagetools inspect docker.io/library/alpine:latest

# 5) Push and pull a standalone SBOM as an OCI artifact
rm -rf pulled-sbom
oras push "${ARTIFACT_REF}" ./sample-artifact/sbom.json:application/vnd.example.sbom.v1+json
oras pull "${ARTIFACT_REF}" -o ./pulled-sbom
ls -la ./pulled-sbom

# 6) Attach the SBOM to the image and discover referrers
oras attach "${IMAGE_REF}" ./sample-artifact/sbom.json:application/vnd.cyclonedx+json --artifact-type application/vnd.cyclonedx+json
oras discover "${IMAGE_REF}"

# 7) Optional remote registry inspection and copy discussion
if command -v skopeo >/dev/null 2>&1; then skopeo inspect "docker://${IMAGE_REF}"; fi

# 8) Bonus: store a Wasm module and config blob in OCI
REGISTRY="${REGISTRY}" REPO="${NAMESPACE}/talk03-wasm-demo" TAG="0.1.0" bash ./bonus/wasm-artifact-demo.sh

# 9) Bonus: extract the trained R model and store it as an OCI artifact
docker create --name talk03-model-extract talk03-r-plumber:local
docker cp talk03-model-extract:/app/model.rds ./sample-artifact/model.rds
docker rm talk03-model-extract
oras push "${MODEL_REF}" ./sample-artifact/model.rds:application/vnd.r-project.rds
rm -rf pulled-model
oras pull "${MODEL_REF}" -o ./pulled-model
```

## Beat-by-beat talking points
1. Registry coordinates separate the demo mechanics from any particular vendor; only the host and namespace change.
2. The R image is a real workload: build dependencies, a trained model, and a Plumber API with health and prediction endpoints.
3. The three tags show different purposes: release identity, commit traceability, and a mutable convenience pointer.
4. Manifest inspection reveals whether the reference points at a single manifest or an index / manifest list.
5. ORAS push and pull prove the registry can store typed JSON content without runnable layers.
6. ORAS attach and discover turn the SBOM into metadata related to the exact image subject.
7. Skopeo is useful for remote inspection and promotion because it does not need a local Docker pull first.
8. The Wasm bonus demonstrates runtime-neutral artifacts sharing registry auth and versioning.
9. The model bonus connects the concept back to the R app: model artefacts can be versioned independently from serving images.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. Default `certs/` is empty = no-op.
- **`COPY certs/` fails** → ensure `certs/.gitkeep` exists and the build context is the talk folder.
- **`NAMESPACE` error** → run `export NAMESPACE=<your-registry-namespace>` before the command sequence.
- **Push or ORAS attach is denied** → confirm `docker login` used the same registry host and that the namespace already exists or can be created by push.
- **Port already in use** → stop the demo container with `docker stop talk03-r-plumber`, or change the run command to another host port such as `8001:8000`.
- **Registry does not show referrers** → use `oras discover` from the CLI and explain that referrers API support can vary by registry and UI.
- **Wasm bonus fails** → install `wabt` for `wat2wasm`, or set `WASM_FILE=/path/to/module.wasm` before running the bonus script.
- **Skopeo is unavailable** → skip that command; Docker and ORAS still cover the registry concepts.

## Reset / cleanup
```bash
docker rm -f talk03-r-plumber talk03-model-extract 2>/dev/null || true
rm -rf pulled-sbom pulled-model bonus/pulled-wasm bonus/local-oci bonus/config.v2025-01-15.json sample-artifact/hello.wasm sample-artifact/hello.wat sample-artifact/model.rds
docker image rm talk03-r-plumber:local "${IMAGE_REF}" "${GIT_REF}" "${LATEST_REF}" 2>/dev/null || true
```

