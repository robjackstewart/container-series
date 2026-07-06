# RUNSHEET — Talk 11: CI/CD for Containers

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Copy your CA cert to `certs/netskope.crt` and add `--secret id=netskope_cert,src=certs/netskope.crt` to any `docker build` or `docker buildx build` command below.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] Python available — `python --version`
- [ ] Buildx available — `docker buildx version`
- [ ] Optional tools installed — `gh --version`, `cosign version`, `trivy --version`, and `az version`
- [ ] Registry chosen for push demos — set `$env:REGISTRY` to an ACR or GHCR registry you can push to
- [ ] (if behind Netskope) corporate `.crt` saved as `certs/netskope.crt`
- [ ] Warm the caches — `docker pull python:3.12-slim; docker pull hadolint/hadolint`
- [ ] Terminal in `talk-11-cicd-for-containers`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```powershell
# 1) Build the image locally and prove the API starts
$env:TAG = 'demo'
docker build -t talk-11-fastapi:dev .
docker run --rm -d --name talk11-fastapi -p 8000:8000 -e ENVIRONMENT=local -e APP_VERSION=dev talk-11-fastapi:dev
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod http://localhost:8000/items
docker stop talk11-fastapi

# 2) Show Buildx Bake as the declarative build graph
docker buildx bake --print

# 3) Run the Bake target as a local single-platform build
New-Item -ItemType Directory -Force .\.buildx-cache | Out-Null
docker buildx bake `
  --set app.platform=linux/amd64 `
  --set app.output=type=docker `
  --set app.tags=talk-11-fastapi:bake `
  --set app.cache-from=type=local,src=.buildx-cache `
  --set app.cache-to=type=local,dest=.buildx-cache,mode=max

# 4) Build and push a multi-architecture image
$env:REGISTRY = if ($env:REGISTRY) { $env:REGISTRY } else { 'myregistry.azurecr.io' }
docker buildx create --use --name talk11builder 2>$null
docker buildx build `
  --platform linux/amd64,linux/arm64 `
  --tag "$env:REGISTRY/container-series/talk-11:$env:TAG" `
  --push `
  .
# Behind Netskope? Add: --secret id=netskope_cert,src=certs/netskope.crt
docker buildx imagetools inspect "$env:REGISTRY/container-series/talk-11:$env:TAG"

# 5) Walk through the CI definitions that automate those same steps
Get-Content .\.github\workflows\ci.yml
Get-Content .\.github\workflows\multi-arch.yml
Get-Content .\azure-pipelines\ci.yml
Get-Content .\azure-pipelines\multi-arch.yml

# 6) Sign and verify the pushed image with Cosign
$env:IMAGE_TO_SIGN = "$env:REGISTRY/container-series/talk-11:$env:TAG"
$env:COSIGN_PASSWORD = 'container-cicd-demo'
cosign generate-key-pair
cosign sign --yes --key .\cosign.key "$env:IMAGE_TO_SIGN"
cosign verify --key .\cosign.pub "$env:IMAGE_TO_SIGN"

# 7) Bonus: lint the Dockerfile with hadolint
Get-Content -Raw .\Dockerfile | docker run --rm -i hadolint/hadolint -
```

## Beat-by-beat talking points
1. The local build proves the Dockerfile before CI enters the story; pipelines should automate known-good steps, not hide them.
2. The health call gives a quick runtime signal and shows the image carries environment metadata.
3. Bake makes the build graph reviewable: context, tags, cache, platforms, and attestations are declared once.
4. The local Bake override keeps the demo laptop on one platform and local cache while preserving the same target definition.
5. The multi-arch push creates a manifest list so AMD64 and ARM64 hosts can pull the right image from one tag.
6. The CI file walkthrough maps each local concern to automation: tests, build, scan, cache, OIDC login, push, SBOM, and provenance.
7. Cosign signs the pushed artefact; verification proves the signature still matches the registry image.
8. hadolint is the lightweight quality gate that catches Dockerfile issues before slower builds and scans run.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: save the corporate root CA as `certs/netskope.crt`, then rebuild with `--secret id=netskope_cert,src=certs/netskope.crt`. CI runners also need the corporate CA in the runner trust store for checkout, registry login, and cloud CLI calls.
- **Port already in use** → stop the previous demo container: `docker rm -f talk11-fastapi`.
- **Bake tries to use the wrong registry cache** → keep the local override in step 3; it redirects cache to `.buildx-cache` instead of the registry cache in `docker-bake.hcl`.
- **Multi-arch push fails** → confirm `$env:REGISTRY` is a registry you can push to and that `az acr login` or `docker login` has completed.
- **Cosign signing fails** → sign a pushed registry image, not a local-only tag, and remove old demo keys if `cosign generate-key-pair` refuses to overwrite them.
- **hadolint image is unavailable** → skip the bonus and mention that the same check normally runs as a CI lint step.

## Reset / cleanup
```powershell
docker rm -f talk11-fastapi 2>$null
docker buildx rm talk11builder 2>$null
docker image rm talk-11-fastapi:dev talk-11-fastapi:bake 2>$null
Remove-Item -Recurse -Force .\.buildx-cache, .\cosign.key, .\cosign.pub -ErrorAction SilentlyContinue
```
