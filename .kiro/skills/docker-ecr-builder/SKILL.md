# Docker ECR Builder & Pusher

## Overview
This skill automates the process of building Docker images and pushing them to Amazon Elastic Container Registry (ECR). It handles ECR authentication, repository creation, multi-architecture builds, parallel processing, and provides comprehensive error handling and validation.

## Capabilities
- **Automatic ECR Login**: Handles AWS ECR authentication automatically
- **Repository Management**: Creates ECR repositories if they don't exist
- **Parallel Builds**: Builds multiple images concurrently for faster execution
- **Multi-Architecture Support**: Build for amd64, arm64, or both platforms
- **Tag Management**: Supports multiple tags (latest, version, git commit, etc.)
- **Image Scanning**: Optional vulnerability scanning after push
- **Lifecycle Policies**: Apply retention policies to manage old images
- **Build Cache**: Leverages Docker BuildKit for efficient caching
- **Validation**: Verifies images are successfully pushed and pullable
- **Rollback Support**: Can revert to previous image versions

## Prerequisites
- AWS CLI configured with appropriate credentials
- Docker installed and running
- AWS ECR permissions (ecr:*, iam:GetAuthorizationToken)
- Docker BuildKit enabled (for better performance)

## Workflow

### Step 1: Authentication
```bash
# Automatic ECR login
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

### Step 2: Repository Setup
```bash
# Check if repository exists
aws ecr describe-repositories --repository-names <name>

# Create if doesn't exist
aws ecr create-repository --repository-name <name> \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256
```

### Step 3: Build Images
```bash
# Single image build
docker build -t <image>:<tag> .

# Multi-architecture build
docker buildx build --platform linux/amd64,linux/arm64 \
  -t <image>:<tag> --push .

# Parallel builds (multiple images)
docker build -t backend:latest backend/ &
docker build -t frontend:latest frontend/ &
wait
```

### Step 4: Tag Images
```bash
# Tag for ECR
docker tag <local-image>:<tag> \
  <account-id>.dkr.ecr.<region>.amazonaws.com/<repo>:<tag>

# Multiple tags
docker tag <image> <ecr-repo>:latest
docker tag <image> <ecr-repo>:v1.0.0
docker tag <image> <ecr-repo>:$(git rev-parse --short HEAD)
```

### Step 5: Push to ECR
```bash
# Push single tag
docker push <ecr-repo>:<tag>

# Push all tags
docker push --all-tags <ecr-repo>

# Parallel push (multiple images)
docker push <ecr-repo>:backend &
docker push <ecr-repo>:frontend &
wait
```

### Step 6: Validation
```bash
# Verify image exists in ECR
aws ecr describe-images \
  --repository-name <repo> \
  --image-ids imageTag=<tag>

# Pull test
docker pull <ecr-repo>:<tag>

# Scan for vulnerabilities
aws ecr start-image-scan \
  --repository-name <repo> \
  --image-id imageTag=<tag>
```

## Usage Examples

### Single Application Build & Push
```bash
# Build and push backend to ECR
"Build and push the backend application to ECR with tag v1.0.0"

# What happens:
# 1. Login to ECR (910661159891.dkr.ecr.us-east-1.amazonaws.com)
# 2. Create repository if needed (youtube-backend)
# 3. Build Docker image
# 4. Tag with multiple tags (latest, v1.0.0, git-commit)
# 5. Push all tags to ECR
# 6. Verify push success
```

### Multiple Applications (Parallel)
```bash
# Build and push both apps simultaneously
"Build and push both backend and frontend applications to ECR in parallel"

# What happens:
# 1. Login to ECR once
# 2. Create/verify both repositories
# 3. Build both images in parallel
# 4. Tag both images
# 5. Push both images in parallel
# 6. Verify both pushes
```

### Multi-Architecture Build
```bash
# Build for multiple platforms
"Build and push frontend for both amd64 and arm64 architectures"

# What happens:
# 1. Enable Docker buildx
# 2. Create builder instance
# 3. Build multi-arch image
# 4. Push manifest with all architectures
```

## Configuration

### Environment Variables
```bash
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=910661159891
ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build Configuration
DOCKER_BUILDKIT=1
BUILDKIT_PROGRESS=plain

# Repository Configuration
ECR_REPOSITORY_PREFIX=dvn-workshop
IMAGE_TAG_STRATEGY=git-commit  # or version, latest, timestamp
```

### Repository Naming Convention
```
<project>-<service>-<environment>

Examples:
- dvn-workshop-backend-prod
- dvn-workshop-frontend-dev
- youtube-live-backend
- youtube-live-frontend
```

### Tagging Strategy
```
Multiple tags per image:
1. latest              - Always points to most recent
2. v{version}          - Semantic version (v1.0.0)
3. {git-commit}        - Git commit SHA (abc123f)
4. {environment}       - Environment name (prod, dev)
5. {timestamp}         - Build timestamp (20260726-120000)

Example:
- 910661159891.dkr.ecr.us-east-1.amazonaws.com/backend:latest
- 910661159891.dkr.ecr.us-east-1.amazonaws.com/backend:v1.0.0
- 910661159891.dkr.ecr.us-east-1.amazonaws.com/backend:abc123f
```

## Build Script Example

### Bash Script for Automated Build & Push
```bash
#!/bin/bash
# build-and-push.sh

set -e

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
GIT_COMMIT=$(git rev-parse --short HEAD)
VERSION="v1.0.0"

# Applications to build
declare -A APPS=(
  ["backend"]="dvn-workshop-apps/backend/YoutubeLiveApp"
  ["frontend"]="dvn-workshop-apps/frontend/youtube-live-app"
)

# Step 1: ECR Login
echo "==> Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Step 2: Create repositories if needed
for app in "${!APPS[@]}"; do
  echo "==> Checking repository: ${app}"
  aws ecr describe-repositories --repository-names ${app} 2>/dev/null || \
    aws ecr create-repository --repository-name ${app} \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256
done

# Step 3: Build images in parallel
echo "==> Building images in parallel..."
pids=()
for app in "${!APPS[@]}"; do
  (
    echo "Building ${app}..."
    cd ${APPS[$app]}
    docker build -t ${app}:${VERSION} .
    echo "${app} build complete"
  ) &
  pids+=($!)
done

# Wait for all builds
for pid in "${pids[@]}"; do
  wait $pid || exit 1
done

# Step 4: Tag images
echo "==> Tagging images..."
for app in "${!APPS[@]}"; do
  docker tag ${app}:${VERSION} ${ECR_REGISTRY}/${app}:latest
  docker tag ${app}:${VERSION} ${ECR_REGISTRY}/${app}:${VERSION}
  docker tag ${app}:${VERSION} ${ECR_REGISTRY}/${app}:${GIT_COMMIT}
done

# Step 5: Push images in parallel
echo "==> Pushing images to ECR in parallel..."
pids=()
for app in "${!APPS[@]}"; do
  (
    echo "Pushing ${app}..."
    docker push ${ECR_REGISTRY}/${app}:latest
    docker push ${ECR_REGISTRY}/${app}:${VERSION}
    docker push ${ECR_REGISTRY}/${app}:${GIT_COMMIT}
    echo "${app} push complete"
  ) &
  pids+=($!)
done

# Wait for all pushes
for pid in "${pids[@]}"; do
  wait $pid || exit 1
done

# Step 6: Verify
echo "==> Verifying images in ECR..."
for app in "${!APPS[@]}"; do
  aws ecr describe-images \
    --repository-name ${app} \
    --image-ids imageTag=latest \
    --query 'imageDetails[0].imagePushedAt' \
    --output text
done

echo "==> All images successfully built and pushed!"
```

## Advanced Features

### Multi-Stage Build Optimization
```bash
# Use BuildKit cache mounts
docker build \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  --cache-from ${ECR_REGISTRY}/${APP}:latest \
  -t ${APP}:${TAG} .
```

### Image Scanning
```bash
# Scan after push
aws ecr start-image-scan \
  --repository-name ${APP} \
  --image-id imageTag=${TAG}

# Get scan results
aws ecr describe-image-scan-findings \
  --repository-name ${APP} \
  --image-id imageTag=${TAG}
```

### Lifecycle Policies
```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

Apply policy:
```bash
aws ecr put-lifecycle-policy \
  --repository-name ${APP} \
  --lifecycle-policy-text file://policy.json
```

### Cross-Region Replication
```bash
# Enable replication
aws ecr put-replication-configuration \
  --replication-configuration file://replication.json

# replication.json
{
  "rules": [
    {
      "destinations": [
        {
          "region": "us-west-2",
          "registryId": "910661159891"
        }
      ]
    }
  ]
}
```

## CI/CD Integration

### GitHub Actions
```yaml
name: Build and Push to ECR

on:
  push:
    branches: [main]

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/backend:$IMAGE_TAG .
          docker push $ECR_REGISTRY/backend:$IMAGE_TAG
```

### GitLab CI
```yaml
build-and-push:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - apk add --no-cache aws-cli
    - aws ecr get-login-password --region us-east-1 | 
        docker login --username AWS --password-stdin 
        910661159891.dkr.ecr.us-east-1.amazonaws.com
  script:
    - docker build -t backend:$CI_COMMIT_SHA .
    - docker tag backend:$CI_COMMIT_SHA 
        910661159891.dkr.ecr.us-east-1.amazonaws.com/backend:latest
    - docker push 910661159891.dkr.ecr.us-east-1.amazonaws.com/backend:latest
```

## Troubleshooting

### Authentication Failures
```bash
# Check AWS credentials
aws sts get-caller-identity

# Re-login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  910661159891.dkr.ecr.us-east-1.amazonaws.com

# Check ECR permissions
aws ecr get-repository-policy --repository-name backend
```

### Build Failures
```bash
# Check disk space
docker system df
docker system prune -a

# View build logs
docker build --progress=plain -t app:latest .

# Check BuildKit cache
docker buildx du --verbose
```

### Push Failures
```bash
# Check network connectivity
curl -I https://910661159891.dkr.ecr.us-east-1.amazonaws.com

# Check image size
docker images app:latest

# Manual retry
docker push --disable-content-trust=false <image>
```

### Repository Issues
```bash
# List all repositories
aws ecr describe-repositories

# Check repository policies
aws ecr get-repository-policy --repository-name backend

# Delete and recreate
aws ecr delete-repository --repository-name backend --force
aws ecr create-repository --repository-name backend
```

## Best Practices

### Security
- Never commit AWS credentials
- Use IAM roles when possible (ECS, EC2, Lambda)
- Enable image scanning
- Use private repositories
- Implement least privilege access
- Rotate credentials regularly

### Performance
- Use BuildKit for caching
- Leverage layer caching
- Build in parallel when possible
- Use multi-stage builds
- Minimize image sizes
- Use specific base image versions

### Maintenance
- Tag images with multiple identifiers
- Implement lifecycle policies
- Monitor repository sizes
- Regular vulnerability scans
- Document tagging strategy
- Automate cleanup of old images

### Reliability
- Validate images after push
- Test image pull before deployment
- Implement retry logic
- Monitor push/pull metrics
- Set up alerting for failures
- Keep backup of critical images

## Cost Optimization

### Storage Costs
```bash
# Check repository sizes
aws ecr describe-repositories --query \
  'repositories[*].[repositoryName,repositoryUri]' --output table

# Calculate storage cost
# ECR Storage: $0.10 per GB-month

# Apply lifecycle policies to remove old images
# Keep only: latest, last 5 versions, last 30 days
```

### Transfer Costs
```bash
# Data transfer OUT is charged
# Within same region: Free
# Cross-region: Standard data transfer rates

# Minimize cross-region pulls
# Use replication for multi-region deployments
```

## Monitoring

### CloudWatch Metrics
- Repository PullCount
- Repository ImageCount
- Repository ImageSizeBytes

### Alerts
```bash
# Create CloudWatch alarm for repository size
aws cloudwatch put-metric-alarm \
  --alarm-name ecr-repo-size \
  --metric-name ImageSizeBytes \
  --namespace AWS/ECR \
  --statistic Sum \
  --period 86400 \
  --threshold 10737418240 \
  --comparison-operator GreaterThanThreshold
```

## References
- [Amazon ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [Docker Build Documentation](https://docs.docker.com/engine/reference/commandline/build/)
- [Docker BuildKit](https://docs.docker.com/build/buildkit/)
- [AWS ECR Best Practices](https://docs.aws.amazon.com/AmazonECR/latest/userguide/best-practices.html)

## Version
1.0.0

## Last Updated
2026-07-26
