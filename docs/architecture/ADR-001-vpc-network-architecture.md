# ADR-001: AWS VPC Network Architecture

## Status
Proposed

## Context

Precisamos estabelecer uma arquitetura de rede na AWS que forneça isolamento entre recursos públicos e privados, com conectividade controlada para a Internet. A arquitetura deve suportar workloads que requerem acesso direto à Internet (recursos públicos) e workloads que necessitam apenas de conectividade de saída (recursos privados).

### Requisitos de Negócio
- Segregação entre recursos públicos e privados
- Conectividade de saída para recursos privados (ex: atualizações de software, APIs externas)
- Otimização de custos com infraestrutura de rede
- Preparação para crescimento futuro em múltiplas Availability Zones

### Requisitos Técnicos
- VPC com CIDR block: `10.0.0.0/24` (254 endereços IP utilizáveis)
- 2 Subnets públicas: `10.0.0.0/26` (62 IPs), `10.0.0.64/26` (62 IPs)
- 2 Subnets privadas: `10.0.0.128/26` (62 IPs), `10.0.0.192/26` (62 IPs)
- NAT Gateway único para conectividade de saída das subnets privadas
- Região: us-east-1

### Análise de Capacidade
```
VPC CIDR: 10.0.0.0/24
├── Subnet Pública 1 (AZ-a): 10.0.0.0/26    → 62 IPs utilizáveis (64 - 2 reservados AWS)
├── Subnet Pública 2 (AZ-b): 10.0.0.64/26   → 62 IPs utilizáveis
├── Subnet Privada 1 (AZ-a): 10.0.0.128/26  → 62 IPs utilizáveis
└── Subnet Privada 2 (AZ-b): 10.0.0.192/26  → 62 IPs utilizáveis

Total IPs disponíveis: 248 IPs (254 - 5 reservados AWS por subnet × 4 subnets)
```

## Decision

Implementaremos uma arquitetura VPC multi-AZ com as seguintes características:

### Componentes Principais

1. **VPC**
   - CIDR: `10.0.0.0/24`
   - DNS hostnames: Habilitado
   - DNS resolution: Habilitado
   - Região: us-east-1

2. **Subnets Públicas** (2)
   - Distribuídas em 2 Availability Zones (us-east-1a, us-east-1b)
   - Associadas a tabela de rotas com rota para Internet Gateway
   - Auto-assign public IPv4: Habilitado
   - CIDRs: `10.0.0.0/26`, `10.0.0.64/26`

3. **Subnets Privadas** (2)
   - Distribuídas nas mesmas 2 Availability Zones
   - Associadas a tabela de rotas com rota para NAT Gateway
   - Sem IPs públicos automáticos
   - CIDRs: `10.0.0.128/26`, `10.0.0.192/26`

4. **Internet Gateway**
   - Único IGW anexado à VPC
   - Permite conectividade bidirecional para subnets públicas

5. **NAT Gateway**
   - **Um único NAT Gateway** na primeira subnet pública (us-east-1a)
   - Elastic IP associado
   - Roteamento de todas as subnets privadas através deste NAT

6. **Route Tables**
   - **Public Route Table**: Rota default (0.0.0.0/0) → Internet Gateway
   - **Private Route Table**: Rota default (0.0.0.0/0) → NAT Gateway

## Rationale

### Por que esta arquitetura?

1. **Multi-AZ para Alta Disponibilidade**
   - Distribuir subnets em 2 AZs protege contra falhas de zona
   - Permite deployment de aplicações com redundância geográfica

2. **Segregação Público/Privado**
   - Subnets públicas hospedam recursos que precisam ser acessíveis externamente (load balancers, bastion hosts)
   - Subnets privadas hospedam workloads sensíveis (databases, application servers) com zero exposição direta

3. **NAT Gateway Único - Decisão de Trade-off**
   - ✅ **Redução de custos**: Um NAT Gateway custa ~$32/mês + data transfer
   - ✅ **Simplicidade operacional**: Menos componentes para gerenciar
   - ⚠️ **Single Point of Failure**: Se us-east-1a falhar, subnets privadas perdem conectividade de saída
   - ⚠️ **Cross-AZ data transfer charges**: Tráfego da us-east-1b para NAT em us-east-1a incorre custos adicionais (~$0.01/GB)

### Alternativas Consideradas

#### Alternativa 1: NAT Gateway por AZ (Recomendação AWS)
```
Componentes: 2 NAT Gateways (um em cada AZ)
Custo mensal: ~$64 + data transfer
Prós: 
  - Zero ponto único de falha
  - Sem cross-AZ data transfer
  - Alta disponibilidade completa
Contras:
  - Custo 2x maior
  - Maior complexidade na configuração de route tables
```
**Por que não escolhemos**: Para ambientes de desenvolvimento/teste ou workloads não-críticos, o custo adicional não justifica o benefício. Esta decisão deve ser **revista para ambientes de produção**.

#### Alternativa 2: NAT Instance
```
Componentes: EC2 instance rodando NAT
Custo mensal: ~$10-20 (t3.small) + data transfer
Prós:
  - Mais barato
  - Maior controle e customização
Contras:
  - Gerenciamento manual (patching, monitoring, scaling)
  - Menor throughput
  - Não managed pela AWS
  - Ponto único de falha ainda maior
```
**Por que não escolhemos**: NAT Gateway é fully managed, oferece melhor performance e confiabilidade.

#### Alternativa 3: Regional NAT Gateway (Novo em 2024)
```
Componentes: 1 Regional NAT Gateway
Custo mensal: Similar ao NAT Gateway tradicional
Prós:
  - Simplificação operacional
  - Expande automaticamente para AZs conforme workload
  - Não requer public subnets em cada AZ
  - Zonal affinity automática
Contras:
  - Feature mais recente, menos battle-tested
  - Disponibilidade limitada em algumas regiões
```
**Por que não escolhemos (ainda)**: Esta é uma feature promissora para futuras iterações. Recomenda-se avaliar quando houver maior maturidade e casos de uso documentados.

## Consequences

### Positive
- ✅ Arquitetura de rede segura com isolamento público/privado
- ✅ Multi-AZ preparada para workloads resilientes
- ✅ Custo otimizado com NAT Gateway único (~50% economia vs. 2 NATs)
- ✅ Conectividade de saída garantida para recursos privados
- ✅ Espaço de endereçamento adequado (248 IPs) para workloads pequenas a médias
- ✅ Infraestrutura fully managed (NAT Gateway, IGW)

### Negative
- ⚠️ **Single Point of Failure**: Falha na us-east-1a afeta conectividade de saída de todas subnets privadas
- ⚠️ Cross-AZ data transfer costs para tráfego de us-east-1b
- ⚠️ Espaço IP limitado (/24 = ~250 IPs total) - não adequado para ambientes muito grandes
- ⚠️ Não atende requisitos de alta disponibilidade para ambientes críticos de produção

### Neutral
- 📊 Necessidade de monitoramento de utilização de NAT Gateway
- 📊 Considerar VPC Flow Logs para análise de tráfego
- 📊 Revisão futura para migração para Regional NAT Gateway

## Implementation Guidance

### Directory Structure
```
terraform/
├── modules/
│   └── networking/
│       ├── provider.tf              # AWS provider configuration
│       ├── versions.tf              # Terraform and provider versions
│       ├── variables.tf             # Input variables
│       ├── outputs.tf               # Output values
│       ├── locals.tf                # Local values (se necessário)
│       │
│       ├── vpc.tf                   # VPC principal
│       ├── vpc-public-subnets.tf    # Public subnets
│       ├── vpc-private-subnets.tf   # Private subnets
│       ├── vpc-internet-gateway.tf  # Internet Gateway
│       ├── vpc-nat-gateway.tf       # NAT Gateway + Elastic IP
│       ├── vpc-public-route-table.tf    # Public route table + routes + associations
│       └── vpc-private-route-table.tf   # Private route table + routes + associations
│
├── environments/
│   ├── dev/
│   │   ├── provider.tf          # Provider config específico do ambiente
│   │   ├── versions.tf          # Version constraints
│   │   ├── variables.tf         # Environment-specific variables
│   │   ├── terraform.tfvars     # Variable values
│   │   ├── backend.tf           # Remote state configuration
│   │   └── main.tf              # Module invocation
│   ├── staging/
│   │   └── (mesma estrutura)
│   └── prod/
│       └── (mesma estrutura)
│
└── docs/
    ├── architecture/
    │   └── ADR-001-vpc-network-architecture.md
    └── diagrams/
        └── network-diagram.png
```

### Organização de Arquivos Terraform

**Convenção de nomenclatura de arquivos**: `{service}-{resource-type}.tf`

**Exemplos:**
- `vpc.tf` - Recurso principal VPC
- `vpc-public-subnets.tf` - Todas as subnets públicas
- `vpc-private-subnets.tf` - Todas as subnets privadas
- `vpc-internet-gateway.tf` - Internet Gateway
- `vpc-nat-gateway.tf` - NAT Gateway + Elastic IP
- `vpc-public-route-table.tf` - Route table pública, routes e associations
- `vpc-private-route-table.tf` - Route table privada, routes e associations

**Benefícios desta organização:**
- ✅ Fácil navegação - encontre recursos rapidamente pelo nome do arquivo
- ✅ Separação de responsabilidades - cada arquivo tem um propósito claro
- ✅ Revisões de código mais simples - mudanças isoladas por tipo de recurso
- ✅ Manutenção facilitada - modificar um tipo de recurso sem afetar outros

### Required AWS Services
- **Amazon VPC**: Virtual Private Cloud foundation
- **EC2 (Network)**: Internet Gateway, NAT Gateway, Route Tables, Elastic IP
- **CloudWatch**: Para monitoramento de NAT Gateway metrics

### Resource Naming Convention
```
Padrão: <environment>-<project>-<resource-type>-<descriptor>

Exemplos:
- VPC: dev-app-vpc
- Subnets: 
  - dev-app-subnet-public-1a
  - dev-app-subnet-public-1b
  - dev-app-subnet-private-1a
  - dev-app-subnet-private-1b
- NAT Gateway: dev-app-nat-1a
- Internet Gateway: dev-app-igw
- Route Tables:
  - dev-app-rt-public
  - dev-app-rt-private
```

### Tagging Strategy
Todas as resources devem ter as seguintes tags:
```hcl
tags = {
  Environment  = "dev | staging | prod"
  Project      = "nome-do-projeto"
  ManagedBy    = "Terraform"
  CostCenter   = "engineering"
  Owner        = "devops-team"
  ADR          = "ADR-001"
}
```

### Best Practices

1. **VPC Configuration**
   - Habilitar DNS hostnames e DNS resolution
   - Considerar VPC Flow Logs para troubleshooting
   - Usar default DHCP options set

2. **Subnet Design**
   - Sempre usar múltiplas AZs (mínimo 2)
   - Reservar espaço para crescimento futuro
   - Documentar alocação de IPs

3. **NAT Gateway**
   - Monitorar métricas: BytesOutToDestination, BytesInFromSource
   - Configurar CloudWatch alarms para alta utilização
   - Elastic IP deve ter tags adequadas
   - **Importante**: Documentar SLA reduzido devido a NAT único

4. **Route Tables**
   - Explicit subnet associations (não usar default route table)
   - Uma route table pública para ambas subnets públicas
   - Uma route table privada para ambas subnets privadas
   - Nomear claramente para evitar confusão

5. **Security**
   - Network ACLs: Usar default (allow all) inicialmente, restringir conforme necessário
   - Security Groups: Implementar no nível de recurso (EC2, RDS, etc.)
   - Considerar VPC endpoints para serviços AWS (S3, DynamoDB) para evitar tráfego via NAT

### Terraform Code Standards

#### File Organization Rules

**Regra 1: Um arquivo por tipo de recurso**
```
Cada tipo lógico de recurso deve ter seu próprio arquivo com nomenclatura clara:

vpc.tf                        # VPC principal
vpc-public-subnets.tf         # Todas as subnets públicas
vpc-private-subnets.tf        # Todas as subnets privadas
vpc-internet-gateway.tf       # Internet Gateway
vpc-nat-gateway.tf            # NAT Gateway + Elastic IP
vpc-public-route-table.tf     # Public RT + routes + associations
vpc-private-route-table.tf    # Private RT + routes + associations
```

**Regra 2: Naming Conventions**
```hcl
# ARQUIVOS: Use dash (-) e lowercase
vpc-public-subnets.tf         ✅
vpc_public_subnets.tf         ❌
VpcPublicSubnets.tf           ❌

# RECURSOS: Use underscore (_) e lowercase
resource "aws_subnet" "public" {}              ✅
resource "aws_subnet" "public-subnet" {}       ❌
resource "aws_subnet" "publicSubnet" {}        ❌

# VALORES DE ARGUMENTOS: Dash (-) é permitido
tags = {
  Name = "my-vpc-name"        ✅
}
```

**Regra 3: Resource Naming Patterns**
```hcl
# Use "this" para recurso único daquele tipo no módulo
resource "aws_vpc" "this" {}                    ✅
resource "aws_internet_gateway" "this" {}       ✅

# Use nomes descritivos para múltiplos recursos
resource "aws_subnet" "public" {}               ✅
resource "aws_subnet" "private" {}              ✅
resource "aws_route_table" "public" {}          ✅
resource "aws_route_table" "private" {}         ✅

# NÃO repita o tipo no nome
resource "aws_vpc" "main_vpc" {}                ❌
resource "aws_subnet" "public_subnet" {}        ❌
```

#### Example File Contents

**vpc.tf**
```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}
```

**vpc-public-subnets.tf**
```hcl
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
      Type = "public"
    }
  )
}
```

**vpc-private-subnets.tf**
```hcl
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
      Type = "private"
    }
  )
}
```

**vpc-internet-gateway.tf**
```hcl
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-igw"
    }
  )
}
```

**vpc-nat-gateway.tf**
```hcl
resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? 1 : 0
  
  domain = "vpc"
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nat-eip"
    }
  )
  
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0
  
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nat"
    }
  )
  
  depends_on = [aws_internet_gateway.this]
}
```

**vpc-public-route-table.tf**
```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-rt"
      Type = "public"
    }
  )
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

**vpc-private-route-table.tf**
```hcl
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-rt"
      Type = "private"
    }
  )
}

resource "aws_route" "private_nat_gateway" {
  count = var.create_nat_gateway ? 1 : 0
  
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

#### Argument Order Within Resources
```hcl
resource "aws_nat_gateway" "this" {
  # 1. count/for_each (first, with newline after)
  count = var.create_nat_gateway ? 1 : 0
  
  # 2. Required arguments (alphabetically or logically grouped)
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  # 3. Optional arguments
  connectivity_type = "public"
  
  # 4. tags (always before lifecycle/depends_on)
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nat"
    }
  )
  
  # 5. depends_on (if needed)
  depends_on = [aws_internet_gateway.this]
  
  # 6. lifecycle (last)
  lifecycle {
    create_before_destroy = true
  }
}
```

### Security Considerations

1. **Network Access Control**
   - NACLs stateless como primeira camada de defesa
   - Security Groups stateful como segunda camada
   - Princípio de menor privilégio em todas as regras

2. **Logging e Monitoring**
   - Habilitar VPC Flow Logs (enviar para CloudWatch Logs ou S3)
   - Configurar CloudWatch Alarms para:
     - NAT Gateway bytes processados
     - NAT Gateway connection count
     - VPC Flow Logs rejected packets

3. **Isolation**
   - Nunca expor databases diretamente em subnets públicas
   - Usar bastion hosts ou AWS Systems Manager Session Manager para acesso a recursos privados
   - Considerar AWS PrivateLink para serviços internos

4. **Encryption**
   - VPC traffic não é criptografado por padrão
   - Usar TLS/SSL para dados sensíveis em trânsito
   - Considerar AWS Certificate Manager para gerenciamento de certificados

### Cost Optimization

**Custos Estimados (us-east-1):**
```
VPC: $0 (free)
Subnets: $0 (free)
Internet Gateway: $0 (free, paga-se apenas data transfer out)
NAT Gateway: ~$32.85/mês (730 horas × $0.045/hora)
Elastic IP: $0 (enquanto associado ao NAT Gateway)
Data Transfer: ~$0.09/GB para Internet, $0.01/GB cross-AZ

Custo mensal estimado base: ~$35-50 (sem data transfer)
Custo com tráfego moderado (100GB/mês): ~$45-60
```

**Oportunidades de Otimização:**
1. Usar VPC Endpoints para S3/DynamoDB (elimina custo de NAT para esses serviços)
2. Monitorar top talkers via Flow Logs e otimizar tráfego
3. Considerar Reserved Capacity para NAT Gateway em produção (quando disponível)
4. Avaliar Regional NAT Gateway quando estiver mais maduro

### Monitoring & Observability

**CloudWatch Metrics para NAT Gateway:**
```
- ActiveConnectionCount
- BytesInFromDestination
- BytesInFromSource
- BytesOutToDestination
- BytesOutToSource
- ConnectionAttemptCount
- ConnectionEstablishedCount
- ErrorPortAllocation
- IdleTimeoutCount
- PacketsDropCount
- PacketsInFromDestination
- PacketsInFromSource
- PacketsOutToDestination
- PacketsOutToSource
```

**Recommended Alarms:**
```hcl
# High data transfer (cost alert)
Metric: BytesOutToDestination
Threshold: > 100GB/day
Action: SNS notification to cost team

# Connection errors
Metric: ErrorPortAllocation
Threshold: > 10 errors/minute
Action: SNS notification to ops team

# Packet drops
Metric: PacketsDropCount
Threshold: > 100 drops/minute
Action: SNS notification to ops team
```

### Disaster Recovery & Backup

**Scenario: Falha da AZ us-east-1a**

**Impacto:**
- ❌ NAT Gateway fica indisponível
- ❌ Subnets privadas perdem conectividade de saída
- ✅ Workloads em subnets públicas continuam funcionando
- ✅ Workloads em subnets privadas de us-east-1b continuam acessíveis internamente

**Plano de Mitigação:**
1. **Automático**: Nenhum - requer intervenção manual
2. **Manual (Emergency)**:
   ```
   Tempo estimado: 5-10 minutos
   Passos:
   1. Criar novo NAT Gateway em subnet pública us-east-1b
   2. Atualizar Private Route Table para apontar para novo NAT
   3. Aguardar propagação (~2-3 minutos)
   4. Validar conectividade
   ```

**Runbook de Recovery:**
```bash
# 1. Criar NAT Gateway via Terraform (recomendado)
terraform apply -target=aws_nat_gateway.backup

# 2. OU criar via AWS CLI (emergência)
aws ec2 allocate-address --domain vpc
aws ec2 create-nat-gateway \
  --subnet-id subnet-XXXXXX \
  --allocation-id eipalloc-XXXXXX

# 3. Atualizar route table
aws ec2 replace-route \
  --route-table-id rtb-XXXXXX \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-XXXXXX
```

**Recomendação**: Para produção, implementar 2 NAT Gateways desde o início para eliminar este risco.

### Future Enhancements

1. **Short-term (1-3 meses)**
   - Implementar VPC Flow Logs
   - Configurar CloudWatch Dashboards para network metrics
   - Criar VPC Endpoints para S3 e DynamoDB

2. **Medium-term (3-6 meses)**
   - Avaliar migração para 2 NAT Gateways se ambiente for promovido para produção
   - Implementar AWS Transit Gateway se houver necessidade de conectar múltiplas VPCs
   - Considerar IPv6 para reduzir dependência de NAT

3. **Long-term (6-12 meses)**
   - Avaliar Regional NAT Gateway após maturidade
   - Expandir para mais AZs se necessário
   - Implementar rede híbrida com AWS Direct Connect se houver datacenter on-premises

## References

### AWS Documentation
- [Amazon VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [NAT Gateway Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html)
- [VPC Design Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-design.html)
- [Regional NAT Gateway Announcement](https://aws.amazon.com/blogs/networking-and-content-delivery/introducing-amazon-vpc-regional-nat-gateway/)

### AWS Well-Architected Framework
- [Reliability Pillar - Network Design](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/design-your-workload-service-architecture.html)
- [Cost Optimization Pillar - Network](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/networking.html)

### CIDR Calculation
- [Visual Subnet Calculator](https://www.davidc.net/sites/default/subnets/subnets.html)
- IPv4 CIDR block: 10.0.0.0/24 = 256 addresses (254 usable)
- /26 subnet = 64 addresses (62 usable after AWS reserved IPs)

### MCP Research Findings
- Validated NAT Gateway availability in us-east-1: ✅ Available
- Confirmed best practice: 1 NAT per AZ for production workloads
- Regional NAT Gateway: New feature (2024), consider for future iterations

---

**Document Control**
- Version: 1.0
- Created: 2026-07-25
- Author: Cloud Architecture Team
- Status: Proposed - Pending Review
- Next Review: Upon implementation completion or 90 days
