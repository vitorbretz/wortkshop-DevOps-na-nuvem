# Terraform Variable Best Practices

## Princípio Fundamental

**✅ SEMPRE use variáveis - NUNCA hardcode valores**

**✅ PREFIRA objetos complexos ao invés de variáveis múltiplas separadas**

---

## Regra Principal: Objetos Complexos vs Variáveis Separadas

### ❌ NÃO FAÇA - Variáveis Separadas

```hcl
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/26", "10.0.0.64/26"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.128/26", "10.0.0.192/26"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "enable_dns_hostnames" {
  type    = bool
  default = true
}

variable "enable_dns_support" {
  type    = bool
  default = true
}
```

**Problemas:**
- ❌ Configurações relacionadas estão espalhadas
- ❌ Difícil entender relação entre subnets e AZs
- ❌ Não escalável - precisa criar nova variável para cada atributo
- ❌ Validação entre variáveis é complexa
- ❌ Falta contexto - qual CIDR pertence a qual AZ?

---

### ✅ FAÇA - Objeto Complexo Contextualizado

```hcl
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
  
  validation {
    condition     = can(cidrhost(var.vpc.cidr_block, 0))
    error_message = "VPC CIDR must be valid IPv4 CIDR block"
  }
}
```

**Vantagens:**
- ✅ Todas configs relacionadas agrupadas logicamente
- ✅ Relação clara entre CIDR e AZ
- ✅ Fácil adicionar novos atributos sem criar variáveis
- ✅ Auto-documentado - estrutura mostra hierarquia
- ✅ Escalável - adicione atributos aos objetos existentes
- ✅ Validação de relações é simples

---

## Uso nos Resources

### Com Objeto Complexo

```hcl
# vpc.tf
resource "aws_vpc" "this" {
  cidr_block           = var.vpc.cidr_block
  enable_dns_hostnames = var.vpc.enable_dns_hostnames
  enable_dns_support   = var.vpc.enable_dns_support
  
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# vpc-public-subnets.tf
resource "aws_subnet" "public" {
  count = length(var.vpc.public_subnets)
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.vpc.public_subnets[count.index].cidr_block
  availability_zone       = var.vpc.public_subnets[count.index].availability_zone
  map_public_ip_on_launch = true
  
  tags = {
    Name = "${var.project_name}-${var.vpc.public_subnets[count.index].name_suffix}"
    Type = "public"
  }
}

# vpc-private-subnets.tf
resource "aws_subnet" "private" {
  count = length(var.vpc.private_subnets)
  
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.vpc.private_subnets[count.index].cidr_block
  availability_zone = var.vpc.private_subnets[count.index].availability_zone
  
  tags = {
    Name = "${var.project_name}-${var.vpc.private_subnets[count.index].name_suffix}"
    Type = "private"
  }
}
```

---

## Quando Usar Cada Abordagem

### Use Objetos Complexos Quando:

- ✅ Há múltiplos recursos **relacionados** (VPC + subnets + route tables)
- ✅ Recursos **compartilham contexto** comum
- ✅ Cada instância precisa de **múltiplos atributos**
- ✅ Configurações são **hierárquicas**
- ✅ Você quer **agrupar logicamente** configs relacionadas

**Exemplos:**
- VPC (com subnets, gateways, route tables)
- ECS Cluster (com services, task definitions, capacidade)
- RDS (com instance, parameter group, subnet group)
- Application Load Balancer (com listeners, target groups, rules)

### Use Variáveis Simples Quando:

- ✅ Valor é **independente** (não relacionado a outros)
- ✅ Configuração é **única** e global
- ✅ Tipo **primitivo** é suficiente (string, number, bool)

**Exemplos:**
- `project_name` (usado em todas resources)
- `environment` (dev, staging, prod)
- `aws_region` (região AWS)
- `enable_monitoring` (flag global)

---

## Exemplos Adicionais

### EC2 Instance Configuration

```hcl
variable "ec2_instances" {
  description = "EC2 instance configurations"
  type = map(object({
    instance_type = string
    ami_id        = string
    subnet_id     = string
    
    root_volume = object({
      size              = number
      type              = string
      encrypted         = bool
      delete_on_termination = bool
    })
    
    security_groups = list(string)
    
    tags = optional(map(string), {})
  }))
  
  default = {
    web = {
      instance_type = "t3.medium"
      ami_id        = "ami-12345678"
      subnet_id     = "subnet-abc123"
      
      root_volume = {
        size              = 30
        type              = "gp3"
        encrypted         = true
        delete_on_termination = true
      }
      
      security_groups = ["sg-web"]
    }
    
    app = {
      instance_type = "t3.large"
      ami_id        = "ami-12345678"
      subnet_id     = "subnet-abc456"
      
      root_volume = {
        size              = 50
        type              = "gp3"
        encrypted         = true
        delete_on_termination = true
      }
      
      security_groups = ["sg-app"]
    }
  }
}
```

### RDS Database Configuration

```hcl
variable "database" {
  description = "RDS database configuration"
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    
    storage = object({
      allocated     = number
      max_allocated = number
      type          = string
      encrypted     = bool
    })
    
    credentials = object({
      username          = string
      manage_master_password = bool
    })
    
    backup = object({
      retention_period = number
      window           = string
    })
    
    maintenance = object({
      window = string
    })
    
    multi_az               = bool
    publicly_accessible    = bool
    deletion_protection    = bool
  })
  
  default = {
    engine         = "postgres"
    engine_version = "15.4"
    instance_class = "db.t3.medium"
    
    storage = {
      allocated     = 100
      max_allocated = 200
      type          = "gp3"
      encrypted     = true
    }
    
    credentials = {
      username                = "dbadmin"
      manage_master_password  = true
    }
    
    backup = {
      retention_period = 7
      window           = "03:00-04:00"
    }
    
    maintenance = {
      window = "mon:04:00-mon:05:00"
    }
    
    multi_az            = true
    publicly_accessible = false
    deletion_protection = true
  }
}
```

---

## Checklist de Implementação

Ao criar variáveis, pergunte-se:

- [ ] Este valor é realmente **independente** ou está **relacionado** a outros?
- [ ] Estou criando múltiplas variáveis para o **mesmo contexto**?
- [ ] Posso **agrupar** essas configs em um objeto?
- [ ] Cada item precisa de **múltiplos atributos**?
- [ ] A estrutura de objeto tornaria o código **mais claro**?
- [ ] Estou usando **variáveis** ao invés de **hardcode**?
- [ ] Adicionei **description** em todas as variáveis?
- [ ] Usei **validation** onde apropriado?
- [ ] Defini **optional()** com defaults sensatos?
- [ ] Configurei **nullable = false** quando necessário?

---

## Benefícios Resumidos

| Aspecto | Variáveis Separadas | Objetos Complexos |
|---------|---------------------|-------------------|
| **Contextualização** | ❌ Baixa | ✅ Alta |
| **Manutenção** | ❌ Difícil | ✅ Fácil |
| **Escalabilidade** | ❌ Cria novas vars | ✅ Adiciona atributos |
| **Documentação** | ❌ Implícita | ✅ Explícita |
| **Validação** | ❌ Complexa | ✅ Simples |
| **Legibilidade** | ❌ Espalhado | ✅ Agrupado |

---

## Referências

- **Naming Conventions**: `docs/standards/terraform-naming-conventions.md`
- **ADR-001**: `docs/architecture/ADR-001-vpc-network-architecture.md`
- [Terraform Variable Documentation](https://www.terraform.io/language/values/variables)
- [Terraform Type Constraints](https://www.terraform.io/language/expressions/types)

---

**Última Atualização**: 2026-07-25  
**Mantido Por**: DevOps Team
