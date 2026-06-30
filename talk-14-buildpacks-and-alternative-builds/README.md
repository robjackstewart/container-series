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
- **`certs/`** — drop a corporate CA `.crt` here if you're behind Netskope (optional; empty = no-op).

## Run it
See **`RUNSHEET.md`** for the exact command sequence. Quick start:
```bash
pack build ruby-sinatra-pack --path ./ruby-app --builder paketobuildpacks/builder-jammy-base:latest --env PORT=4567
```

## Behind a TLS-intercepting proxy (Netskope)?
Copy your corporate CA (`.crt`, PEM) into **`certs/`** as the talk-level placeholder. Non-Dockerfile builders also need host or tool-specific trust: `pack` can mount host certs or use trust-related build environment, `ko` can use `SSL_CERT_FILE`, Jib can use a JVM trust store, and Nixpacks follows host trust. The comparison Dockerfile builds with **`ruby-app/`** as its context, so its `EXTRA_CERTS_DIR` default resolves to **`ruby-app/certs/`**. See **`notes/README.md`** and **`RUNSHEET.md`** for the full presenter guidance.

## Next in the series
Talk 15 closes the course with observability and debugging for containerised workloads.
