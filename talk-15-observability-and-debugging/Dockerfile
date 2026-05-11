FROM elixir:1.15-alpine AS build

RUN apk add --no-cache build-base git

ENV MIX_ENV=prod
WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY src/mix.exs ./mix.exs
COPY src/config ./config
RUN mix deps.get --only prod
RUN mix deps.compile

COPY src/lib ./lib
RUN mix compile && mix release

FROM alpine:3.19

RUN apk add --no-cache libgcc libstdc++ openssl ncurses-libs

WORKDIR /app
RUN addgroup -S app && adduser -S app -G app

COPY --from=build --chown=app:app /app/_build/prod/rel/app ./

USER app
EXPOSE 4000
CMD ["bin/app", "start"]
