# .NET Aspire — Cloud-Native Orchestration for Development

Talk 10 in the container series introduces **.NET Aspire** as a developer-focused orchestration layer for cloud-native apps. We'll build a small distributed system that combines APIs, workers, data services, messaging, a Blazor front end, and the Aspire dashboard.

## Prerequisites

- Completion of Talks 1-9 in this series
- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Aspire workload installed:

```powershell
dotnet workload install aspire
```

## Talk outline (~60 mins)

1. **Aspire overview and motivation**  
   Why Aspire exists, what problems it solves, and why it improves the local inner loop for distributed applications.
2. **Aspire vs Docker Compose: when to use which**  
   Compare developer experience, service discovery, diagnostics, and container orchestration responsibilities.
3. **AppHost project: `AddProject`, `AddContainer`, service references**  
   Use the AppHost as the orchestration entry point for local environments.
4. **Service discovery: automatic endpoint injection**  
   See how referenced services are resolved without hardcoding ports.
5. **Aspire Dashboard: logs, traces, metrics**  
   Explore observability built into the developer workflow.
6. **Aspire integrations: PostgreSQL, Redis, RabbitMQ**  
   Add common infrastructure with strongly-typed resource definitions.
7. **Building our demo: API + OrderService + NotificationService + Blazor + PostgreSQL + Redis + RabbitMQ**  
   Assemble a realistic cloud-native sample end to end.
8. **`AddDockerfile` for custom containers**  
   Show how Aspire can orchestrate custom-built containers alongside projects.
9. **Deployment with `azd`**  
   Discuss the path from local Aspire development to Azure deployment.

## Demo architecture

This talk creates the following app graph:

- **AppHost**: Aspire orchestration entry point
- **API**: lightweight gateway for order requests and Redis cache demo
- **OrderService**: persists orders to PostgreSQL and publishes RabbitMQ events
- **NotificationService**: worker that consumes order-created messages
- **Web**: Blazor front end that calls the API
- **PostgreSQL**: order storage
- **Redis**: distributed cache demo
- **RabbitMQ**: event transport between services

## Running the demo

From the `talk-10-dotnet-aspire` folder:

```powershell
dotnet restore

dotnet run --project .\ContainerSeries.AppHost\ContainerSeries.AppHost.csproj
```

When the AppHost starts, Aspire will:

- provision PostgreSQL, Redis, and RabbitMQ containers
- start the API, order service, notification worker, and Blazor app
- wire up service discovery and connection strings automatically
- open the Aspire dashboard so you can inspect logs, traces, and metrics

## Suggested walkthrough flow

- Start with the `ContainerSeries.AppHost` project and explain the distributed graph
- Show how `.WithReference(...)` drives service discovery and configuration
- Create orders from the API or Blazor front end
- Inspect PostgreSQL data, Redis cache behavior, and RabbitMQ events
- Watch logs and traces in the Aspire dashboard
- Discuss how the same services could be composed with Docker Compose and where Aspire adds value

## Aspire vs Docker Compose

Use **Docker Compose** when you primarily need to start containers and wire ports, volumes, and environment variables. It is a great fit for infrastructure-heavy or polyglot environments.

Use **.NET Aspire** when the development experience of a distributed application matters most:

- first-class .NET project orchestration
- built-in service discovery
- integrated observability dashboard
- strongly-typed infrastructure integrations
- easier local composition of apps, workers, and supporting services

They are complementary, not mutually exclusive.

## Key takeaways

- Aspire improves the local development story for distributed .NET apps
- The AppHost becomes a single orchestration entry point for projects and containers
- Service references replace a lot of manual endpoint configuration
- The Aspire dashboard makes distributed debugging far easier
- Integrations for PostgreSQL, Redis, and RabbitMQ reduce boilerplate
- Aspire helps bridge local orchestration and cloud deployment workflows

## Bonus: Aspire + Ollama local AI

A fun extension for this talk is to add **Ollama** as another Aspire-managed container and wire an internal AI helper into the system. That lets you demonstrate:

- local LLM inference without cloud dependency
- service discovery for AI endpoints
- blended application architecture with APIs, workers, data stores, and AI services

That makes Aspire a compelling platform for modern, AI-enabled cloud-native development.
