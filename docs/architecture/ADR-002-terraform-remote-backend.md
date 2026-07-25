# ADR-002: Terraform Remote Backend with S3

## Status
Proposed

## Context

Atualmente, o estado do Terraform está sendo armazenado localmente nos diretórios de cada stack. Isso apresenta diversos problemas para trabalho colaborativo e segurança:

### Problemas com State Local
- ❌ **Colaboração**: Múltiplos desenvolvedores não podem trabalhar simultaneamente
- ❌ **Segurança**: State files contêm informações sensíveis (IPs, IDs, secrets) armazenados localmente
- ❌ **Backup**: Sem backup automatizado, perda de state = perda de controle sobre infraestrutura
- ❌ **State Locking**: Sem proteção contra modificações concorrentes
- ❌ **Auditoria**: Sem histórico de mudanças no estado
- ❌ **Disaster Recovery**: Sem versionamento para rollback

### Requisitos de Negócio
- Permitir colaboração entre múltiplos desenvolvedores
- Proteger informações sensíveis no estado do Terraform
- Garantir backup automatizado do state
- Prevenir corrupção do state por modificações simultâneas
- Manter histórico de versões para auditoria e rollback
- Preparar infraestrutura para CI/CD pipelines

### Requisitos Técnicos
- Remote backend usando S3 para armazenamento
- Versionamento habilitado para histórico e rollback
- Criptografia em repouso (encryption at rest)
- Criptografia em trânsito (HTTPS)
- State locking para prevenir modificações concorrentes
- Região: us-east-1

## Decision

Implementaremos um Terraform Remote Backend usando Amazon S3 com as seguintes características:

### Componentes Principais

1. **S3 Bucket**
   - Nome: `${project_name}-${account_id}-terraform-state`
   - Versionamento: Habilitado
   - Encryption: AES-256 (SSE-S3) ou AWS KMS
   - Public Access: Bloqueado
   - Lifecycle: Transição para S3 Glacier após 90 dias (versões antigas)
   - MFA Delete: Recomendado para produção

2. **State Locking**
   - **Terraform >= 1.10**: S3 Native Locking (RECOMENDADO)
   - **Terraform < 1.10**: DynamoDB Table (legacy, sendo descontinuado)
   - Para esta implementação, usaremos S3 native locking se disponível

3. **DynamoDB Table** (Opcional - apenas se Terraform < 1.10)
   - Nome: `${project_name}-terraform-state-lock`
   - Partition Key: `LockID` (String)
   - Billing Mode: PAY_PER_REQUEST
   - Point-in-Time Recovery: Habilitado

4. **Bucket Policy**
   - Enforce encryption em upload
   - Deny insecure transport (require HTTPS)
   - Restrict access para IAM roles específicas

5. **IAM Policy**
   - Least privilege access
   - Separação entre read-only e read-write
   - Auditoria via CloudTrail

## Rationale

### Por que S3 como Backend?

1. **Durabilidade**: 99.999999999% (11 nines)
2. **Disponibilidade**: 99.99% SLA
3. **Versionamento**: Histórico completo de mudanças no state
4. **Encryption**: Suporte nativo para SSE-S3 e AWS KMS
5. **Cost-Effective**: ~$0.023/GB/mês
6. **Native Integration**: Suporte oficial do Terraform
7. **State Locking**: Suporte nativo no Terraform 1.10+

### S3 Native Locking vs DynamoDB

#### Terraform >= 1.10: S3 Native Locking (RECOMENDADO)

```hcl
terraform {
  backend "s3" {
    bucket        = "myorg-terraform-state"
    key           = "networking/terraform.tfstate"
    region        = "us-east-1"
    use_lockfile  = true
    encrypt       = true
  }
}
```

**Vantagens:**
- ✅ Sem custo adicional (DynamoDB)
- ✅ Menos componentes para gerenciar
- ✅ Configuração mais simples
- ✅ Melhor performance
- ✅ Future-proof (DynamoDB locking será removido)

#### Terraform < 1.10: DynamoDB Locking (LEGACY)

```hcl
terraform {
  backend "s3" {
    bucket         = "myorg-terraform-state"
    key            = "networking/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Desvantagens:**
- ⚠️ Custo adicional (~$0.25/mês por tabela + requests)
- ⚠️ Mais componentes para gerenciar
- ⚠️ Sendo descontinuado pelo Terraform
- ⚠️ Configuração mais complexa

### Decisão: Implementar Ambos Inicialmente

Para compatibilidade e transição suave:
1. Criar S3 bucket (sempre necessário)
2. Criar DynamoDB table (para Terraform < 1.10)
3. Documentar migração para S3 native locking

### Alternativas Consideradas

#### Alternativa 1: Terraform Cloud
```
Custo: $20/usuário/mês (após free tier)
Prós:
  - UI para gerenciar state
  - Remote execution
  - Policy as Code
  - VCS integration
Contras:
  - Vendor lock-in
  - Custo mensal recorrente
  - Menos controle sobre dados
```
**Por que não**: Queremos manter controle total e evitar custos recorrentes.

#### Alternativa 2: GitOps com State Encriptado
```
Prós:
  - Versionamento via Git
  - Sem custo adicional
Contras:
  - State exposto no repositório (mesmo encriptado)
  - Sem state locking robusto
  - Risco de segurança
  - Merge conflicts complexos
```
**Por que não**: Riscos de segurança muito altos.

#### Alternativa 3: Backend Local com NFS/Compartilhado
```
Prós:
  - Sem custo cloud adicional
Contras:
  - Single point of failure
  - Sem backup automatizado
  - Performance issues
  - Complexidade de gerenciamento
```
**Por que não**: Não escalável e sem garantias de durabilidade.

## Consequences

### Positive
- ✅ Colaboração segura entre múltiplos desenvolvedores
- ✅ Backup automatizado com 99.999999999% durabilidade
- ✅ Versionamento completo para auditoria e rollback
- ✅ State locking previne corrupção
- ✅ Criptografia protege dados sensíveis
- ✅ Preparado para CI/CD pipelines
- ✅ Custo muito baixo (~$0.50-1.00/mês)
- ✅ Reduz risco de perda de state file
- ✅ CloudTrail logging para auditoria

### Negative
- ⚠️ Dependency externa (S3 precisa estar disponível)
- ⚠️ Bootstrapping problem: bucket S3 criado sem remote backend
- ⚠️ Latência de rede (vs local state)
- ⚠️ Necessita configurar IAM permissions adequadamente
- ⚠️ Migrações entre workspaces são mais complexas

### Neutral
- 📊 Necessário manter credenciais AWS configuradas
- 📊 State file não pode ser versionado no Git (deve estar em .gitignore)
- 📊 Necessário processo para disaster recovery

## Implementation Guidance

### Stack: 00-remote-backend-stack

Esta será a **primeira stack** a ser criada, antes de todas as outras.

### Directory Structure
```
terraform/
├── 00-remote-backend-stack/
│   ├── provider.tf                # AWS provider
│   ├── versions.tf                # Terraform versions
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Outputs (bucket name, table name)
│   ├── s3-backend-bucket.tf       # S3 bucket for state
│   ├── s3-bucket-policy.tf        # Bucket policy
│   ├── dynamodb-lock-table.tf     # DynamoDB for locking (optional)
│   ├── iam-backend-policy.tf      # IAM policies for access
│   ├── terraform.tfvars.example   # Example values
│   └── README.md                  # Documentation
│
└── 01-networking-stack/
    ├── backend.tf                 # Backend configuration
    └── ...
```

### Bootstrapping Process

**Ordem de criação:**

1. **Criar 00-remote-backend-stack** com state local
2. **Apply da stack** para criar S3 bucket
3. **Configurar backend.tf** em 00-remote-backend-stack apontando para o bucket criado
4. **Migrar state** da stack usando `terraform init -migrate-state`
5. **Configurar backend.tf** em outras stacks (01-networking, etc.)

### Resource Naming Convention
```
S3 Bucket: ${project_name}-${account_id}-terraform-state
  Exemplo: dvn-workshop-910661159891-terraform-state
  
DynamoDB Table: ${project_name}-terraform-state-lock
  Exemplo: dvn-workshop-terraform-state-lock
  
IAM Policy: ${project_name}-terraform-backend-policy
```

### Required AWS Services
- **Amazon S3**: State file storage
- **DynamoDB**: State locking (se Terraform < 1.10)
- **AWS KMS**: Encryption keys (opcional, mas recomendado para produção)
- **IAM**: Policies e roles para acesso
- **CloudTrail**: Logging e auditoria (recomendado)

### Best Practices

1. **S3 Bucket Configuration**
   ```hcl
   - Versioning: Enabled
   - Encryption: SSE-S3 ou SSE-KMS
   - Public Access Block: All blocked
   - Object Lock: Consider para produção
   - Lifecycle: Archive old versions após 90 dias
   - MFA Delete: Enabled para produção
   - Logging: Enabled para bucket de log
   ```

2. **DynamoDB Table Configuration** (se necessário)
   ```hcl
   - Billing Mode: PAY_PER_REQUEST
   - Point-in-Time Recovery: Enabled
   - Encryption: SSE enabled
   - Deletion Protection: Enabled para produção
   ```

3. **Backend Configuration**
   ```hcl
   # Terraform >= 1.10
   terraform {
     backend "s3" {
       bucket        = "dvn-workshop-910661159891-terraform-state"
       key           = "networking/terraform.tfstate"
       region        = "us-east-1"
       use_lockfile  = true
       encrypt       = true
     }
   }
   
   # Terraform < 1.10
   terraform {
     backend "s3" {
       bucket         = "dvn-workshop-910661159891-terraform-state"
       key            = "networking/terraform.tfstate"
       region         = "us-east-1"
       dynamodb_table = "dvn-workshop-terraform-state-lock"
       encrypt        = true
     }
   }
   ```

4. **State File Keys Pattern**
   ```
   ${stack_name}/terraform.tfstate
   
   Exemplos:
   - remote-backend/terraform.tfstate
   - networking/terraform.tfstate
   - compute/terraform.tfstate
   - database/terraform.tfstate
   ```

5. **IAM Permissions**
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:ListBucket",
           "s3:GetObject",
           "s3:PutObject",
           "s3:DeleteObject"
         ],
         "Resource": [
           "arn:aws:s3:::BUCKET_NAME",
           "arn:aws:s3:::BUCKET_NAME/*"
         ]
       },
       {
         "Effect": "Allow",
         "Action": [
           "dynamodb:DescribeTable",
           "dynamodb:GetItem",
           "dynamodb:PutItem",
           "dynamodb:DeleteItem"
         ],
         "Resource": "arn:aws:dynamodb:*:*:table/TABLE_NAME"
       }
     ]
   }
   ```

### Security Considerations

1. **Encryption**
   - Sempre habilitar encryption at rest (SSE-S3 mínimo)
   - Considerar AWS KMS para maior controle
   - Enforce HTTPS para encryption in transit

2. **Access Control**
   - Bloquear todo acesso público
   - Usar IAM roles ao invés de access keys
   - Implementar least privilege principle
   - Separar permissões read-only vs read-write

3. **Auditoria**
   - Habilitar S3 Access Logging
   - Habilitar CloudTrail para API calls
   - Monitorar acessos suspeitos
   - Alertas para mudanças críticas

4. **Backup & Recovery**
   - Versionamento = backup automático
   - Lifecycle policies para retenção
   - Cross-region replication (produção)
   - Documentar processo de recovery

### Cost Optimization

**Custos Estimados (us-east-1):**
```
S3 Bucket:
- Storage: ~$0.023/GB/mês (primeiros 50TB)
- Requests: ~$0.0004/1000 PUT, ~$0.0004/10000 GET
- Versioning: Custo por versão armazenada

DynamoDB Table (se usar):
- PAY_PER_REQUEST: ~$0.25/mês base + $1.25/milhão writes
- Tipicamente: ~$0.50/mês

Total Estimado: ~$1-2/mês para workload pequeno

Lifecycle para economia:
- Transicionar versões antigas para Glacier após 90 dias
- Expirar versões após 1 ano
```

### Monitoring & Observability

**CloudWatch Metrics:**
```
S3 Bucket:
- BucketSizeBytes
- NumberOfObjects
- AllRequests
- 4xxErrors / 5xxErrors

DynamoDB (se usar):
- ConsumedReadCapacityUnits
- ConsumedWriteCapacityUnits
- UserErrors
```

**Recommended Alarms:**
```hcl
# S3 4xx errors (access denied, etc.)
Metric: 4xxErrors
Threshold: > 10 errors/5min
Action: SNS notification to ops team

# DynamoDB throttling (se usar)
Metric: UserErrors  
Threshold: > 5 errors/minute
Action: SNS notification
```

### Disaster Recovery

**Scenario: Corrupção ou Perda Acidental do State**

**Recovery Steps:**
1. Listar versões do state file no S3
   ```bash
   aws s3api list-object-versions \
     --bucket BUCKET_NAME \
     --prefix networking/terraform.tfstate
   ```

2. Download de versão específica
   ```bash
   aws s3api get-object \
     --bucket BUCKET_NAME \
     --key networking/terraform.tfstate \
     --version-id VERSION_ID \
     terraform.tfstate.backup
   ```

3. Restaurar state
   ```bash
   # Copy para local
   cp terraform.tfstate.backup terraform.tfstate
   
   # Push para remote
   terraform state push terraform.tfstate
   ```

4. Validar
   ```bash
   terraform plan
   ```

**Tempo de Recovery:** 5-10 minutos

### Migration Process

**Migrar state local existente para S3:**

1. **Criar backend resources** (S3, DynamoDB)
2. **Adicionar backend.tf** na stack
   ```hcl
   terraform {
     backend "s3" {
       bucket        = "bucket-name"
       key           = "stack/terraform.tfstate"
       region        = "us-east-1"
       use_lockfile  = true
       encrypt       = true
     }
   }
   ```

3. **Executar init com migration**
   ```bash
   terraform init -migrate-state
   ```

4. **Confirmar migration**
   ```
   Terraform will ask: "Do you want to copy existing state to the new backend?"
   Answer: yes
   ```

5. **Validar**
   ```bash
   # Verificar state está no S3
   aws s3 ls s3://BUCKET_NAME/stack/
   
   # Testar locking
   terraform plan
   ```

6. **Limpar local state**
   ```bash
   rm terraform.tfstate terraform.tfstate.backup
   ```

### Troubleshooting

**Issue: "Error acquiring the state lock"**
```
Causa: Outro processo tem lock ou lock órfão
Solução:
1. Verificar se outro terraform está rodando
2. Se lock órfão (DynamoDB):
   terraform force-unlock LOCK_ID
3. Se S3 native locking:
   Aguardar timeout automático ou remover .lock file
```

**Issue: "Error loading state: AccessDenied"**
```
Causa: Permissões IAM insuficientes
Solução:
1. Verificar IAM policy tem s3:GetObject
2. Verificar bucket policy não nega acesso
3. Verificar credenciais AWS corretas
```

**Issue: "Failed to save state: PutObject"**
```
Causa: Permissões write ou encryption issue
Solução:
1. Verificar s3:PutObject permission
2. Verificar KMS key permissions (se usando)
3. Verificar bucket não está locked
```

## References

### AWS Documentation
- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [S3 Encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingEncryption.html)
- [DynamoDB State Locking](https://www.terraform.io/docs/language/settings/backends/s3.html#dynamodb-state-locking)
- [AWS Best Practices - Terraform Backend](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html)

### Terraform Documentation
- [S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)
- [Backend Migration](https://www.terraform.io/docs/language/settings/backends/configuration.html#migrating-state)

### Security
- [AWS Security Best Practices for S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [Terraform State Security](https://www.terraform.io/docs/language/state/sensitive-data.html)

---

**Document Control**
- Version: 1.0
- Created: 2026-07-25
- Author: Cloud Architecture Team
- Status: Proposed - Pending Implementation
- Next Review: After 00-remote-backend-stack implementation
- Depends On: None (foundation stack)
- Required By: All other stacks (01-networking, 02-compute, etc.)
