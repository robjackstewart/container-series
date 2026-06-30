# RUNSHEET — Talk 14: Buildpacks and Alternative Builds

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Prepare host trust for the non-Dockerfile builders; the comparison Dockerfile uses `ruby-app/certs/` because its build context is `ruby-app/`.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] `pack` installed — `pack --version`
- [ ] `ko` installed — `ko version`
- [ ] Go, Java, Maven, Node.js, npm, and Nixpacks installed — `go version`, `java -version`, `mvn --version`, `node --version`, `npm --version`, `nixpacks --version`
- [ ] Optional endpoint checker installed — `curl --version`
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/` for the talk notes and into `ruby-app/certs/` for the comparison Dockerfile build
- [ ] Warm the caches — `docker pull paketobuildpacks/builder-jammy-base:latest; docker pull ruby:3.3-slim`
- [ ] Terminal in `talk-14-buildpacks-and-alternative-builds`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Build the Ruby/Sinatra app with Cloud Native Buildpacks
pack build ruby-sinatra-pack --path ./ruby-app --builder paketobuildpacks/builder-jammy-base:latest --env PORT=4567
docker run --rm -d --name ruby-pack -p 4567:4567 -e PORT=4567 ruby-sinatra-pack
curl http://localhost:4567/health
docker stop ruby-pack

# 2) Inspect the buildpack image and show the rebase bonus
pack inspect-image ruby-sinatra-pack
pack rebase ruby-sinatra-pack || true

# 3) Build the Go service with ko
goImage=$(cd go-app && ko build --local .)
docker run --rm -d --name go-ko -p 8080:8080 "$goImage"
curl http://localhost:8080/health
docker stop go-ko

# 4) Build the Java service with Jib
(cd java-app && mvn -q compile jib:dockerBuild -Dimage=java-jib-app)
docker run --rm -d --name java-jib -p 8081:8080 java-jib-app
curl http://localhost:8081/health
docker stop java-jib

# 5) Build the Node service with Nixpacks
nixpacks build ./node-app --name node-nixpacks
docker run --rm -d --name node-nixpacks -p 3000:3000 -e PORT=3000 node-nixpacks
curl http://localhost:3000/health
docker stop node-nixpacks

# 6) Build the Ruby/Sinatra comparison image with the Dockerfile
docker build -f comparison/Dockerfile.ruby -t ruby-sinatra-dockerfile ruby-app
docker run --rm -d --name ruby-dockerfile -p 4568:4567 -e PORT=4567 ruby-sinatra-dockerfile
curl http://localhost:4568/health
docker stop ruby-dockerfile

# 7) Compare outputs, layers, and build-tool metadata
docker images | grep -E 'ruby-sinatra|ko.local|java-jib|node-nixpacks'
docker history ruby-sinatra-dockerfile
pack inspect-image ruby-sinatra-pack
nixpacks plan ./node-app
(cd java-app && mvn -q compile jib:_skaffold-files-v2)
```

## Beat-by-beat talking points
1. Buildpacks detect Ruby from the app shape and apply a builder's policy without a Dockerfile.
2. Rebase is the operations story: patch the run image layers without reinstalling application dependencies.
3. `ko` shows the Go-specific path: source to small image with minimal ceremony and no maintained Dockerfile.
4. Jib shows ecosystem-native image creation: Maven already knows the dependency and class structure, so the image can be layered intelligently.
5. Nixpacks shows the Heroku-like developer experience for broad language detection and fast onboarding.
6. The Dockerfile comparison proves the trade-off: maximum control, but every hardening and certificate pattern must be maintained by hand.
7. The comparison commands make daemon requirements, cache shape, image size, and metadata differences visible.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted. For `pack`, trust the host and use `--volume hostcerts:/etc/ssl/certs/extra:ro`, or set `SSL_CERT_FILE` / relevant `BP_*` environment. For `ko`, set host trust or `SSL_CERT_FILE`. For Jib, configure the JVM trust store with `-Djavax.net.ssl.trustStore`. For Nixpacks, fix host trust. For the comparison Dockerfile, put PEM `.crt` files in `ruby-app/certs/`.
- **`COPY certs/` fails in the Dockerfile build** → keep the build context as `ruby-app` and ensure `ruby-app/certs/.gitkeep` exists; the talk-root `certs/` folder is not inside that Docker build context.
- **Port already in use** → change the host side of the mapping, for example `4569:4567`, `8082:8080`, or `3001:3000`.
- **`ko` tries to push instead of loading locally** → keep `--local` for the live demo, or set `KO_DOCKER_REPO` to a registry you can push to.
- **Jib cannot find Docker** → use `jib:build` with a real registry target, or skip the run step and discuss daemonless CI builds.
- **Nixpacks is missing or slow on first build** → show `nixpacks plan ./node-app` and explain the generated build plan instead.

## Reset / cleanup
```bash
docker rm -f ruby-pack go-ko java-jib node-nixpacks ruby-dockerfile 2>/dev/null || true
docker rmi ruby-sinatra-pack ruby-sinatra-dockerfile java-jib-app node-nixpacks 2>/dev/null || true
docker images | grep 'ko.local' | awk '{print $3}' | xargs -r docker rmi 2>/dev/null || true
rm -rf sbom-output
```
