# syntax=docker/dockerfile:1.7

FROM golang:1.22-alpine AS build
WORKDIR /src

COPY go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api .

FROM gcr.io/distroless/static-debian12
WORKDIR /app
COPY --from=build /out/api /app/api

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/api"]
