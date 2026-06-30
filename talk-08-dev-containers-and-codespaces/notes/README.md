# Speaker Guide — Talk 08: Dev Containers and GitHub Codespaces

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with the common pain: every project quietly depends on a machine-shaped pile of tools, versions, extensions, and setup steps. Then show that Dev Containers make that environment explicit, repeatable, and reviewable in source control. The big idea is that a development environment can be treated like a product artefact: built, cached, opened locally, opened in Codespaces, and validated in CI.

## Section-by-section narrative
### 1) The "works on my machine" problem
- Frame the problem as environment drift rather than developer error. Python, Node, Go, database versions, editor extensions, and command-line tools all become hidden dependencies when they live only on laptops.
- Use the three projects as a progression: the Flask project shows a simple image-based setup, the TypeScript project shows a custom Dockerfile, and the full-stack Go project shows Compose for a realistic service dependency.
- Emphasise that the source repository now describes both the application and the development runtime needed to work on it.

> Expert aside: a dev container is still a container build. If the build pulls packages, installs Features, downloads language tooling, or runs package managers behind a TLS-intercepting proxy, the same corporate CA trust pattern matters as it does for production images.

### 2) `devcontainer.json` as the contract
- Explain `devcontainer.json` as the entry point the tooling reads. It names the environment, chooses an `image`, `build`, or `dockerComposeFile`, declares ports, sets lifecycle hooks, and configures VS Code.
- In `python-project`, the prebuilt Python image keeps the setup small. The value is clarity: runtime, extensions, forwarded port, and the post-create install are declared in one place.
- In `typescript-project`, the custom Dockerfile demonstrates when an image is worth owning: extra packages, a pinned Node path, shell behaviour, and tools such as `httpie`.
- Mention lifecycle hooks deliberately: `onCreateCommand` is for first creation, `postCreateCommand` is for dependency setup after the workspace is available, and `postStartCommand` is for work that should happen whenever the container starts.

> Expert aside: lifecycle hooks are convenient, but they should be fast and repeatable. A slow `postCreateCommand` is paid by every new developer and every Codespaces prebuild miss.

### 3) Features: reusable environment building blocks
- Introduce Features as the modular way to add common tools such as Docker-in-Docker, Git, Go, Node, and GitHub CLI without copying installer scripts into every repository.
- The Python and Go examples use Features to add tooling around the base environment; the TypeScript example combines a Dockerfile with Features to show that the approaches are not mutually exclusive.
- Reinforce the decision rule: use a Feature when the tool is generic and well-maintained; use a Dockerfile when the project has bespoke image needs.

> Expert aside: Dev Container Features are distributed as OCI artefacts. That means they can be versioned, resolved, cached, and governed using the same registry primitives as container images.

### 4) Multi-container dev containers with Compose
- Move to `fullstack-project` to show why single-container development is not always enough. A real API often needs a database, queue, cache, or emulator beside it.
- `docker-compose.yml` defines the Go API container and PostgreSQL service, while `devcontainer.json` tells VS Code which service is the development container.
- Call out the workspace mount and shared network: the API edits source from the repository but reaches the database by service name, just as containers do in other Compose setups.
- Keep the teaching point practical: Compose makes integration development local and repeatable without asking every developer to install PostgreSQL directly on the host.

### 5) GitHub Codespaces
- Position Codespaces as the same dev container contract running on managed GitHub compute. The repository configuration remains the source of truth; the machine moves from the laptop to the cloud.
- Cover the lifecycle: create, build or restore a prebuild, attach editor, forward ports, stop, resume, and delete.
- Explain secrets separately from configuration. Non-secret defaults can live in the repository; tokens and credentials belong in Codespaces secrets at user, repository, or organisation scope.
- Mention cost awareness without derailing the talk: right-size machines, stop idle environments, and avoid turning heavyweight setup into every start.

> Expert aside: Codespaces prebuilds cache the dev container image and setup work ahead of time. They do not remove the need for deterministic setup; they reward it by making new environments start quickly.

### 6) Dev Container CLI bonus
- Introduce the Dev Container CLI as the automation bridge. The same configuration that VS Code and Codespaces use can be built and executed by CI.
- The useful CI check is not "does the app compile on the runner"; it is "can a fresh development environment be built and does the project bootstrap inside it".
- Use this as the closing loop: if the environment is source-controlled, it can be reviewed, built, cached, and tested like any other important artefact.

## Discussion prompts (engage the room)
- Which tools in your current project are assumed to exist on every developer laptop but are not written down anywhere?
- When would you choose a prebuilt image, a Dockerfile, a Feature, or Docker Compose?
- What should run during container creation, and what should remain a manual developer action?
- Which dependencies would benefit most from a Codespaces prebuild in your team?
- What is the right policy for secrets in cloud development environments?

## Key takeaways (the close)
- Dev Containers make development environments explicit, repeatable, and reviewable.
- `devcontainer.json` is the contract; images, Dockerfiles, Features, and Compose are implementation choices behind it.
- Features are best for common reusable tooling; Dockerfiles are best for project-specific image customisation.
- Compose-backed dev containers make realistic multi-service development practical.
- Codespaces reuses the same configuration in the cloud, and prebuilds make that experience fast.
- The Dev Container CLI lets teams validate environment builds before they break onboarding.

## Bonus / niche corner
Use the Dev Container CLI to show that the configuration is not tied to the VS Code UI. In a CI pipeline, it can build the dev container, resolve Features, run setup hooks, and execute a smoke check inside the same kind of environment a developer opens locally. That makes environment drift visible before a new starter or a cloud codespace hits it.

## Netskope / corporate proxy note
This talk includes both image-based and Dockerfile-backed dev containers. The Python project uses a prebuilt dev container image and Features, so certificate trust mostly depends on the host, Codespaces, and Feature resolution path. The TypeScript and full-stack examples build Dockerfiles, so they include the `EXTRA_CERTS_DIR` pattern before network work such as `apt`, `curl`, `npm`, or `go mod download`.

The default `certs/` folders are empty, so the certificate step is a no-op on a normal laptop. Behind Netskope or another TLS-intercepting proxy, export the corporate root as PEM, rename it with a `.crt` extension if necessary, and place it in the cert folder that belongs to the relevant build context before rebuilding the dev container.
