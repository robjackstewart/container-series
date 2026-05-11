# Testcontainers — Integration Testing with Real Dependencies

Talk 9 shows how to run integration tests against real infrastructure by spinning up disposable containers from your test code. Instead of mocking PostgreSQL, Redis, or RabbitMQ, your xUnit suite uses Testcontainers to provision the exact dependencies the application needs and tears them down automatically when the run completes.

## Prerequisites

- Talks 1-8 in this series
- Docker Desktop
- .NET 8 SDK

## Talk outline (~60 mins)

1. **Testing pyramid recap**  
   Where unit, integration, and end-to-end tests fit in a healthy delivery pipeline.
2. **The problem with mocks for infrastructure**  
   Why database, cache, and broker behavior is often too important to fake.
3. **Testcontainers overview: ephemeral containers in tests**  
   Spinning up dependencies on demand with isolated, repeatable test environments.
4. **Testcontainers.NET NuGet package setup**  
   Installing the core package and provider-specific packages for .NET 8/xUnit.
5. **Container lifecycle: per-test vs per-class vs per-assembly**  
   Trade-offs between isolation, runtime, and fixture complexity.
6. **PostgreSQL integration tests with EF Core**  
   Running migrations into a disposable database and asserting persistence behavior.
7. **Redis caching tests**  
   Verifying cache reads, writes, deletes, and expiration with a real Redis instance.
8. **RabbitMQ message broker tests**  
   Adding broker-backed tests without needing a shared dev environment.
9. **WebApplicationFactory + Testcontainers for full API tests**  
   Booting the full ASP.NET Core app against test infrastructure for realistic HTTP tests.
10. **Wait strategies**  
    Ensuring containers are actually ready before the test suite starts using them.
11. **CI considerations: Docker-in-Docker, socket mounting**  
    Running the same tests in GitHub Actions, Azure Pipelines, and other hosted runners.

## Key takeaways

- Integration tests become much more trustworthy when they use real dependencies.
- Testcontainers keeps that realism practical by provisioning disposable containers on demand.
- xUnit fixtures are a good fit for sharing expensive infrastructure across related tests.
- `WebApplicationFactory` and Testcontainers work well together for full-stack API verification.
- Wait strategies and predictable lifecycle management are essential for stable CI runs.

## Bonus topics

- **Testcontainers Desktop** for inspecting containers, logs, and lifecycle during local runs
- **Reusable containers** when you want faster feedback loops during development
- **Playwright integration** for browser tests that share the same disposable backing services

## Running the sample

```powershell
dotnet restore .\talk-09-testcontainers\OrderApi.sln
dotnet test .\talk-09-testcontainers\OrderApi.sln
```

Make sure Docker Desktop is running before you execute the tests.
