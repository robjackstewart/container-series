FROM rust:1.75-slim AS builder

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends pkg-config libssl-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml ./
RUN mkdir src \
    && printf 'fn main() {}\n' > src/main.rs \
    && cargo build --release \
    && rm -rf src

COPY src ./src
RUN cargo build --release && strip target/release/acr-app-service-todo-api

FROM debian:bookworm-slim

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libssl3 \
    && useradd -r -u 1001 appuser \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/acr-app-service-todo-api /usr/local/bin/app

USER appuser
EXPOSE 8080
CMD ["/usr/local/bin/app"]
