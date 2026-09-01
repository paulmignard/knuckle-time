FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src

# Copy csproj and restore
COPY KnuckleAuth.csproj ./
RUN dotnet restore KnuckleAuth.csproj

# Copy everything else and build
COPY . ./
RUN dotnet publish KnuckleAuth.csproj -c Release -o /app

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:10.0-preview AS runtime
WORKDIR /app
COPY --from=build /app ./

# Railway uses PORT env var
ENV ASPNETCORE_URLS=http://+:${PORT:-8080}

ENTRYPOINT ["dotnet", "KnuckleAuth.dll"]
