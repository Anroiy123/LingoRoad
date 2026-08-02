FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
WORKDIR /src
COPY LingoRoad/LingoRoad.csproj LingoRoad/
RUN dotnet restore LingoRoad/LingoRoad.csproj
COPY LingoRoad/ LingoRoad/
RUN dotnet publish LingoRoad/LingoRoad.csproj -c Release -o /app/publish \
    --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS runtime
RUN apk add --no-cache curl
WORKDIR /app
COPY --from=build --chown=app:app /app/publish .
ENV ASPNETCORE_URLS=http://+:8080 \
    DOTNET_EnableDiagnostics=0
EXPOSE 8080
USER app
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:8080/ready || exit 1
ENTRYPOINT ["dotnet", "LingoRoad.dll"]
