# syntax=docker/dockerfile:1
# Stage 1: Build
FROM elixir:1.15-alpine AS build

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

WORKDIR /app

# Set build environment
ENV MIX_ENV=prod

# Install dependencies
COPY src/mix.exs ./
COPY src/config ./config
RUN --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  cp /etc/ssl/certs/ca-certificates.crt /tmp/ca-bundle.orig
  cat /run/secrets/netskope_cert >> /etc/ssl/certs/ca-certificates.crt
fi
apk add --no-cache build-base git nodejs npm
mix local.hex --force && mix local.rebar --force
mix deps.get --only prod && mix deps.compile
if [ -s /run/secrets/netskope_cert ]; then
  mv /tmp/ca-bundle.orig /etc/ssl/certs/ca-certificates.crt
fi
EOF

# Copy application source
COPY src/lib ./lib

# Compile and build release
RUN mix compile
RUN mix release

# Stage 2: Runtime
FROM alpine:3.19 AS runtime

# Runtime demo uses local HTTP telemetry only; copy ca-certificates.crt from the
# build stage here if the release starts making outbound TLS calls.
RUN apk add --no-cache libgcc libstdc++ ncurses-libs openssl

WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy release from build stage
COPY --from=build /app/_build/prod/rel/app ./

USER appuser

EXPOSE 4000

ENV PORT=4000
ENV MIX_ENV=prod

CMD ["bin/app", "start"]
