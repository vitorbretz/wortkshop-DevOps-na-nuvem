# Terraform Naming Conventions

## Convenções Gerais

### Regras Básicas
1. ✅ Use `_` (underscore) em nomes de recursos, variáveis e outputs
2. ❌ Nunca use `-` (dash) em nomes Terraform (recursos, variáveis, outputs)
3. ✅ Use `-` (dash) em nomes de arquivos Terraform
4. ✅ Use letras minúsculas e números
5. ✅ Use sempre substantivos no singular

---

## Estrutura de Arquivos

### Regra: Separe recursos em arquivos dedicados

Use a convenção `{service}.{resource-type}.tf` para organizar seus arquivos:

```
terraform/
├── provider.tf              # Provider configuration
├── versions.tf              # Terraform and provider versions
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── data.tf                  # Data sources (se houver muitos)
├── locals.tf                # Local values (se houver muitos)
│
├── vpc.tf                   # VPC principal
├── vpc-public-subnets.tf    # Public subnets
├── vpc-private-subnets.tf   # Private subnets
├── vpc-internet-gateway.tf  # Internet Gateway
├── vpc-nat-gateway.tf       # NAT Gateway
├── vpc-public-route-table.tf    # Public route table
├── vpc-private-route-table.tf   # Private route table
│
├── ec2-instances.tf         # EC2 instances
├── ec2-security-groups.tf   # Security groups para EC2
├── rds-database.tf          # RDS database
├── rds-subnet-group.tf      # RDS subnet group
├── s3-buckets.tf            # S3 buckets
└── iam-roles.tf             # IAM roles
```

### Exemplos de Nomenclatura de Arquivos

#### Para recursos de VPC:
```
vpc.tf                        # VPC principal
vpc-public-subnets.tf         # Subnets públicas
vpc-private-subnets.tf        # Subnets privadas
vpc-database-subnets.tf       # Subnets de database
vpc-internet-gateway.tf       # Internet Gateway
vpc-nat-gateway.tf            # NAT Gateway(s)
vpc-public-route-table.tf     # Route table pública
vpc-private-route-table.tf    # Route table privada
vpc-database-route-table.tf   # Route table de database
vpc-endpoints.tf              # VPC Endpoints
vpc-flow-logs.tf              # VPC Flow Logs
```

#### Para recursos de EC2:
```
ec2-instances.tf              # Instâncias EC2
ec2-launch-templates.tf       # Launch templates
ec2-security-groups.tf        # Security groups
ec2-key-pairs.tf              # Key pairs
ec2-elastic-ips.tf            # Elastic IPs
```

#### Para recursos de ECS:
```
ecs-cluster.tf                # ECS Cluster
ecs-services.tf               # ECS Services
ecs-task-definitions.tf       # Task definitions
ecs-security-groups.tf        # Security groups para ECS
```

#### Para recursos de RDS:
```
rds-database.tf               # RDS instance
rds-subnet-group.tf           # DB subnet group
rds-parameter-group.tf        # Parameter group
rds-security-groups.tf        # Security groups para RDS
```

### Arquivos Principais (Sempre Presentes)

```
provider.tf                   # Configuração do provider AWS
versions.tf                   # Versões do Terraform e providers
variables.tf                  # Todas as variáveis do módulo
outputs.tf                    # Todos os outputs do módulo
data.tf                       # Data sources (opcional)
locals.tf                     # Local values (opcional)
```

### Regras de Organização

1. **Um tipo de recurso por arquivo** quando possível
2. **Recursos relacionados podem ficar juntos** (ex: route table + routes + associations)
3. **Use prefixo do serviço** (vpc-, ec2-, rds-, etc.)
4. **Use hífen para separar palavras** nos nomes de arquivos
5. **Seja descritivo** - o nome do arquivo deve indicar claramente o conteúdo

```hcl
# ✅ CORRETO
resource "aws_vpc" "main" {}
resource "aws_subnet" "public" {}

# ❌ ERRADO
resource "aws_vpc" "Main" {}          # Maiúscula
resource "aws-vpc" "main" {}          # Dash no tipo
resource "aws_subnet" "publics" {}    # Plural
```

### Exemplo Completo de Estrutura

```
projeto/
├── environments/
│   ├── dev/
│   │   ├── provider.tf
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── vpc.tf
│   │   ├── vpc-public-subnets.tf
│   │   ├── vpc-private-subnets.tf
│   │   ├── vpc-nat-gateway.tf
│   │   └── vpc-route-tables.tf
│   └── prod/
│       └── (mesma estrutura)
└── modules/
    └── networking/
        ├── vpc.tf
        ├── vpc-public-subnets.tf
        ├── vpc-private-subnets.tf
        ├── vpc-internet-gateway.tf
        ├── vpc-nat-gateway.tf
        ├── vpc-public-route-table.tf
        ├── vpc-private-route-table.tf
        ├── variables.tf
        ├── outputs.tf
        └── versions.tf
```

---

## Recursos (Resources)

### Regra 1: Não repita o tipo do recurso no nome

```hcl
# ✅ CORRETO
resource "aws_route_table" "public" {}

# ❌ ERRADO
resource "aws_route_table" "public_route_table" {}
resource "aws_route_table" "public_aws_route_table" {}
```

### Regra 2: Use "this" quando houver apenas um recurso daquele tipo

```hcl
# ✅ CORRETO - Apenas 1 VPC no módulo
resource "aws_vpc" "this" {}

# ✅ CORRETO - Múltiplas subnets, então use nomes descritivos
resource "aws_subnet" "public" {}
resource "aws_subnet" "private" {}
```

### Regra 3: Use `-` (dash) dentro dos valores de argumentos

```hcl
# ✅ CORRETO
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "my-vpc-name"           # Dash em valores OK
    Environment = "dev-environment" # Dash em valores OK
  }
}
```

### Regra 4: Ordem dos argumentos

```hcl
resource "aws_nat_gateway" "this" {
  # 1. count/for_each sempre primeiro
  count = 2
  
  # 2. Argumentos principais
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  # 3. Tags sempre antes de depends_on/lifecycle
  tags = {
    Name = "nat-gateway-${count.index}"
  }
  
  # 4. depends_on (se necessário)
  depends_on = [aws_internet_gateway.this]
  
  # 5. lifecycle (se necessário)
  lifecycle {
    create_before_destroy = true
  }
}
```

### Regra 5: Condições em count - prefira booleanos

```hcl
# ✅ MELHOR
resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0
}

# ✅ BOM
resource "aws_nat_gateway" "this" {
  count = length(var.public_subnets) > 0 ? 1 : 0
}

# ❌ EVITE
resource "aws_nat_gateway" "this" {
  count = var.enable_nat == true ? 1 : 0  # Redundante
}
```

---

## Variáveis (Variables)

### Regra 1: Use nomes descritivos e positivos

```hcl
# ✅ CORRETO
variable "encryption_enabled" {
  description = "Enable encryption at rest"
  type        = bool
  default     = true
}

# ❌ ERRADO - Negativo duplo confunde
variable "encryption_disabled" {
  type    = bool
  default = false
}
```

### Regra 2: Use plural para listas e mapas

```hcl
# ✅ CORRETO
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "subnet_cidrs" {
  description = "Map of subnet CIDR blocks"
  type        = map(string)
  default     = {}
}

# ❌ ERRADO - Singular para lista
variable "availability_zone" {
  type    = list(string)
  default = ["us-east-1a"]
}
```

### Regra 3: Ordem das chaves em variável

```hcl
variable "vpc_cidr" {
  # 1. description (sempre primeiro)
  description = "CIDR block for VPC"
  
  # 2. type
  type = string
  
  # 3. default
  default = "10.0.0.0/16"
  
  # 4. validation (se necessário)
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be valid IPv4 CIDR"
  }
  
  # 5. nullable (se necessário)
  nullable = false
}
```

### Regra 4: Tipos simples vs específicos

```hcl
# ✅ CORRETO - Tipo simples quando adequado
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# ✅ CORRETO - Tipo específico quando precisa validação
variable "vpc_config" {
  description = "VPC configuration object"
  type = object({
    cidr_block           = string
    enable_dns_hostnames = bool
    enable_dns_support   = bool
  })
}

# ✅ CORRETO - Use 'any' para flexibilidade
variable "tags" {
  description = "Additional tags"
  type        = any
  default     = {}
}
```

### Regra 5: Prefira objetos complexos ao invés de variáveis múltiplas separadas

**IMPORTANTE**: Ao trabalhar com recursos relacionados, agrupe configurações em objetos complexos ao invés de criar múltiplas variáveis separadas.

#### ❌ EVITE - Variáveis separadas (menos contextualizado)

```hcl
variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/26", "10.0.0.64/26"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.128/26", "10.0.0.192/26"]
}

variable "public_subnet_azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
```

#### ✅ PREFIRA - Objeto complexo (mais contextualizado)

```hcl
variable "vpc" {
  description = "VPC configuration including subnets"
  type = object({
    cidr_block           = string
    enable_dns_hostnames = optional(bool, true)
    enable_dns_support   = optional(bool, true)
    
    public_subnets = list(object({
      cidr_block        = string
      availability_zone = string
      name_suffix       = optional(string)
    }))
    
    private_subnets = list(object({
      cidr_block        = string
      availability_zone = string
      name_suffix       = optional(string)
    }))
  })
  
  default = {
    cidr_block           = "10.0.0.0/24"
    enable_dns_hostnames = true
    enable_dns_support   = true
    
    public_subnets = [
      {
        cidr_block        = "10.0.0.0/26"
        availability_zone = "us-east-1a"
        name_suffix       = "public-1a"
      },
      {
        cidr_block        = "10.0.0.64/26"
        availability_zone = "us-east-1b"
        name_suffix       = "public-1b"
      }
    ]
    
    private_subnets = [
      {
        cidr_block        = "10.0.0.128/26"
        availability_zone = "us-east-1a"
        name_suffix       = "private-1a"
      },
      {
        cidr_block        = "10.0.0.192/26"
        availability_zone = "us-east-1b"
        name_suffix       = "private-1b"
      }
    ]
  }
}
```

#### Uso nos Resources

```hcl
# Com objeto complexo
resource "aws_vpc" "this" {
  cidr_block           = var.vpc.cidr_block
  enable_dns_hostnames = var.vpc.enable_dns_hostnames
  enable_dns_support   = var.vpc.enable_dns_support
}

resource "aws_subnet" "public" {
  count = length(var.vpc.public_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.vpc.public_subnets[count.index].cidr_block
  availability_zone = var.vpc.public_subnets[count.index].availability_zone
  
  tags = {
    Name = "${var.project_name}-${var.vpc.public_subnets[count.index].name_suffix}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.vpc.private_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.vpc.private_subnets[count.index].cidr_block
  availability_zone = var.vpc.private_subnets[count.index].availability_zone
  
  tags = {
    Name = "${var.project_name}-${var.vpc.private_subnets[count.index].name_suffix}"
  }
}
```

#### Benefícios desta Abordagem

✅ **Contextualização**: Todas configurações relacionadas ficam agrupadas  
✅ **Flexibilidade**: Cada subnet pode ter atributos específicos  
✅ **Manutenção**: Mais fácil entender e modificar configurações  
✅ **Validação**: Pode validar relações entre atributos  
✅ **Escalabilidade**: Fácil adicionar novos atributos sem criar variáveis  
✅ **Documentação**: Estrutura auto-documentada

#### Quando Usar Objetos Complexos

Use objetos complexos quando:
- Há múltiplos recursos relacionados (ex: VPC + subnets + route tables)
- Recursos compartilham contexto comum
- Cada instância precisa de múltiplos atributos
- Configurações são hierárquicas

#### Quando Usar Variáveis Simples

Use variáveis simples quando:
- Valor é realmente independente (ex: region, project_name)
- Configuração é única e não relacionada a outras
- Tipo primitivo é suficiente (string, number, bool)

### Regra 6: Use nullable = false quando apropriado

```hcl
# ✅ CORRETO - Garante que null use o default
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "main-vpc"
  nullable    = false
}
```

---

## Outputs

### Regra 1: Formato do nome: {name}_{type}_{attribute}

```hcl
# ✅ CORRETO
output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "main_vpc_id" {
  description = "ID of main VPC"
  value       = aws_vpc.main.id
}

output "nat_gateway_public_ip" {
  description = "Elastic IP of NAT Gateway"
  value       = aws_eip.nat.public_ip
}

# ❌ ERRADO
output "subnet_id" {              # Não específico
  value = aws_subnet.private.id
}

output "id" {                     # Muito vago
  value = aws_vpc.this.id
}
```

### Regra 2: Use plural quando retornar lista

```hcl
# ✅ CORRETO
output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

# ❌ ERRADO
output "private_subnet_id" {      # Singular para lista confunde
  value = aws_subnet.private[*].id
}
```

### Regra 3: Sempre inclua description

```hcl
# ✅ CORRETO
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

# ❌ ERRADO
output "vpc_id" {
  value = aws_vpc.this.id
}
```

### Regra 4: Use try() para outputs opcionais

```hcl
# ✅ CORRETO - Terraform 0.13+
output "nat_gateway_id" {
  description = "ID of NAT Gateway if created"
  value       = try(aws_nat_gateway.this[0].id, "")
}

# ❌ EVITE - Legado (pre-0.13)
output "nat_gateway_id" {
  value = element(concat(aws_nat_gateway.this.*.id, [""]), 0)
}
```

---

## Exemplos Práticos por Resource Type

### Exemplo Completo: VPC com Estrutura de Objeto Complexo

#### variables.tf (Recomendado)

```hcl
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "my-project"
  nullable    = false
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  nullable    = false
}

variable "vpc" {
  description = "Complete VPC configuration with all network components"
  type = object({
    cidr_block           = string
    enable_dns_hostnames = optional(bool, true)
    enable_dns_support   = optional(bool, true)
    
    public_subnets = list(object({
      cidr_block        = string
      availability_zone = string
      name_suffix       = optional(string)
    }))
    
    private_subnets = list(object({
      cidr_block        = string
      availability_zone = string
      name_suffix       = optional(string)
    }))
    
    nat_gateway = optional(object({
      enabled           = bool
      single_nat        = optional(bool, true)
    }), { enabled = true, single_nat = true })
  })
  
  default = {
    cidr_block           = "10.0.0.0/24"
    enable_dns_hostnames = true
    enable_dns_support   = true
    
    public_subnets = [
      {
        cidr_block        = "10.0.0.0/26"
        availability_zone = "us-east-1a"
        name_suffix       = "public-1a"
      },
      {
        cidr_block        = "10.0.0.64/26"
        availability_zone = "us-east-1b"
        name_suffix       = "public-1b"
      }
    ]
    
    private_subnets = [
      {
        cidr_block        = "10.0.0.128/26"
        availability_zone = "us-east-1a"
        name_suffix       = "private-1a"
      },
      {
        cidr_block        = "10.0.0.192/26"
        availability_zone = "us-east-1b"
        name_suffix       = "private-1b"
      }
    ]
    
    nat_gateway = {
      enabled    = true
      single_nat = true
    }
  }
}
```

#### vpc.tf
```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc.cidr_block
  enable_dns_hostnames = var.vpc.enable_dns_hostnames
  enable_dns_support   = var.vpc.enable_dns_support
  
  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}
```

#### vpc-public-subnets.tf
```hcl
resource "aws_subnet" "public" {
  count = length(var.vpc.public_subnets)
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.vpc.public_subnets[count.index].cidr_block
  availability_zone       = var.vpc.public_subnets[count.index].availability_zone
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project_name}-${var.environment}-${var.vpc.public_subnets[count.index].name_suffix}"
    Type = "public"
  }
}
```

#### vpc-private-subnets.tf
```hcl
resource "aws_subnet" "private" {
  count = length(var.vpc.private_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.vpc.private_subnets[count.index].cidr_block
  availability_zone = var.vpc.private_subnets[count.index].availability_zone
  
  tags = {
    Name = "${var.project_name}-${var.environment}-${var.vpc.private_subnets[count.index].name_suffix}"
    Type = "private"
  }
}
```

---

### Exemplos por Resource Type (Estrutura Antiga - Menos Recomendado)

### VPC
```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = var.vpc_name
  }
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}
```

### Subnets
```hcl
# Múltiplas subnets - use nomes descritivos
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Type = "public"
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Type = "private"
  }
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}
```

### NAT Gateway
```hcl
# Único NAT Gateway - use "this"
resource "aws_eip" "nat" {
  count  = var.create_nat_gateway ? 1 : 0
  domain = "vpc"
  
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
  
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0
  
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  tags = {
    Name = "${var.project_name}-nat"
  }
  
  depends_on = [aws_internet_gateway.this]
}

output "nat_gateway_id" {
  description = "ID of NAT Gateway"
  value       = try(aws_nat_gateway.this[0].id, "")
}

output "nat_gateway_public_ip" {
  description = "Elastic IP of NAT Gateway"
  value       = try(aws_eip.nat[0].public_ip, "")
}
```

### Internet Gateway
```hcl
# Único IGW - use "this"
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  
  tags = {
    Name = "${var.project_name}-igw"
  }
}

output "internet_gateway_id" {
  description = "ID of Internet Gateway"
  value       = aws_internet_gateway.this.id
}
```

### Route Tables
```hcl
# Múltiplas route tables - use nomes descritivos
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  
  tags = {
    Name = "${var.project_name}-public-rt"
    Type = "public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  
  tags = {
    Name = "${var.project_name}-private-rt"
    Type = "private"
  }
}

output "public_route_table_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of private route table"
  value       = aws_route_table.private.id
}
```

---

## Resumo - Checklist Rápido

### Arquivos ✅
- [ ] Use `-` (dash) para nomes de arquivos
- [ ] Formato: `{service}-{resource-type}.tf`
- [ ] Exemplos: `vpc-public-subnets.tf`, `ec2-instances.tf`
- [ ] Arquivos padrão: `provider.tf`, `versions.tf`, `variables.tf`, `outputs.tf`

### Resources ✅
- [ ] Use `_` (underscore) para nomes de recursos
- [ ] Não repetir tipo no nome
- [ ] Usar "this" para recurso único
- [ ] count/for_each primeiro
- [ ] tags antes de depends_on/lifecycle
- [ ] Usar `-` em valores de argumentos

### Variables ✅
- [ ] description sempre presente
- [ ] Ordem: description → type → default → validation
- [ ] **Prefira objetos complexos** para configs relacionadas
- [ ] Use `vpc.public_subnets` ao invés de múltiplas variáveis separadas
- [ ] Plural para list/map
- [ ] Nomes positivos (avoid double negatives)
- [ ] nullable = false quando apropriado

### Outputs ✅
- [ ] Formato: {name}_{type}_{attribute}
- [ ] Plural para listas
- [ ] description sempre presente
- [ ] Usar try() para valores opcionais

---

**Referência:** [Terraform Best Practices - Naming Conventions](https://www.terraform-best-practices.com/naming)
