# ============================================
# Stage 1: Base - SDK for building and testing
# ============================================
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS base
WORKDIR /app

# Copy solution and project files for dependency restoration
COPY *.sln .
COPY src/*/*.csproj ./
RUN for file in $(ls *.csproj); do mkdir -p src/${file%.*}/ && mv $file src/${file%.*}/; done

COPY test/*/*.csproj ./
RUN for file in $(ls *.csproj); do mkdir -p test/${file%.*}/ && mv $file test/${file%.*}/; done

# Restore dependencies
RUN dotnet restore IdentityService.sln

# ============================================
# Stage 2: Test - Run unit tests
# ============================================
FROM base AS test
WORKDIR /app

# Copy all source code
COPY . .

# Run all tests
RUN dotnet test IdentityService.sln --verbosity normal --logger "trx;LogFileName=test-results.trx"

# ============================================
# Stage 3: Development - Watch mode support
# ============================================
FROM base AS development
WORKDIR /app

# Copy all source code
COPY . .

# Install dotnet-ef
RUN dotnet tool install --global dotnet-ef --version 8.0.3
ENV PATH="$PATH:/root/.dotnet/tools"

# Expose ports
EXPOSE 5000
EXPOSE 5001

# Set environment to Development
ENV ASPNETCORE_ENVIRONMENT=Development
ENV ASPNETCORE_URLS=http://+:5000

# Default command runs in watch mode
ENTRYPOINT ["dotnet", "watch", "run", "--project", "src/IdentityService.API/IdentityService.API.csproj", "--urls", "http://0.0.0.0:5000"]

# ============================================
# Stage 4: Build - Production build
# ============================================
FROM base AS build
WORKDIR /app

# Copy all source code
COPY . .

# Build the solution in Release mode
RUN dotnet build IdentityService.sln -c Release -o /app/build

# Publish the API project
RUN dotnet publish src/IdentityService.API/IdentityService.API.csproj \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

# ============================================
# Stage 5: Production - Runtime only
# ============================================
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS production
WORKDIR /app

# Install curl for health checks
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy published application
COPY --from=build /app/publish .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port (adjust if needed)
EXPOSE 8080
EXPOSE 8081

# Set environment variables
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080

# Run the application
ENTRYPOINT ["dotnet", "IdentityService.API.dll"]
