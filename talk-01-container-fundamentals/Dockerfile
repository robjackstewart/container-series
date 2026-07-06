# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/dotnet/sdk:8.0

# Set the working directory used for the rest of the build.
WORKDIR /workspace

# --- Corporate CA trust (e.g. Netskope TLS interception) ---------------------
# Supply a corporate CA cert as a BuildKit secret — the cert is not stored in any image layer:
#   docker build --secret id=netskope_cert,src=certs/netskope.crt -t myapp .
# Omit --secret when not behind a proxy; the cert guard in each network RUN is a no-op.
# -----------------------------------------------------------------------------

# Copy the application source into the image.
# This is convenient for a first example, but it is not cache-friendly because
# even a small source change invalidates the restore layer.
COPY src/. ./src/

# Restore NuGet packages inside the container.
RUN --mount=type=secret,id=netskope_cert <<'EOF'
set -e
if [ -s /run/secrets/netskope_cert ]; then
  cp /etc/ssl/certs/ca-certificates.crt /tmp/ca-bundle.orig
  cp /run/secrets/netskope_cert /usr/local/share/ca-certificates/netskope.crt 2>/dev/null || true
  update-ca-certificates 2>/dev/null || cat /run/secrets/netskope_cert >> /etc/ssl/certs/ca-certificates.crt
fi
dotnet restore "src/WeatherApi.csproj"
if [ -s /run/secrets/netskope_cert ]; then
  rm -f /usr/local/share/ca-certificates/netskope.crt
  mv /tmp/ca-bundle.orig /etc/ssl/certs/ca-certificates.crt
fi
EOF

# Publish the application into a self-contained output folder.
# In a single-stage build the SDK, source code, and build tooling all remain in
# the final image, which is why this is intentionally shown as the "what not to do" example.
RUN dotnet publish "src/WeatherApi.csproj" -c Release -o /app/publish --no-restore /p:UseAppHost=false

# Configure Kestrel to listen on port 8080 inside the container.
ENV ASPNETCORE_URLS=http://+:8080

# Document the port the containerised app listens on.
EXPOSE 8080

# Use ENTRYPOINT so the container always launches the API process.
# CMD could be used to provide default arguments, but ENTRYPOINT is the better fit here.
ENTRYPOINT ["dotnet", "/app/publish/WeatherApi.dll"]
