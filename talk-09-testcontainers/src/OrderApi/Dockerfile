# syntax=docker/dockerfile:1.7

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

COPY src/OrderApi/OrderApi.csproj ./src/OrderApi/
RUN --mount=type=cache,target=/root/.nuget/packages \
    --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  cp /etc/ssl/certs/ca-certificates.crt /tmp/ca-bundle.orig
  cp /run/secrets/netskope_cert /usr/local/share/ca-certificates/netskope.crt 2>/dev/null || true
  update-ca-certificates 2>/dev/null || cat /run/secrets/netskope_cert >> /etc/ssl/certs/ca-certificates.crt
fi
dotnet restore "./src/OrderApi/OrderApi.csproj"
if [ -s /run/secrets/netskope_cert ]; then
  rm -f /usr/local/share/ca-certificates/netskope.crt
  mv /tmp/ca-bundle.orig /etc/ssl/certs/ca-certificates.crt
fi
EOF

COPY src/OrderApi/. ./src/OrderApi/
WORKDIR /src/src/OrderApi
RUN dotnet publish "OrderApi.csproj" -c Release -o /app/publish --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final

# Runtime makes no outbound TLS calls in this demo, so no extra corporate CA bundle is copied here.
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
USER app
ENTRYPOINT ["dotnet", "OrderApi.dll"]
