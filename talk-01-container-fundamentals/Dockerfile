FROM mcr.microsoft.com/dotnet/sdk:8.0

# Set the working directory used for the rest of the build.
WORKDIR /workspace

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

# Copy the application source into the image.
# This is convenient for a first example, but it is not cache-friendly because
# even a small source change invalidates the restore layer.
COPY src/. ./src/

# Restore NuGet packages inside the container.
RUN dotnet restore "src/WeatherApi.csproj"

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
