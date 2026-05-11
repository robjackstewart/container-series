# Stage 1: Build
FROM elixir:1.15-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git nodejs npm

WORKDIR /app

# Install Hex + Rebar
RUN mix local.hex --force && mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Install dependencies
COPY src/mix.exs src/mix.lock* ./
COPY src/config ./config
RUN mix deps.get --only prod && mix deps.compile

# Copy application source
COPY src/lib ./lib

# Compile and build release
RUN mix compile
RUN mix release

# Stage 2: Runtime
FROM alpine:3.19 AS runtime

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