# Container Security — Scanning & Hardened Images

Talk 7 introduces practical container security: how to find problems in images, how to interpret scanner output, and how to build smaller and safer runtime containers.

## Prerequisites

- Talks 1-6 completed
- Docker installed and working
- Trivy installed locally
- Docker Scout available via Docker Desktop
- Optional: Snyk CLI, Cosign, and Syft
- Basic familiarity with TypeScript, Express, and Dockerfiles

## Project overview

This talk uses a small TypeScript + Express API with two contrasting Dockerfiles:

- `Dockerfile.vulnerable`: intentionally insecure for demos
- `Dockerfile.hardened`: multi-stage, distroless, non-root runtime
- `Dockerfile.chainguard`: Chainguard-based hardened alternative

## Talk outline (~60 minutes)

1. **Container threat model**
   - Image vulnerabilities: outdated OS packages and application dependencies
   - Runtime escape risks: privileged containers, broad Linux capabilities, writable filesystems
   - Supply chain risks: poisoned dependencies, tampered images, missing provenance
2. **Vulnerability scanning**
   - Trivy for local image, filesystem, and IaC scanning
   - Docker Scout for image insights and remediation guidance
   - Snyk as another commercial/developer-friendly option
3. **Interpreting scan results**
   - CVE identifiers and what they represent
   - Severity levels: LOW, MEDIUM, HIGH, CRITICAL
   - CVSS scores and why context still matters
4. **Base image choices**
   - Ubuntu: convenient but broad package footprint
   - Debian slim: balanced default for many apps
   - Alpine: very small, but musl can complicate native modules
   - Distroless: minimal runtime, no shell/package manager
   - Chainguard: hardened, minimal, frequently rebuilt, strong supply-chain story
5. **Dockerfile security best practices**
   - Run as non-root
   - Prefer read-only filesystems when possible
   - Drop Linux capabilities you do not need
   - Use multi-stage builds and deterministic installs
6. **Supply chain security**
   - Sign images with Cosign
   - Generate SBOMs with Syft
   - Track what is actually shipped to production
7. **Docker Content Trust / Notary**
   - Verify publisher trust and signed image workflows
8. **Runtime security**
   - Default seccomp profile
   - AppArmor or similar LSM enforcement
   - Avoid `--privileged` except in controlled demos

## API endpoints

- `GET /health`
- `GET /items`
- `POST /items`
- `GET /items/:id`
- `DELETE /items/:id`

Start locally:

```bash
npm install
npm run dev
```

Build for production:

```bash
npm run build
npm start
```

## Example API usage

Health check:

```bash
curl http://localhost:3000/health
```

List items:

```bash
curl http://localhost:3000/items
```

Create an item:

```bash
curl -X POST http://localhost:3000/items \
  -H "Content-Type: application/json" \
  -d '{"name":"Review Trivy findings","description":"Discuss remediation options"}'
```

Get an item by ID:

```bash
curl http://localhost:3000/items/<item-id>
```

Delete an item:

```bash
curl -X DELETE http://localhost:3000/items/<item-id>
```

## Build the demo images

Build the intentionally vulnerable image:

```bash
docker build -f Dockerfile.vulnerable -t myapp:vulnerable .
```

This image is intentionally bad for teaching. It uses a broad base image, copies everything, installs dependencies non-deterministically, and runs as root.

Build the hardened distroless image:

```bash
docker build -f Dockerfile.hardened -t myapp:hardened .
```

This image uses a multi-stage build, `npm ci`, a smaller runtime, and a non-root user.

Build the Chainguard image:

```bash
docker build -f Dockerfile.chainguard -t myapp:chainguard .
```

This demonstrates a hardened supply-chain-focused base image strategy.

## Vulnerability scanning commands

Scan a local image with Trivy:

```bash
trivy image myapp:latest
```

Use this to get an overview of OS and application dependency vulnerabilities.

Filter to the most important findings:

```bash
trivy image --severity HIGH,CRITICAL myapp:latest
```

This reduces noise during demos and CI gates.

Scan the current directory as a filesystem:

```bash
trivy fs .
```

Useful before building, because it detects issues in source dependencies and local files.

Scan infrastructure-as-code files:

```bash
trivy config .
```

This flags insecure Dockerfile or Compose settings.

Write machine-readable reports:

```bash
trivy image --format json -o trivy-report.json myapp:latest
trivy image --format sarif -o trivy-report.sarif myapp:latest
```

JSON is useful for automation; SARIF integrates with code scanning platforms.

Fail on critical findings:

```bash
trivy image --exit-code 1 --severity CRITICAL myapp:latest
```

Good for CI/CD policy enforcement.

Apply a local ignore policy:

```bash
trivy image --ignorefile .trivyignore myapp:latest
```

Use only with documentation and time-bounded exceptions.

Compare vulnerable and hardened image results:

```bash
trivy image myapp:vulnerable
trivy image myapp:hardened
```

This gives a concrete before/after demonstration.

## Docker Scout commands

Show CVEs:

```bash
docker scout cves myapp:latest
```

Show recommendations:

```bash
docker scout recommendations myapp:latest
```

Compare two images:

```bash
docker scout compare myapp:vulnerable myapp:hardened
```

Quick summary view:

```bash
docker scout quickview myapp:latest
```

Generate an SBOM from an image:

```bash
docker scout sbom myapp:latest
```

## Snyk example commands

```bash
snyk container test myapp:latest
snyk container monitor myapp:latest
```

Use Snyk when you want policy, monitoring, and developer workflow integrations.

## Interpreting scan results

- **CVE**: a published vulnerability identifier
- **Severity**: a coarse prioritization label
- **CVSS**: a numeric score indicating theoretical impact/exploitability
- **Context matters**: a CRITICAL issue in an unreachable package may be less urgent than a HIGH issue in an internet-facing runtime path

Questions to ask when triaging:

- Is the vulnerable package actually present in the runtime image?
- Is the vulnerable code reachable?
- Is there a fixed version available?
- Can we reduce exposure through configuration or hardening?

## Base image choices

- **Ubuntu**: large ecosystem, familiar tooling, bigger surface area
- **Debian slim**: strong default for many services
- **Alpine**: very small but sometimes incompatible with glibc-based native modules
- **Distroless**: excellent runtime hardening, but debugging is harder because there is no shell
- **Chainguard**: minimal and supply-chain focused; often rebuilt quickly when vulnerabilities are disclosed

## Dockerfile and runtime hardening examples

Run the hardened image as read-only and drop capabilities:

```bash
docker run --rm \
  -p 8080:8080 \
  --read-only \
  --tmpfs /tmp \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  myapp:hardened
```

Why this helps:

- `--read-only`: prevents writes to the container filesystem
- `--tmpfs /tmp`: adds a safe temporary writable area when needed
- `--cap-drop ALL`: removes Linux capabilities the app does not need
- `--security-opt no-new-privileges:true`: blocks privilege escalation via setuid/setgid binaries

Use the default seccomp profile explicitly:

```bash
docker run --rm --security-opt seccomp=default myapp:hardened
```

Apply AppArmor where available:

```bash
docker run --rm --security-opt apparmor=docker-default myapp:hardened
```

## Supply chain security

Generate a key pair:

```bash
cosign generate-key-pair
```

Sign an image:

```bash
cosign sign --key cosign.key myregistry/myapp:latest
```

Verify the signature:

```bash
cosign verify --key cosign.pub myregistry/myapp:latest
```

Generate an SBOM:

```bash
syft myapp:latest -o cyclonedx-json > sbom.json
```

Attach the SBOM as an OCI artifact:

```bash
cosign attach sbom --sbom sbom.json myregistry/myapp:latest
```

Verify attestations:

```bash
cosign verify-attestation --key cosign.pub myregistry/myapp:latest
```

These steps help answer: who built this image, what is inside it, and can I trust it?

## Docker Content Trust / Notary

Enable Docker Content Trust:

```bash
export DOCKER_CONTENT_TRUST=1
```

Pull a trusted image:

```bash
docker pull docker.io/library/node:20
```

With content trust enabled, Docker verifies signed tags when supported. This is older than Cosign/OCI-native signing, but it is useful historical context for image trust and publisher verification.

## Bonus demo: “hacking” a container

Show how bad flags increase risk:

```bash
docker run --rm -it --privileged ubuntu bash
```

Why it is dangerous:

- `--privileged` grants nearly all capabilities
- device access increases dramatically
- container isolation is weakened
- a compromise is far more likely to become host impact

A safer teaching contrast:

```bash
docker run --rm -it --cap-drop ALL --security-opt no-new-privileges:true ubuntu bash
```

Use this section to explain that container escape is usually the result of a chain: vulnerable workload + excessive privileges + kernel/runtime weakness.

## Script helpers

- `scripts/scan-trivy.sh`
- `scripts/scan-scout.sh`
- `scripts/sign-image.sh`

These scripts package the main demo commands so you can step through them live.

## Key takeaways

- Small runtime images reduce attack surface and noise in scanners
- Non-root containers are a baseline, not an advanced option
- Scan both images and Docker/IaC configuration
- Treat CVE output as triage input, not absolute truth
- Supply-chain security includes signatures, SBOMs, and provenance
- Avoid `--privileged`, writable roots, and unnecessary capabilities
