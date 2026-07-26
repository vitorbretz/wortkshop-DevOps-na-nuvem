# ============================================
# Production-Ready Dockerfile for ASP.NET Core 8.0
# ============================================
# Features:
# - Multi-stage build for minimal image size
# - Runs as non-root user (rootless)
# - Alpine-based runtime image
# - Health check included
# - Optimized layer caching
# - Security hardened
# ============================================

# ============================================
# Stage 1: Build Stage
# ============================================
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS builder

# Set working directory
WORKDIR /src

# Copy csproj and restore dependencies (separate layer for caching)
COPY YoutubeLiveApp.csproj ./
RUN dotnet restore YoutubeLiveApp.csproj --runtime linux-musl-x64

# Copy remaining source code
COPY . ./

# Build and publish the application
RUN dotnet publish YoutubeLiveApp.csproj \
    -c Release \
    -o /app/publish \
    --runtime linux-musl-x64 \
    --self-contained false \
    --no-restore

# ============================================
# Stage 2: Runtime Stage (Production)
# ============================================
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime

# Install curl for health checks
RUN apk add --no-cache curl

# Create non-root user and group
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup -s /sbin/nologin

# Set working directory
WORKDIR /app

# Copy published application from builder stage
COPY --from=builder --chown=appuser:appgroup /app/publish ./

# Switch to non-root user
USER appuser

# Expose port 8080
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Health check configuration
HEALTHCHECK --interval=30s \
            --timeout=3s \
            --start-period=40s \
            --retries=3 \
    CMD curl -f http://localhost:8080/backend/health || exit 1

# Set environment variables for production
ENV ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true \
    DOTNET_EnableDiagnostics=0

# Start the application
ENTRYPOINT ["dotnet", "YoutubeLiveApp.dll"]
