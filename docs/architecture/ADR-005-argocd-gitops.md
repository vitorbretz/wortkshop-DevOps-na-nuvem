# ADR-005: ArgoCD for GitOps-Based Deployment

## Status
Proposed

## Context

O projeto possui pipeline de CI/CD via GitHub Actions (ADR-004) que constrói e envia imagens Docker para ECR. Agora precisamos de uma solução para deployment automatizado dessas aplicações no cluster EKS de forma declarativa, auditável e com capacidade de self-healing.

### Problemas com Deployment Imperativo
- ❌ **Drift de Configuração**: Estado real do cluster diverge da configuração desejada
- ❌ **Falta de Auditoria**: Difícil rastrear quem deployou o quê e quando
- ❌ **Rollbacks Complexos**: Processo manual e propenso a erros
- ❌ **Múltiplas Fontes de Verdade**: Git, Terraform, kubectl commands
- ❌ **Sem Self-Healing**: Mudanças manuais não são revertidas automaticamente
- ❌ **Difícil Colaboração**: Não há revisão de mudanças via PR antes do deploy

### Requisitos de Negócio
- Deployment automatizado de aplicações Kubernetes
- Git como única fonte de verdade para configurações
- Auditoria completa de mudanças (via Git history)
- Capacidade de rollback rápido e confiável
- Self-healing automático do cluster
- Sincronização contínua entre Git e cluster
- Notificações de status de deployment


### Requisitos Técnicos
- GitOps engine rodando no cluster EKS
- Sincronização automática entre repositório Git e cluster
- Suporte para Kustomize e Helm (futuro)
- Integração com GitHub para SSO e webhooks
- Health checks automáticos de recursos Kubernetes
- Região: us-east-1 (EKS cluster já provisionado)

## Decision

Implementaremos ArgoCD como plataforma de continuous delivery baseada em GitOps para gerenciar deployments de aplicações no cluster EKS.

### Componentes Principais

1. **ArgoCD Server**
   - Deployment no namespace `argocd` no EKS
   - API server e UI web para gerenciamento
   - Sincronização contínua com repositório Git
   - Instalação via Helm chart oficial ou manifests

2. **Application Controller**
   - Monitora repositório Git em busca de mudanças
   - Compara estado desejado (Git) vs estado atual (cluster)
   - Aplica mudanças automaticamente (auto-sync habilitado)
   - Executa health checks de recursos

3. **Repository Server**
   - Acessa repositórios Git (GitHub)
   - Renderiza templates (Kustomize, Helm)
   - Gera manifestos Kubernetes finais


4. **Dex (OAuth2)**
   - SSO integration com GitHub
   - RBAC baseado em GitHub teams/organizations
   - Authentication centralizado

5. **Redis**
   - Cache para estado de aplicações
   - Melhoria de performance
   - Reduz load no Git repository

### ArgoCD Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       GitHub Repository                      │
│                                                              │
│  kubernetes/                                                 │
│  ├── base/                    (Kustomize base configs)      │
│  ├── overlays/                                               │
│  │   ├── dev/                 (Dev environment)             │
│  │   └── prod/                (Prod environment)            │
│  └── apps/                                                   │
│      ├── youtube-frontend.yaml                               │
│      └── youtube-backend.yaml                                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Git Pull (every 3 minutes or webhook)
                     │
┌────────────────────▼────────────────────────────────────────┐
│                    ArgoCD in EKS Cluster                     │
│                                                              │
│  ┌──────────────────────────────────────────────┐           │
│  │         ArgoCD Application Controller         │           │
│  │  - Fetch manifests from Git                  │           │
│  │  - Render Kustomize/Helm templates           │           │
│  │  - Compare desired vs actual state           │           │
│  │  - Auto-sync if enabled                      │           │
│  └──────────────┬───────────────────────────────┘           │
│                 │                                            │
│                 │ Apply/Update                               │
│                 │                                            │
│  ┌──────────────▼───────────────────────────────┐           │
│  │          Kubernetes API Server                │           │
│  └──────────────┬───────────────────────────────┘           │
│                 │                                            │
│                 │ Create/Update Resources                    │
│                 │                                            │
│  ┌──────────────▼───────────────────────────────┐           │
│  │    Application Workloads (Pods, Services)    │           │
│  │  - youtube-frontend deployment                │           │
│  │  - youtube-backend deployment                 │           │
│  │  - Services, Ingress, ConfigMaps, etc.       │           │
│  └──────────────────────────────────────────────┘           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```


### GitOps Workflow

```
Developer Workflow:
1. Developer commits K8s manifest changes to Git
2. Opens Pull Request for review
3. Team reviews declarative configuration
4. PR merged to main branch

ArgoCD Workflow:
5. ArgoCD detects Git commit (polling or webhook)
6. Fetches latest manifests from Git
7. Compares with current cluster state
8. Applies changes automatically (if auto-sync enabled)
9. Reports sync status (Synced, OutOfSync, Failed)
10. Self-heals if manual changes are made to cluster
```

### ArgoCD Application Configuration

**Application Manifest Example:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: youtube-live-app-frontend
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main
    path: kubernetes/overlays/dev/frontend
  
  destination:
    server: https://kubernetes.default.svc
    namespace: dvn-workshop-apps
  
  syncPolicy:
    automated:
      prune: true        # Remove resources deleted from Git
      selfHeal: true     # Revert manual changes
      allowEmpty: false  # Prevent accidental deletion of all resources
    
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  revisionHistoryLimit: 10
```


### Key Configuration Decisions

#### 1. Auto-Sync Policy
- **Enabled**: `automated.selfHeal: true`
- **Justificativa**: 
  - Git é a única fonte de verdade
  - Mudanças manuais são automaticamente revertidas
  - Garante consistência cluster ↔ Git
  - Reduz configuration drift

#### 2. Prune Strategy
- **Enabled**: `automated.prune: true`
- **Justificativa**:
  - Recursos deletados do Git são removidos do cluster
  - Evita "orphaned resources"
  - Mantém cluster limpo

#### 3. Sync Options
- **CreateNamespace**: Cria namespace automaticamente se não existir
- **PruneLast**: Deleta recursos após sync bem-sucedido (evita downtime)
- **PrunePropagationPolicy=foreground**: Aguarda dependências serem deletadas

#### 4. Retry Policy
- **Limit**: 5 tentativas
- **Backoff**: Exponential (5s → 10s → 20s → 40s → 3m max)
- **Justificativa**: Transient failures (network, API rate limits)

#### 5. Repository Structure
Usar Kustomize para gerenciar múltiplos ambientes:
```
kubernetes/
├── base/
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── backend/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── kustomization.yaml
│
└── overlays/
    ├── dev/
    │   ├── frontend/
    │   │   ├── kustomization.yaml
    │   │   └── patch-replicas.yaml
    │   └── backend/
    │       └── kustomization.yaml
    └── prod/
        ├── frontend/
        └── backend/
```


## Rationale

### Por que ArgoCD?

| Critério | ArgoCD | Flux | Jenkins X |
|----------|---------|------|-----------|
| **Adoção** | Alta (CNCF Graduated) | Alta (CNCF Graduated) | Média |
| **UI** | Web UI completa | CLI principalmente | Web UI limitada |
| **Multi-tenancy** | Projetos, RBAC granular | Namespaces | Environments |
| **Rollbacks** | UI com um clique | CLI commands | Manual |
| **Health Checks** | Nativos, extensíveis | Básicos | Básicos |
| **SSO** | Dex (OIDC, SAML, LDAP) | Não nativo | Limitado |
| **Helm Support** | ✅ Native | ✅ Native | ✅ Native |
| **Kustomize** | ✅ Native | ✅ Native | ❌ Limitado |
| **App of Apps** | ✅ Sim | ⚠️ Via Kustomize | ❌ Não |
| **Learning Curve** | Baixa (UI intuitiva) | Média (CLI-heavy) | Alta |

**Vencedor: ArgoCD** - Melhor combinação de features, UI, e community support.

### Vantagens Específicas do ArgoCD

1. **Declarative GitOps**
   - Git como single source of truth
   - Todas mudanças rastreáveis via Git history
   - Pull Requests = change management process
   - Auditoria completa via Git commits

2. **Self-Healing**
   - Detecta drift automaticamente
   - Reverte mudanças manuais não autorizadas
   - Mantém cluster sempre sincronizado com Git
   - Reduz operational toil

3. **Rollback Simplificado**
   - Rollback = revert Git commit
   - Histórico completo de deployments
   - One-click rollback via UI
   - Automated ou manual rollback strategies

4. **Observabilidade**
   - UI visual do status de aplicações
   - Health status de cada recurso Kubernetes
   - Sync status em tempo real
   - Resource tree visualization

5. **Multi-Environment Support**
   - Kustomize overlays para dev/staging/prod
   - Single base, múltiplos overlays
   - DRY principle aplicado
   - Consistent configurations


### Alternativas Consideradas

#### Alternativa 1: Flux CD
```
Prós:
  - CNCF Graduated (mesmo nível ArgoCD)
  - GitOps nativo
  - Lightweight, menos componentes
  - Helm Controller robusto
Contras:
  - Sem UI web (CLI apenas)
  - Debugging mais difícil
  - Rollbacks via CLI
  - Menor visibilidade de estado
```
**Por que não escolhemos**: Falta de UI torna operação e troubleshooting mais complexos.

#### Alternativa 2: Kubectl Apply via CI/CD
```
Prós:
  - Simples, sem ferramentas adicionais
  - Controle total via scripts
  - Fácil integração com GitHub Actions
Contras:
  - Não é GitOps (push model)
  - Sem self-healing
  - Sem drift detection
  - Rollbacks manuais
  - Credentials necessárias no CI/CD
```
**Por que não escolhemos**: Não atende filosofia GitOps, sem self-healing.

#### Alternativa 3: Spinnaker
```
Prós:
  - Multi-cloud support
  - Advanced deployment strategies (blue-green, canary)
  - UI rica
Contras:
  - Complexidade muito alta
  - Overhead operacional significativo
  - Overkill para projeto atual
  - Steep learning curve
```
**Por que não escolhemos**: Complexidade excessiva para necessidades atuais.

#### Alternativa 4: Jenkins X
```
Prós:
  - Integração profunda com Jenkins
  - Automated CI/CD pipelines
Contras:
  - GitOps menos maduro
  - UI limitada
  - Overhead de Jenkins
  - Community menor que ArgoCD/Flux
```
**Por que não escolhemos**: CI/CD já resolvido com GitHub Actions (ADR-004).


## Consequences

### Positive
- ✅ **Git as Single Source of Truth**: Configuração centralizada e versionada
- ✅ **Auditoria Completa**: Git history = deployment history
- ✅ **Self-Healing Automático**: Cluster sempre sincronizado com Git
- ✅ **Rollback Simples**: Revert commit = rollback deployment
- ✅ **Drift Detection**: Identifica mudanças manuais não autorizadas
- ✅ **Pull Request Workflow**: Code review para mudanças de infraestrutura
- ✅ **Declarative**: Estado desejado definido claramente
- ✅ **Multi-Environment**: Kustomize overlays para dev/staging/prod
- ✅ **Observabilidade**: UI visual de estado de aplicações
- ✅ **RBAC Granular**: Controle de acesso por projeto/aplicação
- ✅ **Health Checks**: Validação automática de recursos
- ✅ **Sem Credentials em CI/CD**: ArgoCD puxa do Git (pull model)

### Negative
- ⚠️ **Componente Adicional**: ArgoCD precisa ser gerenciado no cluster
- ⚠️ **Learning Curve**: Time precisa aprender GitOps concepts
- ⚠️ **Sync Latency**: Polling interval de 3 minutos (configurável)
- ⚠️ **Git Dependency**: Se GitHub cair, deploys param temporariamente
- ⚠️ **Complexidade Inicial**: Setup de RBAC, SSO, projetos
- ⚠️ **Resource Overhead**: ArgoCD consome recursos do cluster (~500MB RAM)

### Neutral
- 📊 Necessário manter manifests Kubernetes no Git organizados
- 📊 Webhook setup recomendado para sync instantâneo
- 📊 Monitoramento de ArgoCD itself necessário
- 📊 Backup de ArgoCD CRDs e Application definitions

