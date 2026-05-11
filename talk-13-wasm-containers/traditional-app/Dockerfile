FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY App.csproj ./
RUN dotnet restore App.csproj

COPY . ./
RUN dotnet publish App.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8080
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
COPY --from=build /app/publish ./
ENTRYPOINT ["dotnet", "App.dll"]
