# RUNSHEET — Talk 02: Runtime Configuration

> One-page cue card. Keep it on your **private** screen; share the example folder + terminal.
> Behind Netskope? Drop your CA `.crt` into `certs/` first — every build trusts it automatically.

## Pre-flight (before you walk in)
- [ ] Docker Desktop running — `docker version`
- [ ] Bash-compatible shell available — `bash --version`
- [ ] Optional Podman installed — `podman --version`
- [ ] (if behind Netskope) corporate `.crt` copied into `certs/`
- [ ] Sample env file copied — `cp .env.example .env`
- [ ] Warm the caches — `docker pull python:3.12-slim; docker pull busybox:1.36`
- [ ] Terminal in `talk-02-runtime-configuration`, large font, speaker-guide closed

## Command sequence (copy-paste, in order)
```bash
# 1) Prepare local runtime configuration
cp .env.example .env

# 2) Build the Flask image with the optional cert hook and cache mount
DOCKER_BUILDKIT=1 docker build -t talk-02-runtime-config .

# 3) Run with inline environment variables
container_id=$(docker run -d --rm --name runtime-inline -p 8000:8000 -e DB_HOST=host.docker.internal -e DB_PORT=5432 -e DB_NAME=myapp -e DB_USER=myuser -e APP_SECRET_KEY=runtime-secret -e APP_ENV=development talk-02-runtime-config)
sleep 3
curl http://localhost:8000/health
curl http://localhost:8000/config
docker stop runtime-inline

# 4) Run with an env file and exercise the API
container_id=$(docker run -d --rm --name runtime-env-file -p 8000:8000 --env-file .env talk-02-runtime-config)
sleep 3
curl http://localhost:8000/items
curl -X POST http://localhost:8000/items -H 'Content-Type: application/json' -d '{"name":"demo item","description":"created during the talk"}'
docker stop runtime-env-file

# 5) Rebuild with a BuildKit build secret
DOCKER_BUILDKIT=1 docker build --secret id=mysecret,src=secret.txt -t talk-02-runtime-config .
docker history --no-trunc talk-02-runtime-config | head

# 6) Create a user-defined bridge and prove DNS resolution
docker network create mynetwork
docker run -d --rm --name runtime-api --network mynetwork --env-file .env -p 8000:8000 talk-02-runtime-config
docker run --rm --network mynetwork busybox:1.36 ping -c 1 runtime-api
docker stop runtime-api
docker network rm mynetwork

# 7) Show host networking and no-network modes as contrasts
docker run -d --rm --name host-network-demo --network=host --env-file .env talk-02-runtime-config
sleep 3
docker stop host-network-demo
docker run -d --rm --name no-network-demo --network=none --env-file .env talk-02-runtime-config
sleep 3
docker logs no-network-demo | tail -n 5
docker stop no-network-demo

# 8) Compare bind mount, named volume, and tmpfs storage
mkdir -p data
docker run --rm --env-file .env -v "$(pwd)/data:/app/data" talk-02-runtime-config python -c 'from pathlib import Path; Path("/app/data/bind.txt").write_text("bind mount")'
docker volume create mydata
docker run --rm --env-file .env -v mydata:/app/data talk-02-runtime-config python -c 'from pathlib import Path; Path("/app/data/volume.txt").write_text("named volume")'
docker run --rm --env-file .env --tmpfs /tmp:size=100m talk-02-runtime-config python -c 'from pathlib import Path; Path("/tmp/tmpfs.txt").write_text("tmpfs")'

# 9) Inspect image health check behaviour
docker run -d --name health-demo --env-file .env -p 8000:8000 talk-02-runtime-config
sleep 35
docker inspect --format='{{json .State.Health}}' health-demo
docker rm -f health-demo

# 10) Show restart policy and resource limits
docker run -d --name restart-demo --restart=unless-stopped --env-file .env talk-02-runtime-config
docker inspect --format='{{.HostConfig.RestartPolicy.Name}}' restart-demo
docker rm -f restart-demo
docker run --rm --env-file .env --memory=256m --cpus=0.5 talk-02-runtime-config python -c 'import os; print("limited container pid", os.getpid())'

# 11) Bonus: print Podman equivalents
bash bonus/podman-comparison.sh
```

## Beat-by-beat talking points
1. Copying `.env.example` creates realistic runtime input without committing real secrets.
2. The first build shows that the corporate CA hook is present but idle when `certs/` contains no real `.crt` files.
3. Inline `-e` flags make the runtime/image boundary obvious: the image is unchanged, the container instance is configured.
4. `--env-file` is the maintainable version for grouped settings, and the API proves secrets are configured without being echoed back.
5. BuildKit secrets are for build-time access only; the mount is ephemeral and should not appear in image history.
6. A user-defined bridge gives containers DNS names, which is why `runtime-api` resolves from BusyBox.
7. Host networking and `none` are deliberate boundary changes; call out Docker Desktop versus native Linux behaviour.
8. Bind mounts, volumes, and `tmpfs` demonstrate host-coupled, engine-managed, and memory-only storage lifecycles.
9. The health check makes readiness visible as container state, not just as a running PID.
10. Restart policy and limits show the basic operational controls available before moving to an orchestrator.
11. Podman keeps much of the CLI shape but changes the daemon and privilege model.

## If it breaks
- **Build can't pull / x509 / TLS error** → Netskope or corporate TLS interception is not trusted: copy the corporate root CA as a PEM `.crt` into `certs/`, then rebuild. Default `certs/` is empty = no-op.
- **`COPY certs/` fails** → ensure `certs/.gitkeep` exists and the build context is the talk folder.
- **Port already in use** → stop old demo containers: `docker rm -f runtime-inline runtime-env-file runtime-api no-network-demo health-demo host-network-demo restart-demo`.
- **`curl` is missing on Windows** → use Git Bash, WSL, or replace with `Invoke-RestMethod` in PowerShell.
- **Host networking behaves oddly** → explain that Docker Desktop runs containers inside a VM; native Linux host networking is the cleanest version of this demo.
- **`head` is missing** → skip the history truncation and run `docker history --no-trunc talk-02-runtime-config`.
- **Podman is unavailable** → skip the bonus script and explain the rootless/daemonless concepts from the speaker guide.

## Reset / cleanup
```bash
docker rm -f runtime-inline runtime-env-file runtime-api no-network-demo health-demo host-network-demo restart-demo 2>/dev/null || true
docker network rm mynetwork 2>/dev/null || true
docker volume rm mydata 2>/dev/null || true
rm -rf data .env
docker image rm talk-02-runtime-config 2>/dev/null || true
```

