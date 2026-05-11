# Stage 1: Build
FROM rust:1.75-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Cache dependencies by copying manifests first
COPY Cargo.toml Cargo.lock* ./

# Create a dummy main.rs to build dependencies
RUN mkdir src && echo 'fn main() {}' > src/main.rs && \
    cargo build --release && \
    rm -f target/release/deps/rust_todo_api*

# Copy actual source
COPY src ./src

# Build the real binary
RUN cargo build --release

# Stage 2: Runtime
FROM debian:bookworm-slim AS runtime

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -r -u 1001 -g root appuser

# Copy binary from builder
COPY --from=builder /app/target/release/rust-todo-api .

USER appuser

EXPOSE 8080

ENV RUST_LOG=info
ENV PORT=8080
ENV ENVIRONMENT=production
ENV APP_VERSION=1.0.0

CMD ["./rust-todo-api"]