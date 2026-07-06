# syntax=docker/dockerfile:1.7

FROM golang:1.22-alpine AS build
WORKDIR /src

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

COPY api/go.mod ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  cp /etc/ssl/certs/ca-certificates.crt /tmp/ca-bundle.orig
  cp /run/secrets/netskope_cert /usr/local/share/ca-certificates/netskope.crt 2>/dev/null || true
  update-ca-certificates 2>/dev/null || cat /run/secrets/netskope_cert >> /etc/ssl/certs/ca-certificates.crt
fi
go mod download
if [ -s /run/secrets/netskope_cert ]; then
  rm -f /usr/local/share/ca-certificates/netskope.crt
  mv /tmp/ca-bundle.orig /etc/ssl/certs/ca-certificates.crt
fi
EOF

COPY api/. .
RUN --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api .

FROM gcr.io/distroless/static-debian12
WORKDIR /app
COPY --from=build /out/api /app/api
# This shell-less runtime does not copy a CA bundle because the demo app makes no outbound TLS calls.

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app/api"]
