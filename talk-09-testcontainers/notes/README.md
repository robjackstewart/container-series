# Speaker Guide — Talk 09: Testcontainers

> The teaching narrative. Keep this on your private screen or printed; share the code/terminal.
> For the exact commands, use `../RUNSHEET.md`.

## The arc
Start with the familiar pain: integration tests are either fast and fake, or realistic and awkward because they rely on a shared database, cache, or broker. Testcontainers changes that trade-off by letting the test process ask Docker for short-lived dependencies with known image versions and isolated state. The big idea is that the test suite owns its infrastructure boundary: it starts the real dependency, waits until it is ready, injects the connection details into the app, and cleans up afterwards.

## Section-by-section narrative
### 1) Why mocks are not enough for infrastructure
- Position mocks as useful for domain logic but weak for infrastructure behaviour. A mock will not catch PostgreSQL type mapping, transaction behaviour, Redis serialisation quirks, cache expiry, broker acknowledgement semantics, or the way an application behaves during real network start-up.
- The sample keeps the domain deliberately small: an order API with persistence and caching. That lets the audience focus on the testing boundary rather than business logic.
- Land the message that Testcontainers is not a replacement for unit tests. It fills the gap where correctness depends on an external system behaving like the real external system.

> Expert aside: the highest-value integration tests are usually contract tests against infrastructure behaviour, not broad happy-path replays of the whole application. Testcontainers gives those tests realism without requiring a long-lived shared environment.

### 2) The Testcontainers.NET mental model
- In .NET, the test project references provider packages such as PostgreSQL, Redis, and RabbitMQ. Those providers wrap common container configuration so tests can ask for a database, cache, or broker with sensible defaults.
- The fixture creates a container object, starts it asynchronously, reads its generated connection string, and disposes it at the end of the fixture lifetime.
- Emphasise that the host port is intentionally dynamic. Tests should consume the connection string supplied by Testcontainers rather than hard-coding local ports.

> Expert aside: Testcontainers talks to the Docker API through the Docker socket or named pipe. If Docker is not running, the socket is not mounted in CI, or the test process cannot access it, the tests fail before application code is involved.

### 3) PostgreSQL: realistic persistence without a shared database
- Use `PostgresFixture` as the simple fixture story. It starts `postgres:16-alpine`, applies EF Core migrations, then gives each database test a real Npgsql connection string.
- Make the value concrete: EF Core model configuration, migrations, decimal precision, GUID persistence, and delete behaviour are all exercised against the database engine the service expects.
- Call out isolation. This sample uses class-level fixture lifetime to avoid starting a new database for every assertion, while test data uses unique values so tests do not depend on order.

### 4) Redis: cache behaviour that mocks often hide
- Use `RedisFixture` and the cache tests to show why a real cache matters. Serialisation, key shape, TTL expiry, and deletion behaviour are all observable through the same `IDistributedCache` stack used by the app.
- Highlight the TTL test as a teaching moment: it is intentionally simple, but in production suites you should avoid long sleeps and design expiry tests so they remain stable under CI load.
- Explain that cache-backed tests often expose assumptions about time, eventual consistency, and serialisation options earlier than local manual testing.

### 5) RabbitMQ: the broker pattern
- The test project includes the RabbitMQ provider so the speaker can describe the same pattern for messaging: start a broker container, wait until it accepts AMQP connections, publish a message, consume it, and assert acknowledgement or retry behaviour.
- Be clear that the executable sample focuses on PostgreSQL and Redis because the order API does not currently publish messages. RabbitMQ is the natural extension when the service gains asynchronous workflows such as order-created events.
- Stress what a fake broker usually misses: durable queues, exchanges, routing keys, consumer acknowledgements, dead lettering, and connection recovery.

### 6) WebApplicationFactory plus Testcontainers
- `CustomWebApplicationFactory` is the full-stack bridge. It starts PostgreSQL and Redis, overrides the app's connection strings, boots the ASP.NET Core app in the `Testing` environment, and runs migrations before HTTP tests execute.
- This lets the API tests use `HttpClient` against the real ASP.NET Core pipeline while still avoiding a shared database or cache.
- The key teaching point is ownership of configuration. The app does not know it is using containers; it only receives connection strings from normal configuration providers.

> Expert aside: `WebApplicationFactory` and Testcontainers work best when app start-up does not hide irreversible side effects. Keep configuration injectable, make migrations explicit, and avoid static connection state that survives between test runs.

### 7) Wait strategies and flaky tests
- A started container is not necessarily a ready service. Docker may report the process as running before PostgreSQL accepts connections, Redis responds, or RabbitMQ finishes booting plugins.
- Provider modules include sensible defaults, but complex services often need explicit waits for listening ports, log messages, health checks, or application-specific readiness.
- Frame wait strategies as a reliability control, not ceremony. Random sleeps make tests slow and still flaky; a readiness condition makes the suite deterministic.

> Expert aside: most Testcontainers flakiness blamed on Docker is actually readiness flakiness. Replace sleeps with the narrowest wait condition that proves the dependency can satisfy the test's first real operation.

### 8) Lifecycle choices: per-test, per-class, per-assembly
- Per-test containers give excellent isolation but cost the most time, especially when images must be pulled or databases migrated repeatedly.
- Per-class fixtures, as used here, are a pragmatic middle ground: one dependency stack for a coherent group of tests, with test data kept independent.
- Per-assembly or collection-level containers can speed large suites, but the shared state needs stricter cleanup discipline and parallelisation rules.
- Encourage the audience to choose lifecycle intentionally: the default should be the smallest scope that gives reliable isolation at an acceptable feedback speed.

### 9) Cleanup, Ryuk, and what happens after a crash
- Testcontainers labels the resources it creates and uses a resource reaper, commonly known as Ryuk, to clean up containers, networks, and volumes even when the test process exits unexpectedly.
- This is why the demo can show containers appear during `dotnet test` and disappear afterwards without manual teardown.
- Warn against disabling cleanup casually. A laptop full of stale test databases is confusing, and a CI worker with orphaned containers eventually becomes unreliable.

> Expert aside: Ryuk itself is a container with Docker API access. Some locked-down CI environments block that pattern; if so, you need an explicit cleanup strategy rather than simply switching the reaper off and hoping workers are always disposable.

### 10) CI and Testcontainers Cloud
- The CI requirement is simple to state but easy to miss: the job must have Docker available to the test process. That can be Docker on the host, a mounted Docker socket, Docker-in-Docker, or a platform-specific service container setup.
- Testcontainers Cloud moves container execution away from the developer machine or CI worker. It is useful when hosted agents are slow, Docker is restricted, or teams want more consistent remote execution.
- Keep the security message balanced: the agent and token are part of the test infrastructure, so treat them as CI secrets and understand what network paths the containers need.

## Discussion prompts (engage the room)
- Which tests in your current systems are too important to trust to mocks, but too awkward to run against shared infrastructure?
- Where would per-test isolation be worth the cost, and where would class-level fixtures be enough?
- What readiness signal would prove your database, cache, or broker is genuinely ready for the first assertion?
- How does your CI currently expose Docker to test jobs, and who owns cleanup when a run is cancelled?
- Which failures should be caught by Testcontainers tests, and which still belong in full end-to-end environments?

## Key takeaways (the close)
- Testcontainers makes integration tests realistic by provisioning real dependencies on demand.
- xUnit fixture lifetime is an architectural choice: it trades isolation, speed, and state-management complexity.
- `WebApplicationFactory` keeps the application path realistic while letting tests inject container connection strings through normal configuration.
- Wait strategies are the difference between a reliable suite and a suite that only passes on a warm laptop.
- CI needs Docker socket access or a cloud execution path; Testcontainers is not magic if the test process cannot talk to Docker.
- Cleanup is part of the design, not an afterthought.

## Bonus / niche corner
Testcontainers Desktop is useful during the demo because it makes the invisible lifecycle visible: you can inspect containers, ports, logs, and cleanup while the tests run. Use it as a teaching aid, not as a dependency the test suite requires.

Reusable containers are a local-feedback optimisation. They require explicit opt-in through a user-level `testcontainers.reuse.enable=true` setting and matching code-level reuse configuration. They can make repeated local runs much faster, but they weaken isolation and should stay out of CI unless the whole team has deliberately designed for shared state.

The Playwright E2E extension is powerful when a service has a browser surface. Start the real backing services with Testcontainers, boot the app against those connection strings, then let Playwright drive the UI or API boundary. The payoff is an end-to-end test that still owns its dependencies rather than relying on a shared environment.

## Netskope / corporate proxy note
This talk has two certificate paths. The API Dockerfile trusts optional corporate CA certificates from `certs/` before `dotnet restore`, so image builds can reach NuGet through a TLS-intercepting proxy. The ASP.NET Core runtime stage does not make outbound TLS calls during this demo, so it only carries a comment rather than an extra CA bundle.

Testcontainers itself pulls images such as `postgres:16-alpine`, `redis:7-alpine`, and optional `rabbitmq:3-management-alpine` at test time. Those pulls are performed by the Docker daemon or remote container runtime, not by the API Dockerfile. Behind Netskope, Docker Desktop or the Docker host must trust the corporate root CA at host level for registry pulls; dropping a certificate into `certs/` only helps Docker builds that copy it into an image stage. Certificates should be PEM-encoded `.crt` files; if the proxy exports `.pem`, rename it to `.crt` after confirming it is PEM text.
