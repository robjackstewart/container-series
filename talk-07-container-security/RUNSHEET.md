# RUNSHEET — Talk 07: Container Security

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — every build trusts it automatically.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] Trivy installed — `trivy --version`
- [ ] Docker Scout available — `docker scout version`
- [ ] Optional supply-chain tools installed — `cosign version` and `syft version`
- [ ] Optional signing target prepared — set `IMAGE_TO_SIGN` to a registry image you can push and sign
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/`
- [ ] Warm the caches — `docker pull node:18 && docker pull node:20-slim && docker pull gcr.io/distroless/nodejs20-debian12 && docker pull cgr.dev/chainguard/node:latest-dev && docker pull cgr.dev/chainguard/node:latest`
- [ ] Terminal in `talk-07-container-security`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Build the intentionally vulnerable image
docker build -f Dockerfile.vulnerable -t myapp:vulnerable .

# 2) Scan the vulnerable image with Trivy
trivy image myapp:vulnerable
trivy image --severity HIGH,CRITICAL myapp:vulnerable

# 3) Build the hardened distroless image
docker build -f Dockerfile.hardened -t myapp:hardened .

# 4) Build the Chainguard / shell-less image
docker build -f Dockerfile.chainguard -t myapp:chainguard .

# 5) Compare scan results and image sizes
trivy image myapp:hardened
trivy image myapp:chainguard
docker images myapp:vulnerable myapp:hardened myapp:chainguard
docker scout compare myapp:vulnerable myapp:hardened || true

# 6) Generate an SBOM with Syft
syft myapp:hardened -o cyclonedx-json > sbom.json
syft myapp:hardened -o spdx-json > sbom.spdx.json

# 7) Sign and verify an image with Cosign
: "${IMAGE_TO_SIGN:?Set IMAGE_TO_SIGN to a registry image you can push, for example ghcr.io/<owner>/myapp:hardened}"
export COSIGN_PASSWORD="${COSIGN_PASSWORD:-container-security-demo}"
docker tag myapp:hardened "$IMAGE_TO_SIGN"
docker push "$IMAGE_TO_SIGN"
cosign generate-key-pair
cosign sign --yes --key cosign.key "$IMAGE_TO_SIGN"
cosign verify --key cosign.pub "$IMAGE_TO_SIGN"

# 8) Live "hacking" contrast: risky privileged container
docker run --rm --privileged ubuntu bash -lc "id && echo Device entries: && ls /dev | head"

# 9) Safer contrast: no extra capabilities and no privilege escalation
docker run --rm --cap-drop ALL --security-opt no-new-privileges:true ubuntu bash -lc "id && echo Reduced-capability shell completed"

# 10) Optional runtime hardening for the app
docker run --rm -p 8080:8080 --read-only --tmpfs /tmp --cap-drop ALL --security-opt no-new-privileges:true myapp:hardened
```

## Beat-by-beat talking points
1. The vulnerable image is intentionally bad: broad base, copied context, non-deterministic install, secret-shaped build metadata, and root runtime.
2. Trivy gives the room concrete evidence. Do not count CVEs blindly; ask what ships, what is reachable, and what has a fix.
3. The hardened image keeps build tools out of production and runs on a shell-less, non-root distroless runtime.
4. The Chainguard build separates the `-dev` build image from the minimal runtime image and introduces the Wolfi / rapid rebuild model.
5. Compare sizes and scan output to make attack-surface reduction visible.
6. The SBOM is the inventory answer: what is in this image, in a format other systems can process.
7. Cosign is the trust answer: who signed this pushed artefact, and can verification reproduce that trust decision.
8. The privileged Ubuntu shell is not an exploit demo; it is a safe way to show how dangerous flags weaken isolation.
9. The safer contrast shows that runtime policy can remove whole categories of post-compromise options.
10. The final run command ties image hardening to runtime hardening.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. Default `certs/` is empty = no-op.
- **`COPY certs/` fails** → ensure `certs/.gitkeep` exists and the build context is the talk folder.
- **Chainguard pull is slow or rate-limited** → pre-pull before the session or skip to the distroless comparison.
- **Cosign signing fails** → confirm `IMAGE_TO_SIGN` points at a registry image you can push; local-only Docker tags cannot be signed usefully for this demo.
- **`cosign generate-key-pair` prompts or refuses to overwrite** → remove old demo keys first or set a fresh working folder for the talk.
- **Docker Scout is unavailable** → use the Trivy comparisons and mention Scout conceptually.
- **Port already in use** → stop the container using the printed container ID, or change the host port to `8081:8080`.

## Reset / cleanup
```bash
docker rm -f $(docker ps -aq --filter ancestor=myapp:hardened) 2>/dev/null || true
rm -f sbom.json sbom.spdx.json cosign.key cosign.pub
docker rmi myapp:vulnerable myapp:hardened myapp:chainguard 2>/dev/null || true
```
