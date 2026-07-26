# ADR-004: GitHub Actions with AWS OIDC Authentication

## Status
Proposed

## Context

O projeto necessita de um pipeline de CI/CD para automatizar o build, teste e deployment de aplicações. O GitHub Actions será usado como plataforma de CI/CD, mas precisamos de uma forma segura de autenticar com a AWS para realizar operações como push de imagens Docker para o ECR.

### Problemas com Credenciais Estáticas
- ❌ **Segurança**: Access keys armazenadas como secrets podem ser comprometidas
- ❌ **Rotação**: Credenciais de longo prazo requerem rotação manual
- ❌ **Auditoria**: Difícil rastrear qual workflow usou qual credencial
- ❌ **Escopo**: Access keys têm permissões amplas sem controle granular por workflow
- ❌ **Vazamento**: Risco de exposição em logs ou code commits

### Requisitos de Negócio
- Autenticação segura do GitHub Actions com AWS
- Permissões mínimas necessárias (least privilege)
- Sem credenciais de longo prazo
- Auditoria completa de ações realizadas
- Suporte para múltiplos repositórios e branches

### Requisitos Técnicos
- OIDC (OpenID Connect) integration entre GitHub e AWS
- IAM Role com trust relationship para GitHub
- Tokens temporários com duração limitada
- Permissões específicas para:
  - ECR (push/pull de imagens Docker)
  - EKS (deployment de aplicações)
- CloudTrail logging para auditoria
- Região: us-east-1

## Decision

Implementaremos GitHub Actions OIDC Provider no AWS IAM para autenticação federada:

### Componentes Principais

#### 1. OIDC Provider no AWS IAM
```hcl
Provider URL: https://token.actions.githubusercontent.com
Audience: sts.amazonaws.com
Thumbprint: Automático via TLS certificate
```

Benefícios:
- Tokens JWT temporários
- Validação automática de identidade
- Sem necessidade de secrets no GitHub

#### 2. IAM Role para GitHub Actions
```hcl
Trust Policy: 
  - Principal: OIDC Provider (token.actions.githubusercontent.com)
  - Conditions:
    - StringEquals: token.actions.githubusercontent.com:aud = "sts.amazonaws.com"
    - StringLike: token.actions.githubusercontent.com:sub = "repo:ORG/REPO:*"
```

Permissões Attached:
- **ECR Permissions**:
  ```json
  {
    "Effect": "Allow",
    "Action": [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ],
    "Resource": [
      "arn:aws:ecr:us-east-1:ACCOUNT_ID:repository/dvn-workshop/*"
    ]
  }
  ```

#### 3. GitHub Workflow Configuration
```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read   # Required for checkout

jobs:
  build:
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-role
          aws-region: us-east-1
          
      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build and push
        run: |
          docker build -t $ECR_REGISTRY/repo:tag .
          docker push $ECR_REGISTRY/repo:tag
```

### Authentication Flow

```
┌──────────────┐                 ┌──────────────┐                 ┌──────────────┐
│   GitHub     │                 │     AWS      │                 │     ECR      │
│   Actions    │                 │   IAM/STS    │                 │  Registry    │
└──────┬───────┘                 └──────┬───────┘                 └──────┬───────┘
       │                                │                                │
       │ 1. Request OIDC token          │                                │
       ├────────────────────────────────>                                │
       │                                │                                │
       │ 2. Return JWT token            │                                │
       <────────────────────────────────┤                                │
       │                                │                                │
       │ 3. AssumeRoleWithWebIdentity   │                                │
       ├────────────────────────────────>                                │
       │                                │                                │
       │    3a. Validate JWT token      │                                │
       │    3b. Check trust policy      │                                │
       │    3c. Issue temp credentials  │                                │
       │                                │                                │
       │ 4. Return temporary creds      │                                │
       <────────────────────────────────┤                                │
       │    (Access Key, Secret, Token) │                                │
       │    (Valid for 1 hour)          │                                │
       │                                │                                │
       │ 5. GetAuthorizationToken       │                                │
       ├────────────────────────────────────────────────────────────────>│
       │                                │                                │
       │ 6. Return ECR login token      │                                │
       <────────────────────────────────────────────────────────────────┤
       │                                │                                │
       │ 7. Docker build & push         │                                │
       ├────────────────────────────────────────────────────────────────>│
       │                                │                                │
```

### Security Characteristics

**Token Lifetime**:
- Default: 1 hour
- Configurable: 15 minutos a 12 horas
- Recomendação: 1 hora (suficiente para builds)

**Scope Restrictions**:
```yaml
Permitido:
- repo:vitorbretz/workshop-DevOps-na-nuvem:*
- repo:vitorbretz/workshop-DevOps-na-nuvem:ref:refs/heads/main
- repo:vitorbretz/workshop-DevOps-na-nuvem:ref:refs/tags/*

Negado:
- Outros repositórios
- Pull requests de forks (sem acesso)
```

**Auditoria via CloudTrail**:
```json
{
  "eventName": "AssumeRoleWithWebIdentity",
  "userIdentity": {
    "type": "WebIdentityUser",
    "principalId": "arn:aws:sts::ACCOUNT:assumed-role/github-actions-role",
    "userName": "repo:ORG/REPO:ref:refs/heads/main",
    "identityProvider": "token.actions.githubusercontent.com"
  }
}
```

## Rationale

### Por que OIDC ao invés de Access Keys?

| Aspecto | OIDC | Access Keys |
|---------|------|-------------|
| **Segurança** | ✅ Tokens temporários | ❌ Credenciais permanentes |
| **Rotação** | ✅ Automática (por token) | ❌ Manual |
| **Escopo** | ✅ Granular por repo/branch | ❌ Amplo |
| **Auditoria** | ✅ CloudTrail com contexto | ⚠️ Sem contexto de origem |
| **Vazamento** | ✅ Tokens expiram | ❌ Risco permanente |
| **Compliance** | ✅ Best practice | ❌ Não recomendado |

### Alternativas Consideradas

#### Alternativa 1: GitHub Secrets com Access Keys
```
Prós:
  - Simples de configurar
  - Funciona imediatamente
Contras:
  - Credenciais de longo prazo
  - Risco de vazamento
  - Difícil auditoria
  - Rotação manual
```
**Por que não**: Não atende requisitos de segurança modernos.

#### Alternativa 2: Self-hosted Runners com Instance Profiles
```
Prós:
  - Sem credenciais explícitas
  - IAM role nativa
Contras:
  - Custo de EC2 instances
  - Gerenciamento de infraestrutura
  - Scaling complexo
  - Manutenção adicional
```
**Por que não**: Overhead operacional desnecessário.

#### Alternativa 3: Terraform Cloud / Atlantis
```
Prós:
  - UI para gerenciar state
  - Policy enforcement
Contras:
  - Custo adicional ($20+/user/mês)
  - Vendor lock-in
  - Menos controle
```
**Por que não**: Queremos solução nativa e sem custos extras.

## Consequences

### Positive
- ✅ Zero credenciais de longo prazo armazenadas
- ✅ Tokens temporários (1 hora de validade)
- ✅ Princípio de least privilege
- ✅ Auditoria completa via CloudTrail
- ✅ Proteção contra forks maliciosos
- ✅ Compliance com security best practices
- ✅ Sem custos adicionais (OIDC é free)
- ✅ Suporte oficial da AWS e GitHub
- ✅ Fácil adicionar novos repositórios

### Negative
- ⚠️ Configuração inicial mais complexa
- ⚠️ Requer Terraform para provisionar OIDC provider
- ⚠️ Trust policy precisa ser mantida atualizada
- ⚠️ Workflows precisam ter `id-token: write` permission
- ⚠️ Debug pode ser mais complexo que access keys

### Neutral
- 📊 CloudTrail logs crescem (mais eventos)
- 📊 Necessário entender OIDC e JWT tokens
- 📊 Workflows devem tratar role assumption failures

## Implementation Guidance

### Stack Organization
- **Stack Name**: `03-github-oidc-stack`
- **Location**: `terraform/03-github-oidc-stack/`
- **Backend**: S3 remote backend (key: `03-github-oidc/terraform.tfstate`)

### File Structure
```
terraform/03-github-oidc-stack/
├── versions.tf                 # Terraform versions
├── provider.tf                 # AWS provider + backend
├── variables.tf                # Input variables
├── terraform.tfvars           # Variable values
├── terraform.tfvars.example   # Example values
├── outputs.tf                 # Outputs (role ARN)
├── oidc-provider.tf          # OIDC provider resource
├── iam-role.tf               # IAM role + trust policy
├── iam-policy-ecr.tf         # ECR permissions policy
└── README.md                 # Documentation
```

### Required Variables
```hcl
variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs"
  type        = list(string)
}
```

### Terraform Resources

#### OIDC Provider
```hcl
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = [
    "sts.amazonaws.com",
  ]
  
  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint,
  ]
  
  tags = {
    Name = "github-actions-oidc"
  }
}
```

#### IAM Role
```hcl
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  
  tags = {
    Name = "github-actions-role"
  }
}
```

#### ECR Policy
```hcl
data "aws_iam_policy_document" "github_actions_ecr" {
  statement {
    sid    = "ECRAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }
  
  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_policy" "github_actions_ecr" {
  name        = "github-actions-ecr-policy"
  description = "Policy for GitHub Actions to push to ECR"
  policy      = data.aws_iam_policy_document.github_actions_ecr.json
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}
```

### GitHub Secrets Configuration

Após aplicar o Terraform, configurar no GitHub:

1. Ir em **Settings** > **Secrets and variables** > **Actions**
2. Adicionar secret:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: Output do Terraform `github_actions_role_arn`

### GitHub Workflow Template

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  id-token: write   # Required for OIDC
  contents: read    # Required for checkout

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: 910661159891.dkr.ecr.us-east-1.amazonaws.com
  ECR_REPOSITORY: dvn-workshop/frontend

jobs:
  build-and-push:
    name: Build and Push to ECR
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
          role-session-name: GitHubActions-${{ github.run_id }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build, tag, and push image
        env:
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
```

### Outputs Required
```hcl
output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
```

## Security Best Practices

### 1. Trust Policy Scope
```hcl
# ✅ BOM: Restringir por repository
condition {
  test     = "StringLike"
  variable = "token.actions.githubusercontent.com:sub"
  values   = ["repo:ORG/REPO:*"]
}

# ✅ MELHOR: Restringir por branch específico
condition {
  test     = "StringEquals"
  variable = "token.actions.githubusercontent.com:sub"
  values   = ["repo:ORG/REPO:ref:refs/heads/main"]
}

# ❌ EVITAR: Permitir qualquer repositório
condition {
  test     = "StringLike"
  variable = "token.actions.githubusercontent.com:sub"
  values   = ["*"]
}
```

### 2. Session Duration
```yaml
# Configurar sessão curta (mínimo necessário)
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: us-east-1
    role-duration-seconds: 3600  # 1 hora (default)
```

### 3. Logging e Monitoring
- Habilitar CloudTrail para região us-east-1
- Criar CloudWatch alarm para `AssumeRoleWithWebIdentity` failures
- Monitorar tentativas de acesso suspeitas

### 4. Least Privilege
```hcl
# Permitir APENAS ações necessárias
actions = [
  "ecr:GetAuthorizationToken",      # Login
  "ecr:BatchCheckLayerAvailability", # Check layers
  "ecr:PutImage",                   # Push image
  "ecr:InitiateLayerUpload",        # Upload
  "ecr:UploadLayerPart",            # Upload
  "ecr:CompleteLayerUpload"         # Finalize
]

# NÃO dar permissões amplas como:
# - ecr:*
# - ecr:DeleteRepository
# - ecr:SetRepositoryPolicy
```

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Causa**: Trust policy incorreta ou token inválido

**Solução**:
1. Verificar `id-token: write` permission no workflow
2. Verificar trust policy permite o repository correto
3. Verificar OIDC provider thumbprint está correto

### Error: "AccessDenied when calling ECR:GetAuthorizationToken"

**Causa**: IAM policy não tem permissão ECR

**Solução**:
1. Verificar policy está attached à role
2. Verificar action `ecr:GetAuthorizationToken` está presente
3. Resource pode ser "*" para GetAuthorizationToken

### Error: "Repository does not exist"

**Causa**: ECR repository ARN incorreto na policy

**Solução**:
1. Listar repositories: `aws ecr describe-repositories`
2. Atualizar `ecr_repository_arns` variable
3. Re-apply Terraform

## Cost Optimization

**Custos Estimados:**
```
OIDC Provider: $0 (free)
IAM Role: $0 (free)
CloudTrail: ~$2/mês (se habilitado)
API Calls (STS): Negligível (<$0.01)

Total: ~$0-2/mês
```

## Monitoring & Observability

### CloudWatch Metrics
```
AWS/IAM
- AssumeRoleWithWebIdentity (count)
- AssumeRoleWithWebIdentity (errors)
```

### Recommended Alarms
```hcl
# Failed role assumptions
Metric: AssumeRoleWithWebIdentity (errors)
Threshold: > 5 failures/5min
Action: SNS notification

# Unusual access patterns
Metric: AssumeRoleWithWebIdentity (count)
Threshold: > 50 calls/hour
Action: SNS notification
```

### CloudTrail Query Example
```json
{
  "eventName": "AssumeRoleWithWebIdentity",
  "userIdentity.principalId": "arn:aws:sts::ACCOUNT:assumed-role/github-actions-role/*",
  "errorCode": "AccessDenied"
}
```

## Future Enhancements

1. **Short-term (1-3 meses)**
   - Adicionar permissões EKS para deployment automático
   - Implementar múltiplos roles para diferentes repositories
   - Configurar CloudWatch dashboards

2. **Medium-term (3-6 meses)**
   - Adicionar environments (staging, production) com roles separadas
   - Implementar approval workflows para produção
   - Integrar com AWS Secrets Manager

3. **Long-term (6-12 meses)**
   - Multi-region OIDC setup
   - Cross-account access para multi-account strategy
   - Advanced monitoring com AWS Security Hub

## References

### AWS Documentation
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Identity Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [AssumeRoleWithWebIdentity API](https://docs.aws.amazon.com/STS/latest/APIReference/API_AssumeRoleWithWebIdentity.html)

### GitHub Documentation
- [Security hardening with OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)

### Related ADRs
- ADR-002: Terraform Remote Backend with S3
- ADR-005: ArgoCD for GitOps Deployments (planned)

---

**Document Control**
- Version: 1.0
- Created: 2026-07-26
- Author: DevOps Team
- Status: Proposed
- Next Review: After implementation
- Depends On: ADR-002 (S3 Backend)
- Required By: ADR-005 (ArgoCD GitOps)
