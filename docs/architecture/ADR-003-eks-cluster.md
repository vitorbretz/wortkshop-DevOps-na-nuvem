# ADR-003: Amazon EKS Cluster Implementation

## Status
Proposed

## Context
O projeto precisa de um cluster Kubernetes gerenciado para hospedar aplicações containerizadas. O Amazon EKS (Elastic Kubernetes Service) oferece uma plataforma Kubernetes totalmente gerenciada que integra-se nativamente com os serviços AWS e elimina a necessidade de gerenciar o control plane.

### Requirements
- Cluster Kubernetes para workloads containerizados
- Integração nativa com serviços AWS (IAM, CloudWatch, VPC)
- Alta disponibilidade do control plane (gerenciado pela AWS)
- Escalabilidade para crescimento futuro
- Logs e observabilidade habilitados
- Segurança e controle de acesso granular

### Current State
- VPC já provisionada (ADR-001) com subnets públicas e privadas
- Backend remoto S3 configurado (ADR-002)
- Infraestrutura de rede pronta para receber o cluster

## Decision

### Cluster Configuration
Implementaremos um cluster Amazon EKS com as seguintes características:

#### Kubernetes Version
- **Versão**: 1.33 (latest stable release em July 2026)
- **Justificativa**: Versão mais recente disponível com recursos modernos incluindo:
  - Suporte estável para sidecar containers
  - Topology-aware routing e traffic distribution
  - User namespaces em Linux pods
  - Dynamic resource allocation para network interfaces
  - In-place resource resizing para vertical scaling

#### Control Plane
- **Gerenciado pela AWS**: EKS gerencia automaticamente:
  - Alta disponibilidade (multi-AZ)
  - Patches de segurança
  - Atualizações de versão
  - Backup do etcd
- **Logs habilitados**: Todos os tipos de log do control plane:
  - API server logs
  - Audit logs
  - Authenticator logs
  - Controller manager logs
  - Scheduler logs
- **Destino**: Amazon CloudWatch Logs

#### Authentication Mode
- **Modo**: `API_AND_CONFIG_MAP` (híbrido)
- **Justificativa**: 
  - Permite uso simultâneo de Access Entries (API) e ConfigMap (`aws-auth`)
  - Flexibilidade para migração gradual
  - Suporte a ambos os métodos de gerenciamento de acesso
  - Access Entries é o método moderno recomendado pela AWS
  - ConfigMap mantém compatibilidade com ferramentas existentes

#### Worker Nodes Configuration
- **Tipo**: Managed Node Group
- **Capacity Type**: ON_DEMAND
  - Garantia de disponibilidade
  - Previsibilidade de custos
  - Adequado para workloads de produção
- **Instance Type**: t3.medium
  - 2 vCPUs
  - 4 GB RAM
  - Performance baseline com burst capability
  - Custo-benefício adequado para início
- **Node Count**: 
  - Desired: 2 nodes
  - Minimum: 2 nodes (alta disponibilidade)
  - Maximum: 4 nodes (permite scaling futuro)
- **Placement**: Private subnets (10.0.0.128/26 e 10.0.0.192/26)
  - Segurança: nodes não expostos diretamente
  - Acesso à internet via NAT Gateway
- **AMI Type**: AL2023_x86_64_STANDARD (Amazon Linux 2023)
  - Sistema operacional padrão para novos node groups (desde EKS 1.30)
  - Suporte de longo prazo
  - Otimizado para containers

### IAM Roles and Permissions

#### EKS Cluster IAM Role
Permissões necessárias para o control plane:
- **Managed Policy**: `AmazonEKSClusterPolicy`
  - Gerenciamento de nodes
  - Provisioning de EBS volumes
  - Criação de Load Balancers
  - Integração com KMS para secrets encryption
- **Trust Policy**: Permite que EKS assuma a role
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  }
  ```

#### EKS Node IAM Role
Permissões necessárias para os worker nodes:
- **Managed Policies**:
  - `AmazonEKSWorkerNodePolicy`: Permite nodes se conectarem ao cluster
  - `AmazonEC2ContainerRegistryPullOnly`: Pull de imagens do ECR
  - `AmazonEKS_CNI_Policy`: Gerenciamento de networking (VPC CNI)
- **Trust Policy**: Permite que EC2 assuma a role
  ```json
  {
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  }
  ```

### Access Management

#### Initial Admin Access
- **Current User Access**: Configurar access entry para o usuário IAM atual
  - Type: STANDARD
  - Principal ARN: ARN do usuário que está executando o Terraform
  - Access Policy: `AmazonEKSClusterAdminPolicy`
  - Permite acesso administrativo completo ao cluster via kubectl

#### Access Entry Configuration
Garantir que o usuário atual tenha acesso administrativo:
```hcl
# Access entry será criado automaticamente para o creator do cluster
# Adicionar explicitamente o usuário atual como admin
```

### Network Integration
- **VPC**: Usar VPC existente (ADR-001)
- **Subnets**: 
  - Control Plane Endpoint: Acesso via subnets públicas e privadas
  - Worker Nodes: Private subnets apenas
- **Security Groups**:
  - Cluster security group: Gerenciado pelo EKS
  - Node security group: Gerenciado pelo EKS
  - Comunicação entre control plane e nodes automática

### Add-ons
Instalar add-ons essenciais (versões latest compatíveis):
- **vpc-cni**: Networking plugin (AWS VPC CNI)
- **kube-proxy**: Network proxy
- **coredns**: DNS interno do cluster
- **eks-pod-identity-agent**: Para EKS Pod Identity (recomendado)

### Tags
Aplicar tags consistentes para governança:
```hcl
{
  Project     = "dvn-workshop"
  Environment = "dev"
  ManagedBy   = "Terraform"
  ADR         = "ADR-003"
  Component   = "eks-cluster"
}
```

## Implementation Plan

### Stack Organization
- **Stack Name**: `02-eks-cluster-stack`
- **Location**: `terraform/02-eks-cluster-stack/`
- **Backend**: S3 remote backend (key: `02-eks-cluster-stack/terraform.tfstate`)

### File Structure
Seguir convenções estabelecidas (ADR-002, Naming Conventions):
```
terraform/02-eks-cluster-stack/
├── versions.tf                    # Terraform version, providers, backend
├── provider.tf                    # AWS provider configuration
├── data.tf                        # Data sources (VPC, subnets, current user)
├── locals.tf                      # Local values e computed values
├── variables.tf                   # Input variables
├── terraform.tfvars               # Variable values
├── terraform.tfvars.example       # Example variable values
├── outputs.tf                     # Output values
├── iam-cluster-role.tf           # EKS cluster IAM role
├── iam-node-role.tf              # EKS node IAM role
├── eks-cluster.tf                # EKS cluster resource
├── eks-node-group.tf             # Managed node group
├── eks-addons.tf                 # EKS add-ons
├── eks-access-entry.tf           # Access entries configuration
└── security-groups.tf            # Additional security groups (if needed)
```

### Variable Structure
Usar complex objects conforme best practices:
```hcl
variable "eks_cluster" {
  type = object({
    name    = string
    version = string
    
    endpoint_access = object({
      private = bool
      public  = bool
      public_access_cidrs = list(string)
    })
    
    logging = object({
      enabled = bool
      types   = list(string)
    })
    
    authentication_mode = string
  })
}

variable "node_group" {
  type = object({
    name          = string
    instance_types = list(string)
    capacity_type = string
    
    scaling = object({
      desired_size = number
      min_size     = number
      max_size     = number
    })
    
    disk_size = number
    ami_type  = string
  })
}
```

### Dependencies
- **Input Dependencies**: 
  - VPC ID (from networking stack)
  - Private subnet IDs (from networking stack)
  - Public subnet IDs (from networking stack - para endpoint)
- **Output Dependencies**: 
  - Cluster endpoint
  - Cluster certificate authority
  - Cluster security group ID
  - Node group details

### Data Sources Required
```hcl
# Obter informações da VPC existente
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = ["dvn-workshop-dev-vpc"]
  }
}

# Obter subnets privadas
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  filter {
    name   = "tag:Type"
    values = ["private"]
  }
}

# Obter usuário atual para access entry
data "aws_caller_identity" "current" {}
```

## Consequences

### Benefits
1. **Managed Control Plane**: AWS gerencia toda complexidade do control plane
2. **High Availability**: Control plane multi-AZ automático
3. **Security**: 
   - Integração nativa com IAM
   - Dual authentication mode para flexibilidade
   - Logs completos para auditoria
   - Nodes em private subnets
4. **Observability**: Logs centralizados no CloudWatch
5. **Scalability**: Fácil adicionar/remover nodes e node groups
6. **Cost Optimization**: 
   - T3.medium com burstable performance
   - Pay-per-use para control plane ($0.10/hour)
   - ON_DEMAND nodes para previsibilidade

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Custo do NAT Gateway para nodes privados | Médio | Já está provisionado (ADR-001), custo compartilhado |
| Nodes insuficientes para workload | Alto | Configurar auto-scaling para até 4 nodes |
| Access management complexity | Médio | Usar API_AND_CONFIG_MAP para flexibilidade |
| Versão Kubernetes desatualizada | Baixo | Usar versão 1.33 (latest), planejar upgrades regulares |
| Perda de acesso administrativo | Alto | Configurar access entry explícito para usuário atual |

### Costs (Estimativa Mensal)
- **EKS Control Plane**: $72/mês ($0.10/hora)
- **2x t3.medium ON_DEMAND**: ~$60/mês (2 × $0.0416/hora × 730h)
- **CloudWatch Logs**: ~$5/mês (estimativa)
- **EBS Volumes** (20GB cada): ~$4/mês (2 × $0.10/GB × 20GB)
- **Data Transfer**: Variável
- **Total Estimado**: ~$141/mês

### Trade-offs
1. **ON_DEMAND vs SPOT**: 
   - Escolha: ON_DEMAND
   - Trade-off: Maior custo, mas maior previsibilidade e disponibilidade
2. **t3.medium vs larger**: 
   - Escolha: t3.medium
   - Trade-off: Menor capacidade individual, mas suficiente para início e cost-effective
3. **2 vs 3+ nodes**: 
   - Escolha: 2 nodes
   - Trade-off: Menor resiliência, mas permite scaling até 4 quando necessário
4. **API_AND_CONFIG_MAP vs API only**:
   - Escolha: Hybrid mode
   - Trade-off: Mais complexidade, mas maior flexibilidade

## References
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes 1.33 Release Notes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.33.md)
- [EKS Cluster IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/cluster-iam-role.html)
- [EKS Node IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html)
- [Grant IAM Access to Kubernetes APIs](https://docs.aws.amazon.com/eks/latest/userguide/grant-k8s-access.html)
- ADR-001: VPC Network Architecture
- ADR-002: Terraform Remote Backend
- Terraform Naming Conventions
- Terraform Variable Best Practices

## Notes
- Este ADR assume que a VPC da ADR-001 já está provisionada
- O cluster será criado em uma nova stack independente (02-eks-cluster-stack)
- A autenticação híbrida permite transição gradual para Access Entries
- Node groups em private subnets requerem NAT Gateway (já provisionado)
- Add-ons essenciais serão instalados automaticamente nas versões latest compatíveis
- O usuário que criar o cluster terá acesso admin automático via access entry
- Planeje upgrades regulares de versão Kubernetes (EKS mantém suporte por ~14 meses)
