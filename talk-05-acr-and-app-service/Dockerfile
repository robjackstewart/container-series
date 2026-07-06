# syntax=docker/dockerfile:1
# Stage 1: Build
FROM rust:1.75-slim AS builder

WORKDIR /app

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

# Install build dependencies and prime the dependency cache.
COPY Cargo.toml Cargo.lock* ./
RUN --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  cp /etc/ssl/certs/ca-certificates.crt /tmp/ca-bundle.orig
  cp /run/secrets/netskope_cert /usr/local/share/ca-certificates/netskope.crt 2>/dev/null || true
  update-ca-certificates 2>/dev/null || cat /run/secrets/netskope_cert >> /etc/ssl/certs/ca-certificates.crt
fi
apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
mkdir src && echo 'fn main() {}' > src/main.rs
cargo build --release
rm -f target/release/deps/rust_todo_api*
if [ -s /run/secrets/netskope_cert ]; then
  rm -f /usr/local/share/ca-certificates/netskope.crt
  mv /tmp/ca-bundle.orig /etc/ssl/certs/ca-certificates.crt
fi
EOF

# Copy actual source
COPY src ./src

# Build the real binary
RUN cargo build --release

# Stage 2: Runtime
FROM debian:bookworm-slim AS runtime

WORKDIR /app

# Install runtime dependencies. This API does not make outbound TLS calls during
# the demo; keep ca-certificates here for standard Debian TLS hygiene.
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