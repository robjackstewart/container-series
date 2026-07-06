# Speaker Guide — Talk 10: .NET Aspire Cloud-Native Orchestration

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with the pain of running a distributed application locally: several .NET processes, backing services, ports, connection strings, and diagnostics all drift apart. Then introduce .NET Aspire as the AppHost-centred composition model that starts the whole graph, wires dependencies, and gives the developer an observability surface by default. The big idea is that Aspire is not a replacement for containers; it is a developer orchestration layer that uses containers where they are useful and keeps the .NET inner loop first-class.

## Section-by-section narrative
### 1) Why Aspire exists
- Open by naming the local-development problem: modern apps are rarely one process, but most developer workflows still assume one project and one terminal.
- Position Aspire as the local control plane for a distributed .NET application. It starts projects, creates backing resources, injects configuration, and gives the presenter a single dashboard rather than five unrelated consoles.
- Emphasise that the talk deliberately has no Dockerfile. The container story is dependency orchestration through the host Docker engine, not image authoring.

> Expert aside: the Aspire AppHost is driven by the Distributed Control Plane model. It is not just a prettier `docker compose` file; it builds a resource graph that tooling can inspect, launch, observe, and later translate into deployment assets.

### 2) AppHost orchestration model
- Use `ContainerSeries.AppHost` as the map of the system. `AddPostgres`, `AddRedis`, and `AddRabbitMQ` describe infrastructure resources; `AddProject` describes the .NET services and web front end.
- Explain the dependency edges rather than reading code line by line: OrderService depends on PostgreSQL and RabbitMQ; NotificationService depends on RabbitMQ; API depends on OrderService and Redis; Web depends on API.
- Call out the extra local tools: pgAdmin for PostgreSQL, RedisInsight for Redis, and the RabbitMQ management plug-in give visible backing-service demonstrations without hand-rolled scripts.

> Expert aside: Aspire spins up Redis, PostgreSQL, RabbitMQ, and their companion tools through the host Docker daemon. That means image pulls, local volumes, and daemon trust settings are host concerns, even though the application projects are launched by .NET tooling.

### 3) Service discovery and configuration
- Show that the API talks to `http://orderservice` and the Web app talks to `http://api`; those names are resolved by Aspire service discovery, not by hard-coded localhost ports.
- Connection strings for `orderdb`, `redis`, and `rabbitmq` come from resource references in the AppHost. The application projects ask configuration for named resources rather than knowing container names, passwords, or host ports.
- Land the practical benefit: developers can add or reorder services without chasing port numbers through appsettings files.

### 4) ServiceDefaults: observability, health, and resilience
- Use `ContainerSeries.ServiceDefaults` as the shared platform slice. It wires OpenTelemetry, health endpoints, service discovery, and standard HTTP client resilience in one place.
- Explain that each service opting into `AddServiceDefaults` gets consistent `/health` and `/alive` endpoints, telemetry enrichment, and resilient outbound HTTP behaviour.
- Highlight that this is production-shaped discipline, even though the demo is local: observability and health are part of the app shape from day one.

> Expert aside: `ServiceDefaults` is where Aspire samples hide a lot of valuable engineering. It is not magic; it is ordinary .NET dependency injection for OpenTelemetry, health checks, service discovery, and resilience policies, centralised so every service behaves consistently.

### 5) Aspire Dashboard: traces, metrics, logs, and endpoints
- Open the Aspire Dashboard once the AppHost starts and treat it as the main teaching surface.
- Start with the Resources view: every project and container-backed resource is visible, with endpoints and lifecycle state in one place.
- Move to logs for a single service, then traces for a request that goes Web to API to OrderService, and metrics for runtime and HTTP activity.
- Create an order and show the log trail across OrderService and NotificationService. The audience should see distributed behaviour without needing a separate observability stack.

### 6) Integrations: Redis, PostgreSQL, and RabbitMQ
- PostgreSQL stores orders and gives a concrete reason for a stateful dependency. The AppHost-owned data volume keeps local data across restarts until the presenter chooses to clean it up.
- Redis supports the API cache demonstration, which is a fast way to show a container-backed dependency with visible behaviour changes.
- RabbitMQ connects OrderService and NotificationService so the room sees a small event-driven slice, not just synchronous HTTP.
- Keep the point high-level: Aspire integrations reduce ceremony around connection strings, containers, management tools, and dashboard visibility.

### 7) Optional deployment with `azd`
- Treat `azd` as a bridge from local Aspire composition to Azure deployment assets, not as the core of the talk.
- Explain that `azd init` can inspect an Aspire application and generate the deployment scaffold, then `azd up` provisions and deploys the application.
- For a container-focused audience, call out Azure Container Apps as the natural managed-container target for this style of workload.

> Expert aside: the interesting part of the Aspire and `azd` path is not that it runs a command; it is that the local resource graph can be converted into infrastructure definitions such as Bicep and deployed to managed container infrastructure like Azure Container Apps.

### 8) Bonus: Aspire and Ollama local AI
- Present Ollama as a fun extension: another local dependency that can be started and reached through the same orchestration model.
- The teaching angle is that AI does not need to be a special snowflake in the developer workflow. It can be another service endpoint with health, logs, and configuration like Redis or RabbitMQ.
- Keep it as a bonus unless the room is AI-focused. The main talk is orchestration and observability; the AI hook is there to show the model scales to newer workloads.

## Discussion prompts (engage the room)
- Where does your current local setup rely on tribal knowledge about ports, passwords, or startup order?
- Which dependencies should be containerised for local development, and which should stay as managed shared services?
- When is Docker Compose still the simpler choice, and when does Aspire's .NET-aware service discovery and dashboard become worth it?
- What telemetry would you want to see before trusting a distributed local demo in CI or a shared test environment?

## Key takeaways (the close)
- Aspire gives a .NET distributed application one local entry point: the AppHost.
- The AppHost describes a resource graph, not a Dockerfile; dependency containers are run by the host Docker daemon.
- Service discovery and resource references remove most hard-coded local ports and connection strings.
- `ServiceDefaults` makes OpenTelemetry, health checks, discovery, and resilience consistent across services.
- The Aspire Dashboard turns traces, metrics, logs, endpoints, and health into part of the everyday developer loop.
- `azd` can turn the Aspire shape into cloud deployment assets when the team is ready.

## Bonus / niche corner
If time allows, show the system as a template for AI-enabled apps. An Ollama-backed helper can sit beside the API, worker, and backing stores as another locally orchestrated dependency. The value is not the model itself; it is that the same service-discovery, dashboard, and configuration habits apply to a local LLM as they do to Redis or PostgreSQL.

## Netskope / corporate proxy note
This talk follows the non-Dockerfile workaround. There is no Dockerfile to edit or BuildKit secret to pass. Aspire launches .NET projects directly and asks the host Docker daemon to pull and run dependency images such as Redis, PostgreSQL, RabbitMQ, pgAdmin, RedisInsight, and the RabbitMQ management image.

Because those pulls happen through the host Docker engine, the corporate CA must be trusted by the host operating system and by Docker Desktop or the Docker daemon. Putting a certificate only in this talk's `certs/` folder will not affect those pulls. Behind Netskope or another TLS-intercepting proxy, install the corporate root CA into the OS trust store, ensure Docker Desktop trusts the same CA, and restart Docker if necessary.

For .NET HTTP calls made by the local projects, prefer trusting the OS certificate store. If a tool or process needs an explicit bundle, set `SSL_CERT_FILE` to a PEM bundle that includes the corporate CA. If a Node-based helper is introduced later, `NODE_EXTRA_CA_CERTS` can point at the same corporate CA. If this talk later adds a Dockerfile-built image, pass the cert via `--secret id=netskope_cert,src=certs/netskope.crt` to the stage that performs network I/O.
