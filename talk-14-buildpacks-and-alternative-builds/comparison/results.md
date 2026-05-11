# Build Tool Comparison

| Tool | Dockerfile needed | Docker daemon needed | Size | CVEs | Reproducible | Best for |
|------|------------------|---------------------|------|------|--------------|---------|
| Dockerfile | Yes | Yes | Variable | Variable | No | Full control |
| Buildpacks (Paketo) | No | Yes | ~200MB | Few | Yes | Enterprise, Java/Node/Ruby |
| ko | No | No | ~10MB | ~0 | Yes | Go microservices |
| Jib | No | No | ~150MB | Few | Yes | Java/JVM apps |
| Nixpacks | No | Yes | Variable | Few | Partial | Heroku-like convenience |

## Size Comparison for the Ruby App
- Traditional Dockerfile: ~420MB
- Paketo Buildpack: ~220MB  
- Nixpacks: ~280MB

## Security Comparison
- Traditional: depends on your Dockerfile skills
- Paketo: automatically uses hardened base images, patched regularly
- ko: gcr.io/distroless base, ~0 CVEs
- Jib: configurable base image
