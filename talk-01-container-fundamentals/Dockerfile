FROM mcr.microsoft.com/dotnet/sdk:8.0

# Set the working directory used for the rest of the build.
WORKDIR /workspace

# Copy the entire project into the image.
# This is convenient for a first example, but it is not cache-friendly because
# even a small source change invalidates the restore layer.
COPY . .

# Restore NuGet packages inside the container.
RUN dotnet restore "src/WeatherApi.csproj"

# Publish the application into a self-contained output folder.
# In a single-stage build the SDK, source code, and build tooling all remain in
# the final image, which is why this is intentionally shown as the "what not to do" example.
RUN dotnet publish "src/WeatherApi.csproj" -c Release -o /app/publish --no-restore /p:UseAppHost=false

# Configure Kestrel to listen on port 8080 inside the container.
ENV ASPNETCORE_URLS=http://+:8080

# Document the port the containerized app listens on.
EXPOSE 8080

# Use ENTRYPOINT so the container always launches the API process.
# CMD could be used to provide default arguments, but ENTRYPOINT is the better fit here.
ENTRYPOINT ["dotnet", "/app/publish/WeatherApi.dll"]
