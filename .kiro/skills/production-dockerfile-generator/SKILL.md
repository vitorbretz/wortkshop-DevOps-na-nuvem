# Production-Ready Dockerfile Generator

## Overview
This skill generates optimized, production-ready Dockerfiles for applications across multiple programming languages and frameworks. It follows container security and performance best practices including multi-stage builds, minimal base images, rootless execution, and health checks.

## Capabilities
- **Multi-Language Support**: Automatically detects application language/framework and generates appropriate Dockerfile
- **Security First**: Runs containers as non-root user with minimal privileges
- **Optimized Builds**: Uses multi-stage builds to minimize final image size
- **Alpine Images**: Prefers Alpine-based images for smaller footprint
- **Health Checks**: Includes HEALTHCHECK instructions and validation testing
- **Layer Caching**: Optimizes layer order for efficient caching
- **Production Ready**: Includes best practices for production deployments

## Supported Languages & Frameworks
- **Node.js** (Express, NestJS, Next.js, etc.)
- **Python** (Flask, FastAPI, Django, etc.)
- **Go** (Gin, Echo, Chi, etc.)
- **Java** (Spring Boot, Quarkus, Micronaut, etc.)
- **Ruby** (Rails, Sinatra, etc.)
- **.NET** (ASP.NET Core, etc.)
- **Rust** (Actix, Rocket, etc.)
- **PHP** (Laravel, Symfony, etc.)

## Best Practices Implemented

### 1. Multi-Stage Builds
- Separate build and runtime stages
- Only copy necessary artifacts to final image
- Reduces final image size by 60-90%

### 2. Minimal Base Images
- Prefer Alpine Linux variants (`alpine`, `slim`)
- Use distroless images when appropriate
- Strip debug symbols and unnecessary tools

### 3. Rootless Execution
- Create dedicated non-root user
- Run application with minimal privileges
- Set appropriate file permissions
- Use USER directive

### 4. Layer Optimization
- Copy dependency files first (package.json, requirements.txt, go.mod, etc.)
- Install dependencies in separate layer
- Copy application code last
- Maximizes Docker layer caching

### 5. Security Hardening
- No secrets in image layers
- Scan for vulnerabilities
- Use specific version tags (not `latest`)
- Remove package managers when possible
- Set read-only root filesystem when applicable

### 6. Health Checks
- Add HEALTHCHECK instruction
- Verify application is responding
- Use appropriate endpoint (/health, /healthz, /ping)
- Configure timeouts and intervals

### 7. Resource Management
- Set appropriate WORKDIR
- Clean build artifacts
- Remove cache files
- Optimize package installations

## Workflow

### Step 1: Analyze Application
```
- Detect programming language
- Identify framework and dependencies
- Determine build requirements
- Find entry point
- Identify health check endpoint
```

### Step 2: Generate Dockerfile
```
- Select appropriate base images
- Create multi-stage build structure
- Configure non-root user
- Add dependency installation
- Copy application code
- Set up health check
- Define CMD/ENTRYPOINT
```

### Step 3: Validate Dockerfile
```
- Build Docker image
- Start container
- Wait for application startup
- Execute health check (curl/wget)
- Verify response
- Stop and cleanup
```

## Usage

### Invoke the Skill
Ask the agent to generate a production-ready Dockerfile for your application:

```
"Generate a production-ready Dockerfile for my Node.js Express application"
"Create an optimized Dockerfile for my Python FastAPI app with health checks"
"I need a secure Dockerfile for my Go API that runs rootless"
```

### What to Provide
- **Application directory** or codebase location
- **Programming language/framework** (if not obvious)
- **Port number** the application listens on
- **Health check endpoint** (or agent will use defaults)
- **Build requirements** (if any special needs)

### What You'll Get
1. **Dockerfile** - Production-ready with all best practices
2. **Build validation** - Confirms Dockerfile builds successfully
3. **Health check test** - Verifies container runs and responds
4. **.dockerignore** (optional) - Excludes unnecessary files
5. **Build instructions** - Commands to build and run

## Examples

### Node.js Express Application
```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && \
    npm cache clean --force
COPY . .

# Production stage
FROM node:20-alpine
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
WORKDIR /app
COPY --from=builder --chown=nodejs:nodejs /app .
USER nodejs
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"
CMD ["node", "server.js"]
```

### Python FastAPI Application
```dockerfile
# Build stage
FROM python:3.12-alpine AS builder
WORKDIR /app
RUN apk add --no-cache gcc musl-dev libffi-dev
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.12-alpine
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -s /bin/sh -D appuser
WORKDIR /app
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appgroup . .
USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/health || exit 1
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Go Application
```dockerfile
# Build stage
FROM golang:1.23-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git ca-certificates
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-w -s" -o /app/server .

# Production stage
FROM alpine:3.20
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup
WORKDIR /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder --chown=appuser:appgroup /app/server .
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
CMD ["./server"]
```

## Validation Process

### Build Test
```bash
docker build -t app-test:latest .
```

### Container Test
```bash
docker run -d --name app-test -p 8080:8080 app-test:latest
sleep 10  # Wait for startup
```

### Health Check Test
```bash
curl -f http://localhost:8080/health || exit 1
```

### Cleanup
```bash
docker stop app-test
docker rm app-test
```

## Advanced Features

### Environment Variables
- Uses ENV for configuration
- Supports .env files (not in image)
- Externalizes secrets

### Volume Mounts
- Recommends volumes for data persistence
- Excludes volumes from image

### Networking
- Exposes only necessary ports
- Documents port requirements
- Supports custom networks

### Logging
- Logs to stdout/stderr
- No log files in containers
- Compatible with Docker logging drivers

## Troubleshooting

### Image Too Large
- Check for unnecessary files in COPY
- Add .dockerignore file
- Use multi-stage builds
- Remove dev dependencies

### Build Failures
- Check base image availability
- Verify dependency versions
- Review build logs
- Check network connectivity

### Health Check Fails
- Verify endpoint path
- Check application startup time
- Increase start-period
- Review application logs

### Permission Errors
- Verify USER directive
- Check file ownership (COPY --chown)
- Review directory permissions
- Ensure writable directories exist

## Security Considerations

### Image Scanning
After building, scan for vulnerabilities:
```bash
docker scan app-test:latest
trivy image app-test:latest
```

### Minimal Attack Surface
- No shells in final image (when possible)
- No package managers
- No compiler tools
- Only runtime dependencies

### Supply Chain Security
- Pin base image versions
- Verify image signatures
- Use trusted registries
- Review dependencies

## Performance Optimization

### Build Time
- Order layers for cache hits
- Parallelize independent steps
- Use BuildKit
- Minimize context size

### Runtime Performance
- Use compiled binaries (Go, Rust)
- Enable JIT compilation (Node.js, Java)
- Optimize memory allocation
- Configure garbage collection

### Image Size
- Use Alpine variants
- Multi-stage builds
- Remove build dependencies
- Strip debug symbols
- Compress assets

## Integration

### CI/CD Pipelines
- Works with GitHub Actions
- Compatible with GitLab CI
- Integrates with Jenkins
- Supports AWS CodeBuild

### Container Registries
- Docker Hub
- Amazon ECR
- Google GCR
- Azure ACR
- Harbor

### Orchestration
- Kubernetes ready
- Docker Swarm compatible
- ECS optimized
- Cloud Run compatible

## Maintenance

### Updates
- Review base image updates
- Update dependency versions
- Scan for vulnerabilities
- Test after updates

### Monitoring
- Add metrics endpoints
- Expose health endpoints
- Log important events
- Track resource usage

## References
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Security Best Practices](https://docs.docker.com/engine/security/)
- [Health Check Reference](https://docs.docker.com/engine/reference/builder/#healthcheck)

## Version
1.0.0

## Last Updated
2026-07-26
