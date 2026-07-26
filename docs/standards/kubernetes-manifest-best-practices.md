# Kubernetes Manifest Best Practices

## Overview
This document defines the standards and best practices for creating Kubernetes manifests in the dvn-workshop project. These guidelines ensure consistency, reliability, and production-readiness across all deployments.

## Core Principles

### 1. Always Create Service with Deployment
Every Deployment MUST have a corresponding Service manifest. Services should be of type `NodePort` by default unless specified otherwise.

### 2. Minimum Replicas
All Deployments MUST have a minimum of 2 replicas to ensure high availability.

### 3. Health Checks
All Deployments MUST define both `readinessProbe` and `livenessProbe` to ensure application health monitoring.

### 4. Pod Disruption Budget
Every Deployment MUST have a corresponding PodDisruptionBudget to maintain availability during voluntary disruptions.

### 5. Standard Labels
All resources MUST use the standard Kubernetes recommended labels for better organization and management.

## Standard Labels

All Kubernetes resources MUST include the following labels:

```yaml
labels:
  app.kubernetes.io/name: <application-name>
  app.kubernetes.io/instance: <instance-name>
  app.kubernetes.io/version: <version>
  app.kubernetes.io/component: <component-type>
  app.kubernetes.io/part-of: <project-name>
  app.kubernetes.io/managed-by: <tool-name>
```

### Label Descriptions

- **app.kubernetes.io/name**: The name of the application (e.g., `youtube-backend`, `youtube-frontend`)
- **app.kubernetes.io/instance**: A unique name identifying the instance of an application (e.g., `youtube-backend-prod`, `youtube-backend-dev`)
- **app.kubernetes.io/version**: The current version of the application (e.g., `v1.0.0`, `1.2.3`)
- **app.kubernetes.io/component**: The component within the architecture (e.g., `backend`, `frontend`, `database`)
- **app.kubernetes.io/part-of**: The name of a higher level application this one is part of (e.g., `dvn-workshop`, `youtube-live-app`)
- **app.kubernetes.io/managed-by**: The tool being used to manage the operation of an application (e.g., `kubectl`, `helm`, `terraform`)

## Manifest Structure

### Complete Example: Backend Application

```yaml
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: youtube-backend
  namespace: default
  labels:
    app.kubernetes.io/name: youtube-backend
    app.kubernetes.io/instance: youtube-backend-prod
    app.kubernetes.io/version: v1.0.0
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: dvn-workshop
    app.kubernetes.io/managed-by: kubectl
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: youtube-backend
      app.kubernetes.io/instance: youtube-backend-prod
  template:
    metadata:
      labels:
        app.kubernetes.io/name: youtube-backend
        app.kubernetes.io/instance: youtube-backend-prod
        app.kubernetes.io/version: v1.0.0
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: dvn-workshop
    spec:
      containers:
      - name: backend
        image: 910661159891.dkr.ecr.us-east-1.amazonaws.com/dvn-workshop/backend:latest
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /backend/health
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /backend/health
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: youtube-backend
  namespace: default
  labels:
    app.kubernetes.io/name: youtube-backend
    app.kubernetes.io/instance: youtube-backend-prod
    app.kubernetes.io/version: v1.0.0
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: dvn-workshop
    app.kubernetes.io/managed-by: kubectl
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: youtube-backend
    app.kubernetes.io/instance: youtube-backend-prod
  ports:
  - name: http
    protocol: TCP
    port: 8080
    targetPort: http
    nodePort: 30080  # Optional: specify nodePort or let Kubernetes assign

---
# PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: youtube-backend-pdb
  namespace: default
  labels:
    app.kubernetes.io/name: youtube-backend
    app.kubernetes.io/instance: youtube-backend-prod
    app.kubernetes.io/version: v1.0.0
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: dvn-workshop
    app.kubernetes.io/managed-by: kubectl
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: youtube-backend
      app.kubernetes.io/instance: youtube-backend-prod
```

### Complete Example: Frontend Application

```yaml
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: youtube-frontend
  namespace: default
  labels:
    app.kubernetes.io/name: youtube-frontend
    app.kubernetes.io/instance: youtube-frontend-prod
    app.kubernetes.io/version: v1.0.0
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: dvn-workshop
    app.kubernetes.io/managed-by: kubectl
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: youtube-frontend
      app.kubernetes.io/instance: youtube-frontend-prod
  template:
    metadata:
      labels:
        app.kubernetes.io/name: youtube-frontend
        app.kubernetes.io/instance: youtube-frontend-prod
        app.kubernetes.io/version: v1.0.0
        app.kubernetes.io/component: frontend
        app.kubernetes.io/part-of: dvn-workshop
    spec:
      containers:
      - name: frontend
        image: 910661159891.dkr.ecr.us-east-1.amazonaws.com/dvn-workshop/frontend:latest
        ports:
        - name: http
          containerPort: 3000
          protocol: TCP
        env:
        - name: NODE_ENV
          value: "production"
        - name: NEXT_TELEMETRY_DISABLED
          value: "1"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3

---
# Service
apiVersion: v1
kind: Service
metadata:
  name: youtube-frontend
  namespace: default
  labels:
    app.kubernetes.io/name: youtube-frontend
    app.kubernetes.io/instance: youtube-frontend-prod
    app.kubernetes.io/version: v1.0.0
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: dvn-workshop
    app.kubernetes.io/managed-by: kubectl
spec:
  type: NodePort
  selector:
    app.kubernetes.io/name: youtube-frontend
    app.kubernetes.io/instance: youtube-frontend-prod
  ports:
  - name: http
    protocol: TCP
    port: 3000
    targetPort: http
    nodePort: 30030  # Optional: specify nodePort or let Kubernetes assign

---
# PodDisruptionBudget
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: youtube-frontend-pdb
  namespace: default
  labels:
    app.kubernetes.io/name: youtube-frontend
    app.kubernetes.io/instance: youtube-frontend-prod
    app.kubernetes.io/version: v1.0.0
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: dvn-workshop
    app.kubernetes.io/managed-by: kubectl
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: youtube-frontend
      app.kubernetes.io/instance: youtube-frontend-prod
```

## Detailed Requirements

### Deployment Requirements

#### 1. Replicas
```yaml
spec:
  replicas: 2  # MINIMUM 2 replicas for high availability
```

#### 2. Container Ports
Always use named ports for better readability:
```yaml
ports:
- name: http
  containerPort: 8080
  protocol: TCP
```

#### 3. Resource Limits
Always define resource requests and limits:
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

#### 4. Liveness Probe
Checks if the container is alive. If it fails, Kubernetes will restart the container.
```yaml
livenessProbe:
  httpGet:
    path: /health  # or /backend/health, /api/health
    port: http
  initialDelaySeconds: 30  # Wait before first probe
  periodSeconds: 10        # Check every 10 seconds
  timeoutSeconds: 3        # Probe timeout
  failureThreshold: 3      # Restart after 3 failures
```

#### 5. Readiness Probe
Checks if the container is ready to serve traffic. If it fails, the pod is removed from service endpoints.
```yaml
readinessProbe:
  httpGet:
    path: /health  # or /backend/health, /api/health
    port: http
  initialDelaySeconds: 10  # Wait before first probe (shorter than liveness)
  periodSeconds: 5         # Check every 5 seconds (more frequent)
  timeoutSeconds: 3        # Probe timeout
  failureThreshold: 3      # Mark unready after 3 failures
```

**Probe Types Available:**
- `httpGet`: HTTP GET request to a path
- `tcpSocket`: TCP connection to a port
- `exec`: Execute a command in the container

### Service Requirements

#### 1. Service Type
Default service type MUST be `NodePort`:
```yaml
spec:
  type: NodePort
```

**Available Service Types:**
- `NodePort`: Exposes service on each node's IP at a static port (30000-32767)
- `ClusterIP`: Internal cluster IP (use when no external access needed)
- `LoadBalancer`: Creates external load balancer (use for production internet-facing services)

#### 2. Port Configuration
```yaml
ports:
- name: http
  protocol: TCP
  port: 8080              # Service port
  targetPort: http        # Pod port (use named port)
  nodePort: 30080         # Optional: specific NodePort (30000-32767)
```

#### 3. Selector
Service selector MUST match Deployment labels:
```yaml
selector:
  app.kubernetes.io/name: youtube-backend
  app.kubernetes.io/instance: youtube-backend-prod
```

### PodDisruptionBudget Requirements

#### 1. Minimum Available
Define minimum number of pods that must be available during voluntary disruptions:
```yaml
spec:
  minAvailable: 1  # At least 1 pod must be available
```

**Alternative: Maximum Unavailable**
```yaml
spec:
  maxUnavailable: 1  # At most 1 pod can be unavailable
```

#### 2. Selector
PDB selector MUST match Deployment labels:
```yaml
selector:
  matchLabels:
    app.kubernetes.io/name: youtube-backend
    app.kubernetes.io/instance: youtube-backend-prod
```

**Use Cases:**
- Cluster upgrades
- Node maintenance
- Cluster autoscaling
- Manual pod evictions

## File Organization

### Single Application
For simple deployments, use a single file:
```
k8s/
  └── youtube-backend.yaml  # Contains Deployment + Service + PDB
```

### Multiple Applications
For multiple applications, organize by application:
```
k8s/
  ├── backend/
  │   └── youtube-backend.yaml
  └── frontend/
      └── youtube-frontend.yaml
```

### Complex Applications
For complex applications with multiple resources:
```
k8s/
  └── youtube-backend/
      ├── deployment.yaml
      ├── service.yaml
      ├── pdb.yaml
      ├── configmap.yaml
      └── secret.yaml
```

## Naming Conventions

### Resource Names
- Use lowercase kebab-case
- Format: `{application}-{component}` or `{application}-{component}-{resource-type}`
- Examples:
  - `youtube-backend`
  - `youtube-frontend`
  - `youtube-backend-pdb`

### Label Values
- Use lowercase kebab-case for multi-word values
- Examples:
  - `youtube-backend`
  - `youtube-backend-prod`
  - `dvn-workshop`

### Port Names
- Use descriptive lowercase names
- Examples:
  - `http`
  - `https`
  - `grpc`
  - `metrics`

## Environment-Specific Configuration

### Development Environment
```yaml
metadata:
  name: youtube-backend-dev
  labels:
    app.kubernetes.io/instance: youtube-backend-dev
    app.kubernetes.io/environment: development
spec:
  replicas: 2
```

### Production Environment
```yaml
metadata:
  name: youtube-backend-prod
  labels:
    app.kubernetes.io/instance: youtube-backend-prod
    app.kubernetes.io/environment: production
spec:
  replicas: 3  # More replicas for production
```

## Security Best Practices

### 1. Run as Non-Root
```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1001
        fsGroup: 1001
```

### 2. Read-Only Root Filesystem
```yaml
spec:
  template:
    spec:
      containers:
      - name: backend
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
```

### 3. Drop Capabilities
```yaml
spec:
  template:
    spec:
      containers:
      - name: backend
        securityContext:
          capabilities:
            drop:
            - ALL
```

## Common Patterns

### ConfigMap for Configuration
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: youtube-backend-config
  labels:
    app.kubernetes.io/name: youtube-backend
data:
  API_URL: "https://api.example.com"
  LOG_LEVEL: "info"
```

Reference in Deployment:
```yaml
env:
- name: API_URL
  valueFrom:
    configMapKeyRef:
      name: youtube-backend-config
      key: API_URL
```

### Secret for Sensitive Data
```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: youtube-backend-secret
  labels:
    app.kubernetes.io/name: youtube-backend
type: Opaque
stringData:
  DATABASE_PASSWORD: "changeme"
  API_KEY: "secret-key"
```

Reference in Deployment:
```yaml
env:
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: youtube-backend-secret
      key: DATABASE_PASSWORD
```

## Validation Checklist

Before applying any manifest, verify:

- [ ] Deployment has minimum 2 replicas
- [ ] Both livenessProbe and readinessProbe are defined
- [ ] Service of type NodePort is created
- [ ] PodDisruptionBudget is defined with minAvailable: 1
- [ ] All standard labels are present on all resources
- [ ] Resource requests and limits are defined
- [ ] Named ports are used consistently
- [ ] Selectors match between Deployment, Service, and PDB
- [ ] Health check paths are correct for the application
- [ ] Container image is from ECR with proper tag

## Troubleshooting

### Pod Not Starting
```bash
# Check pod status
kubectl get pods -l app.kubernetes.io/name=youtube-backend

# View pod logs
kubectl logs -l app.kubernetes.io/name=youtube-backend

# Describe pod for events
kubectl describe pod -l app.kubernetes.io/name=youtube-backend
```

### Service Not Accessible
```bash
# Check service
kubectl get svc youtube-backend

# Check endpoints
kubectl get endpoints youtube-backend

# Verify selectors match
kubectl get pods -l app.kubernetes.io/name=youtube-backend --show-labels
```

### Probe Failures
```bash
# View events
kubectl get events --sort-by='.lastTimestamp'

# Check probe configuration
kubectl describe deployment youtube-backend

# Test probe manually
kubectl exec -it <pod-name> -- curl http://localhost:8080/backend/health
```

## References

- [Kubernetes Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

## Version
1.0.0

## Last Updated
2026-07-26
