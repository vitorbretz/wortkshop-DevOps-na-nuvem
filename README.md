# Workshop DevOps na Nuvem

[![CI/CD Pipeline](https://github.com/vitorbretz/wortkshop-DevOps-na-nuvem/actions/workflows/ci-cd.yaml/badge.svg)](https://github.com/vitorbretz/wortkshop-DevOps-na-nuvem/actions/workflows/ci-cd.yaml)

Projeto de referência demonstrando práticas modernas de DevOps na AWS, incluindo Infrastructure as Code (IaC), GitOps, CI/CD e containerização.

## 🎯 Visão Geral

Este projeto implementa uma aplicação YouTube Live Search completa com:

- **Frontend**: Next.js 14 (React + TypeScript)
- **Backend**: ASP.NET Core 8 (C#)
- **Infrastructure**: AWS EKS, VPC, ECR
- **CI/CD**: GitHub Actions com OIDC + ArgoCD GitOps
- **IaC**: Terraform com remote backend S3

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                │
│  │ Frontend   │  │  Backend   │  │ Kubernetes │                │
│  │ Next.js    │  │ ASP.NET    │  │ Manifests  │                │
│  └────────────┘  └────────────┘  └────────────┘                │
└───────────┬───────────────────────────────┬─────────────────────┘
            │                               │
            │ Push/PR                       │ GitOps Sync
            ▼                               ▼
    ┌───────────────┐              ┌──────────────┐
    │ GitHub Actions│              │   ArgoCD     │
    │   (OIDC)      │              │   Server     │
    └───────┬───────┘              └──────┬───────┘
            │                              │
            │ Build & Push                 │ Deploy
            ▼                              ▼
    ┌───────────────┐              ┌──────────────┐
    │  Amazon ECR   │              │   EKS        │
    │  (Registries) │              │   Cluster    │
    └───────────────┘              └──────────────┘
```

### Componentes Principais

- **VPC Multi-AZ**: 2 subnets públicas + 2 privadas
- **EKS Cluster**: Kubernetes 1.33 com managed node group
- **ECR Repositories**: Frontend e Backend container images
- **GitHub Actions**: CI com OIDC authentication (zero secrets)
- **ArgoCD**: GitOps continuous deployment
- **Kustomize**: Manifest customization

## 📁 Estrutura do Projeto

```
.
├── dvn-workshop-apps/           # Aplicações
│   ├── frontend/                # Next.js app
│   │   └── youtube-live-app/
│   └── backend/                 # ASP.NET Core API
│       └── YoutubeLiveApp/
├── dvn-workshop-kubernetes/     # Kubernetes manifests
│   ├── frontend/
│   ├── backend/
│   └── kustomization.yaml
├── terraform/                   # Infrastructure as Code
│   ├── 00-remote-backend-stack/ # S3 backend
│   ├── 01-networking-stack/     # VPC, subnets, NAT
│   ├── 02-eks-cluster-stack/    # EKS cluster
│   └── 03-github-oidc-stack/    # OIDC provider
├── argocd/                      # ArgoCD configurations
│   ├── install/
│   └── applications/
├── .github/workflows/           # CI/CD pipelines
│   └── ci-cd.yaml
├── docs/                        # Documentação
│   ├── architecture/            # ADRs
│   │   ├── ADR-001-vpc-network-architecture.md
│   │   ├── ADR-002-terraform-remote-backend.md
│   │   ├── ADR-003-eks-cluster.md
│   │   ├── ADR-004-github-actions-oidc.md
│   │   └── ADR-005-argocd-gitops.md
│   ├── standards/               # Best practices
│   └── CI-CD-SETUP.md          # CI/CD guide
└── scripts/                     # Automation scripts
    ├── install-argocd.sh
    ├── configure-argocd.sh
    └── setup-github-secrets.sh
```

## 🚀 Quick Start

### Pré-requisitos

- AWS CLI configurado
- kubectl instalado
- Terraform >= 1.0
- Docker
- Node.js 20+ (para desenvolvimento local)
- .NET 8 SDK (para desenvolvimento local)

### 1. Provisionar Infraestrutura

```bash
# 1.1 Remote Backend (executar uma única vez)
cd terraform/00-remote-backend-stack
terraform init
terraform apply

# 1.2 Networking (VPC, Subnets, NAT Gateway)
cd terraform/01-networking-stack
terraform init
terraform apply

# 1.3 EKS Cluster
cd terraform/02-eks-cluster-stack
terraform init
terraform apply

# 1.4 GitHub OIDC Provider
cd terraform/03-github-oidc-stack
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com suas informações
terraform init
terraform apply
```

### 2. Configurar kubectl

```bash
aws eks update-kubeconfig --name dvn-workshop-dev-eks --region us-east-1
kubectl get nodes
```

### 3. Instalar ArgoCD

```bash
chmod +x scripts/*.sh
./scripts/install-argocd.sh

# Obter senha admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### 4. Configurar GitHub Secrets

No GitHub repository:
1. Vá em **Settings** > **Secrets and variables** > **Actions**
2. Adicione:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: Output do Terraform `github_actions_role_arn`

```bash
# Obter o ARN
cd terraform/03-github-oidc-stack
terraform output github_actions_role_arn
```

### 5. Deploy Inicial

```bash
# Aplicar configuração ArgoCD
kubectl apply -f argocd/applications/dvn-workshop-app.yaml

# Verificar sync
kubectl get application dvn-workshop -n argocd
```

## 🔄 Workflow de Desenvolvimento

### Fazer mudanças no Frontend

```bash
# 1. Editar código
cd dvn-workshop-apps/frontend/youtube-live-app
# Fazer suas modificações

# 2. Commit e push
git add .
git commit -m "feat: add new feature"
git push origin main

# 3. GitHub Actions automaticamente:
#    - Detecta mudanças no frontend
#    - Build da imagem Docker
#    - Push para ECR com tag SHA
#    - Atualiza kustomization.yaml
#    - Commit da mudança

# 4. ArgoCD automaticamente:
#    - Detecta mudança no Git
#    - Sync com cluster
#    - Deploy da nova versão
```

### Fazer mudanças no Backend

Mesmo processo do frontend, mas para `dvn-workshop-apps/backend/`

## 📊 Monitoramento

### ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Acesse: https://localhost:8080
# User: admin
# Pass: <senha obtida anteriormente>
```

### Verificar Status da Aplicação

```bash
# Status geral
kubectl get all -n default

# Logs do frontend
kubectl logs -l app.kubernetes.io/name=youtube-frontend -n default --tail=50

# Logs do backend
kubectl logs -l app.kubernetes.io/name=youtube-backend -n default --tail=50

# Status ArgoCD
kubectl get application dvn-workshop -n argocd -o yaml
```

### Acessar Aplicação

```bash
# Port forward frontend
kubectl port-forward deployment/youtube-frontend 3000:3000

# Abrir browser
open http://localhost:3000
```

## 🛠️ Comandos Úteis

### Terraform

```bash
# Formatar código
terraform fmt -recursive

# Validar configuração
terraform validate

# Ver plan sem aplicar
terraform plan

# Destruir recursos
terraform destroy
```

### Kubernetes

```bash
# Ver todos recursos
kubectl get all -n default

# Descrever pod
kubectl describe pod <pod-name>

# Logs em tempo real
kubectl logs -f <pod-name>

# Executar comando no pod
kubectl exec -it <pod-name> -- /bin/sh

# Ver eventos
kubectl get events -n default --sort-by='.lastTimestamp'
```

### ArgoCD

```bash
# Sync manual
kubectl patch application dvn-workshop -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Hard refresh
kubectl delete application dvn-workshop -n argocd
kubectl apply -f argocd/applications/dvn-workshop-app.yaml

# Ver diff
argocd app diff dvn-workshop
```

### Docker Local

```bash
# Build frontend local
cd dvn-workshop-apps/frontend/youtube-live-app
docker build -t youtube-frontend:local .
docker run -p 3000:3000 youtube-frontend:local

# Build backend local
cd dvn-workshop-apps/backend/YoutubeLiveApp
docker build -t youtube-backend:local .
docker run -p 8080:8080 youtube-backend:local
```

## 📖 Documentação

### Architecture Decision Records (ADRs)

- [ADR-001](docs/architecture/ADR-001-vpc-network-architecture.md): VPC Network Architecture
- [ADR-002](docs/architecture/ADR-002-terraform-remote-backend.md): Terraform Remote Backend
- [ADR-003](docs/architecture/ADR-003-eks-cluster.md): Amazon EKS Cluster
- [ADR-004](docs/architecture/ADR-004-github-actions-oidc.md): GitHub Actions OIDC
- [ADR-005](docs/architecture/ADR-005-argocd-gitops.md): ArgoCD GitOps

### Guias

- [CI/CD Setup Guide](docs/CI-CD-SETUP.md): Configuração completa do pipeline
- [Terraform Naming Conventions](docs/standards/terraform-naming-conventions.md)
- [Terraform Variable Best Practices](docs/standards/terraform-variable-best-practices.md)
- [Kubernetes Manifest Best Practices](docs/standards/kubernetes-manifest-best-practices.md)

## 🔐 Segurança

### Práticas Implementadas

- ✅ **OIDC Authentication**: Zero credenciais estáticas
- ✅ **Least Privilege IAM**: Permissões mínimas necessárias
- ✅ **Private Subnets**: Workers nodes isolados
- ✅ **Encryption at Rest**: S3, EBS volumes
- ✅ **Encryption in Transit**: TLS/HTTPS
- ✅ **RBAC**: Controle de acesso Kubernetes
- ✅ **Network Policies**: Segmentação de rede
- ✅ **Container Image Scanning**: ECR scanning enabled
- ✅ **Secrets Management**: Kubernetes secrets (considerar External Secrets)

### Melhorias Futuras

- [ ] Integrar AWS Secrets Manager
- [ ] Implementar Pod Security Standards
- [ ] Adicionar Falco para runtime security
- [ ] Configurar AWS GuardDuty
- [ ] Implementar OPA/Gatekeeper policies

## 💰 Custos Estimados

### Custos Mensais (us-east-1)

| Recurso | Quantidade | Custo/mês |
|---------|-----------|-----------|
| EKS Control Plane | 1 | $72 |
| EC2 t3.medium nodes | 2 | $60 |
| NAT Gateway | 1 | $33 |
| EBS Volumes (20GB) | 2 | $4 |
| ECR Storage (10GB) | - | $1 |
| CloudWatch Logs | - | $5 |
| **Total Estimado** | | **~$175/mês** |

*Valores aproximados, podem variar com data transfer e uso*

### Otimizações Possíveis

- Usar Spot Instances para nodes (economia de 70%)
- Implementar auto-scaling com Karpenter
- Configurar lifecycle policies no ECR
- Usar VPC Endpoints para S3/DynamoDB

## 🧪 Testes

### Testes Locais

```bash
# Frontend
cd dvn-workshop-apps/frontend/youtube-live-app
npm install
npm run lint
npm run build
npm test

# Backend
cd dvn-workshop-apps/backend/YoutubeLiveApp
dotnet restore
dotnet build
dotnet test
```

### Testes de Integração

```bash
# Verificar health endpoints
curl http://localhost:3000/api/health
curl http://localhost:8080/backend/health

# Testar API
curl "http://localhost:3000/api/youtube/search?q=kubernetes"
```

## 🤝 Contribuindo

1. Fork o projeto
2. Crie uma feature branch (`git checkout -b feature/amazing-feature`)
3. Commit suas mudanças (`git commit -m 'feat: add amazing feature'`)
4. Push para a branch (`git push origin feature/amazing-feature`)
5. Abra um Pull Request

### Padrões de Commit

Seguimos [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` Nova funcionalidade
- `fix:` Correção de bug
- `docs:` Documentação
- `chore:` Manutenção
- `refactor:` Refatoração
- `test:` Testes

## 📝 License

Este projeto é licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 👥 Autores

- **Vitor Bretz** - *Initial work* - [vitorbretz](https://github.com/vitorbretz)

## 🙏 Agradecimentos

- AWS Documentation
- Kubernetes Community
- ArgoCD Project
- GitHub Actions Team
- Next.js Team
- ASP.NET Core Team

## 📞 Suporte

Para questões e suporte:

- Abra uma [Issue](https://github.com/vitorbretz/wortkshop-DevOps-na-nuvem/issues)
- Consulte a [Documentação](docs/)
- Verifique os [ADRs](docs/architecture/)

---

**Nota**: Este projeto é para fins educacionais e demonstração. Para uso em produção, revise e ajuste conforme necessidades de segurança e compliance da sua organização.
