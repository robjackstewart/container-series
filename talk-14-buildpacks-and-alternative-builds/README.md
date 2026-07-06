# Talk 14 — Buildpacks and Alternative Builds

Build container images without maintaining Dockerfiles for every stack, then compare that experience with one traditional Dockerfile. Language: Ruby/Sinatra, Go, Java/Spring Boot, and Node.js/Express.

## What you'll learn
- How Cloud Native Buildpacks use detection, build, launch layers, SBOMs, and rebase to standardise image creation.
- How `ko`, Jib, and Nixpacks remove Dockerfile boilerplate for Go, Java, and multi-language apps.
- How to choose between platform defaults and Dockerfile-level control.

## Prerequisites
- Docker Desktop or another local Docker runtime.
- `pack` CLI installed.
- `ko` installed for the Go demo.
- Go 1.22+, Java 17+, Maven 3.9+, Node.js, npm, and Nixpacks.
- Optional: `curl` for endpoint checks.

## Folder map
- **`RUNSHEET.md`** — one-page cue card: run this talk cold in 10 minutes.
- **`notes/`** — speaker guide (the teaching narrative — what to say).
- **`ruby-app/`** — Sinatra API for Cloud Native Buildpacks and the Dockerfile comparison.
- **`go-app/`** — small Go service for `ko`.
- **`java-app/`** — Spring Boot app with Jib configured in Maven.
- **`node-app/`** — Express app for Nixpacks.
- **`comparison/`** — comparison Dockerfile and build-tool notes.
- **`scripts/`** — optional helper scripts for each builder.
- **`certs/`** — save `netskope.crt` here if you're behind a TLS-intercepting proxy (optional).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
pack build ruby-sinatra-pack --path ./ruby-app --builder paketobuildpacks/builder-jammy-base:latest --env PORT=4567
```

## Behind a TLS-intercepting proxy (Netskope)?
Save your corporate CA as **`ruby-app/certs/netskope.crt`** for the comparison Dockerfile (which uses `ruby-app/` as its build context). Build with `--secret id=netskope_cert,src=ruby-app/certs/netskope.crt` to trust it during the build — the cert is not stored in any image layer. Non-Dockerfile builders (`pack`, `ko`, Jib, Nixpacks) need host or tool-specific trust instead: see **`notes/README.md`** and **`RUNSHEET.md`** for the full presenter guidance.

## Next in the series
Talk 15 closes the course with observability and debugging for containerised workloads.
