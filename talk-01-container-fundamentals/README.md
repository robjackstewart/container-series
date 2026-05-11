# Container Fundamentals — Building Your First Image

This talk introduces container fundamentals by building and packaging a small ASP.NET Core minimal API with .NET 8. The focus is on understanding *why* Dockerfiles work the way they do, how images are built, and how to make good decisions when moving from a first draft to a production-friendly image.

> Note: Windows containers exist and are useful for Windows-specific workloads (for example Windows Server Core and Nano Server), but this series focuses on **Linux containers** because they are the most common choice for modern application platforms.

## Prerequisites

- **Docker Desktop** installed and running
- **.NET 8 SDK** installed
- Optional but useful:
  - `curl` for testing endpoints
  - [`dive`](https://github.com/wagoodman/dive) for exploring image layers

## Project structure

```text
.
├── .dockerignore
├── Dockerfile
├── Dockerfile.multistage
├── README.md
├── bonus
│   ├── Dockerfile.scratch
│   └── hello.go
└── src
    ├── Program.cs
    └── WeatherApi.csproj
```

## Talk outline (~60 mins)

### 1) What are containers vs VMs
- A **virtual machine** packages a full guest operating system on top of a hypervisor.
- A **container** packages an application and its dependencies while sharing the host kernel.
- Linux containers rely on kernel features such as:
  - **Namespaces** for isolation (process, network, mount, PID, UTS, IPC, user)
  - **cgroups** for resource control (CPU, memory, IO)
- Containers are typically faster to start and smaller to distribute than VMs, but isolation boundaries are different because the kernel is shared.

### 2) Docker architecture
- **Docker client**: the `docker` CLI you type into
- **Docker daemon**: the background service that builds images and runs containers
- **Registry**: where images are stored and shared, such as Docker Hub or a private registry
- Common flow:
  1. You run `docker build`
  2. The client sends the build context to the daemon
  3. The daemon executes Dockerfile instructions and produces an image
  4. You run `docker run` to start a container from that image

### 3) Writing your first Dockerfile
We will cover the most important instructions:
- `FROM`: choose the base image
- `WORKDIR`: set the working directory inside the image
- `COPY`: bring files into the image
- `RUN`: execute commands during the image build
- `EXPOSE`: document the port the app listens on
- `CMD` vs `ENTRYPOINT`:
  - `ENTRYPOINT` defines the executable that always runs
  - `CMD` provides default arguments (or a default command if no entrypoint is set)

### 4) Understanding image layers and caching
- Each Dockerfile instruction usually creates a new layer
- If nothing affecting a layer changes, Docker can reuse the cached result
- Good Dockerfiles put **stable steps first** and **frequently changing steps later**
- Copying everything before `restore` usually hurts caching because any source code change invalidates dependency restore

### 5) Build arguments (`ARG`) vs environment variables (`ENV`)
- `ARG` exists at **build time** and is commonly used to parameterise the build
- `ENV` exists in the resulting image and is available at **runtime**
- A common pattern is to accept a build arg and promote it to an environment variable in the runtime image

### 6) Multi-stage builds
- Multi-stage builds separate **build tooling** from **runtime output**
- The SDK image is great for compiling, but the lighter ASP.NET runtime image is better for running the app
- Result: smaller images, reduced attack surface, faster pushes and pulls

### 7) BuildKit cache mounts
- BuildKit supports advanced features such as cache mounts
- For .NET, `--mount=type=cache,target=/root/.nuget/packages` speeds up repeated restores by preserving the NuGet package cache between builds
- This improves developer feedback without polluting the final runtime image

### 8) `.dockerignore`
- `.dockerignore` removes unnecessary files from the build context
- This speeds up builds and avoids copying local artifacts such as `bin`, `obj`, `.git`, `.vs`, test results, and editor files into the context

### 9) Basic Docker commands
- Build images
- Run containers
- View logs
- Inspect image history
- List and remove containers and images

## Commands used in the talk

### Run the API locally with .NET
```powershell
dotnet restore .\src\WeatherApi.csproj
dotnet run --project .\src\WeatherApi.csproj --urls http://localhost:5088
```
- `dotnet restore` downloads NuGet dependencies
- `dotnet run` builds and starts the API locally on a predictable port for the demo

Test the endpoints:
```powershell
curl http://localhost:5088/health
curl http://localhost:5088/info
curl http://localhost:5088/weatherforecast
```
- Swagger UI is available at `http://localhost:5088/swagger`

### Build the intentionally non-optimised image
```powershell
docker build -t weatherapi:single -f .\Dockerfile .
```
- Uses the single-stage Dockerfile
- Easy to understand, but includes the SDK and copies too much too early

### Run the single-stage image
```powershell
docker run --rm -p 8080:8080 weatherapi:single
```
- `--rm` cleans up the container when it exits
- `-p 8080:8080` maps host port 8080 to container port 8080

Test it:
```powershell
curl http://localhost:8080/health
curl http://localhost:8080/info
curl http://localhost:8080/weatherforecast
```

### Build the optimised multi-stage image
```powershell
docker build -t weatherapi:multi -f .\Dockerfile.multistage --build-arg APP_VERSION=1.0.0 .
```
- Uses separate build and runtime stages
- Passes `APP_VERSION` at build time
- Produces a smaller, cleaner image

### Run the multi-stage image with runtime configuration
```powershell
docker run --rm -p 8080:8080 -e ASPNETCORE_ENVIRONMENT=Production -e APP_VERSION=1.0.0 weatherapi:multi
```
- `ASPNETCORE_ENVIRONMENT` controls the ASP.NET Core environment name
- `APP_VERSION` is exposed by the `/info` endpoint

### Inspect images
```powershell
docker image ls
docker history weatherapi:single
docker history weatherapi:multi
```
- `docker image ls` lists local images
- `docker history` shows the layers that make up an image

### Inspect running containers
```powershell
docker ps
docker logs <container-id>
docker exec -it <container-id> sh
```
- `docker ps` lists running containers
- `docker logs` shows the application output
- `docker exec` opens a shell in the running container (works for images that contain a shell)

### Stop and clean up
```powershell
docker stop <container-id>
docker container prune
docker image prune
```
- `docker stop` stops a running container
- `docker container prune` removes stopped containers
- `docker image prune` removes dangling images

### BuildKit example
BuildKit is enabled by default in modern Docker Desktop versions. If needed, force it explicitly:
```powershell
$env:DOCKER_BUILDKIT=1
docker build -t weatherapi:multi -f .\Dockerfile.multistage --build-arg APP_VERSION=1.0.0 .
```
- Ensures Docker understands the `RUN --mount=type=cache` syntax

## Suggested live demo flow

1. Run the app locally with `dotnet run`
2. Open Swagger UI and call `/health`, `/info`, and `/weatherforecast`
3. Build the single-stage image and discuss why it works
4. Use `docker history` to explain layers
5. Rebuild after a small source change to show cache invalidation
6. Build the multi-stage image and compare size and layer history
7. Run the multi-stage image as a non-root user
8. Show `.dockerignore` and explain build context hygiene

## Single-stage vs multi-stage discussion points

### Single-stage Dockerfile
Pros:
- Simple and easy to explain
- Good for teaching first principles

Cons:
- Ships the SDK in the final image
- Larger attack surface
- Larger image size
- Poor caching because it copies everything before restore

### Multi-stage Dockerfile
Pros:
- Smaller runtime image
- Better cache reuse
- Clear separation of concerns
- Better security posture with a non-root runtime user

Cons:
- Slightly more complex to read at first

## Key takeaways

- Containers package an application plus its dependencies while sharing the host kernel
- Docker builds images as layers, so Dockerfile ordering matters
- `ARG` is for build time; `ENV` is for runtime
- `.dockerignore` is essential for clean, fast builds
- Multi-stage builds are the default choice for production-ready images
- Running as a non-root user is a simple but important improvement
- BuildKit cache mounts can make iterative builds much faster

## Bonus ideas

### Explore image layers with `dive`
```powershell
dive weatherapi:multi
```
Use `dive` to:
- See which files are added in each layer
- Compare wasted space between Dockerfile approaches
- Understand why layer ordering matters

### Build from `scratch`
See the files in `bonus\` for an example of the smallest practical container image:
- Build a static Go binary in one stage
- Copy only the binary into `FROM scratch`
- No package manager, no shell, no OS userland, just the application binary

Example:
```powershell
docker build -t hello-scratch -f .\bonus\Dockerfile.scratch .\bonus
docker run --rm hello-scratch
```

## Endpoints

- `GET /health` → returns a health payload
- `GET /info` → returns app name, version, and environment
- `GET /weatherforecast` → returns sample forecast data
- `GET /swagger` → Swagger UI

## Recommended talking points while coding

- Why `COPY . .` is convenient but often suboptimal
- Why `EXPOSE` is documentation, not port publishing
- Why containers are immutable artifacts and configuration belongs in environment variables
- Why container image size matters for CI/CD, startup, and security scanning

## Next step in the series

After understanding how to build a single service image, the next logical step is composing multiple containers together and managing configuration across environments.
