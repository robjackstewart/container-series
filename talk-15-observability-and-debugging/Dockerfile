# Stage 1: Build
FROM elixir:1.15-alpine AS build

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Default EXTRA_CERTS_DIR=certs points at an empty placeholder, so this is a NO-OP
# on a normal laptop and only activates when real .crt files are supplied in certs/.
# Pass real certs with:  docker build --build-arg EXTRA_CERTS_DIR=certs ...
ARG EXTRA_CERTS_DIR=certs
COPY ${EXTRA_CERTS_DIR}/ /usr/local/share/ca-certificates/extra/
RUN if ls -A /usr/local/share/ca-certificates/extra/ 2>/dev/null | grep -q .; then \
        if command -v update-ca-certificates >/dev/null 2>&1; then \
            update-ca-certificates; \
        else \
            cat /usr/local/share/ca-certificates/extra/*.crt >> /etc/ssl/certs/ca-certificates.crt; \
        fi; \
    fi
# -----------------------------------------------------------------------------

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm

WORKDIR /app

# Install Hex + Rebar
RUN mix local.hex --force && mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Install dependencies
COPY src/mix.exs ./
COPY src/config ./config
RUN mix deps.get --only prod && mix deps.compile

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
