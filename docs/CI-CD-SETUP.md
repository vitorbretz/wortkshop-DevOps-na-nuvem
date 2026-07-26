# CI/CD Setup Guide

Este guia descreve como configurar o pipeline CI/CD completo com GitHub Actions OIDC, ECR e ArgoCD.

## Arquitetura

```
GitHub Actions (OIDC) → AWS ECR → Kustomize → ArgoCD → EKS
```

## Pré-requisitos

- AWS CLI configurado
- kubectl configurado para o cluster EKS
- Terraform instalado
- Acesso ao repositório GitHub
- Kustomize instalado

## Passo 1: Configurar OIDC Provider no AWS

### 1.1 Configurar variáveis

```bash
cd terraform/03-github-oidc-stack
cp terraform.tfvars.example terraform.tfvars
```

Edite `terraform.tfvars` e configure:
- `github_org`: Seu usuário ou organização do GitHub
- `github_repo`: Nome do seu repositório

### 1.2 Aplicar Terraform

```bash
terraform init
terraform plan
terraform apply
```

### 1.3 Obter o ARN da Role

```bash
terraform output github_actions_role_arn
```

Anote este ARN - você precisará dele para configurar o GitHub.

## Passo 2: Configurar GitHub Secrets

1. Acesse seu repositório no GitHub
2. Vá em **Settings** > **Secrets and variables** > **Actions**
3. Clique em **New repository secret**
4. Adicione o secret:
   - **Name**: `AWS_ROLE_ARN`
   - **Value**: O ARN obtido no passo anterior

## Passo 3: Instalar ArgoCD no Cluster

```bash
# Dar permissão de execução aos scripts
chmod +x scripts/*.sh

# Instalar ArgoCD
./scripts/install-argocd.sh
```

Este script irá:
- Criar o namespace `argocd`
- Instalar ArgoCD
- Exibir a senha de admin

## Passo 4: Configurar ArgoCD Application

```bash
# Substituir pela URL do seu repositório
./scripts/configure-argocd.sh https://github.com/SEU_USER/SEU_REPO.git
```

## Passo 5: Acessar ArgoCD UI

```bash
# Port forward para acessar a UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Acesse: https://localhost:8080
- **Username**: admin
- **Password**: Execute o comando abaixo para obter

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## Passo 6: Testar o Pipeline

### 6.1 Fazer mudanças no Frontend

```bash
# Edite qualquer arquivo em dvn-workshop-apps/frontend/
git add .
git commit -m "feat: update frontend"
git push origin main
```

O pipeline irá:
1. ✅ Detectar mudanças no frontend
2. ✅ Fazer login no ECR via OIDC
3. ✅ Buildar a imagem Docker
4. ✅ Taguear com o SHA do commit
5. ✅ Push para ECR
6. ✅ Atualizar `dvn-workshop-kubernetes/frontend/kustomization.yaml`
7. ✅ Commit e push das mudanças
8. ✅ ArgoCD detecta e faz deploy automaticamente

### 6.2 Fazer mudanças no Backend

```bash
# Edite qualquer arquivo em dvn-workshop-apps/backend/
git add .
git commit -m "feat: update backend"
git push origin main
```

O mesmo processo acontece para o backend.

## Estrutura do Pipeline

### Detecção de Mudanças

O pipeline usa `dorny/paths-filter` para detectar mudanças:

- **Frontend**: `dvn-workshop-apps/frontend/**`
- **Backend**: `dvn-workshop-apps/backend/**`
- **Kubernetes**: `dvn-workshop-kubernetes/**`

### Jobs Condicionais

- `build-frontend`: Executa APENAS se houver mudanças no frontend
- `build-backend`: Executa APENAS se houver mudanças no backend

### Tagging de Imagens

As imagens são tagueadas com:
- `<sha-do-commit>`: Para versionamento específico
- `latest`: Para facilitar testes

### Atualização do Kustomization

O pipeline usa `kustomize edit set image` para atualizar as imagens:

```bash
kustomize edit set image \
  910661159891.dkr.ecr.us-east-1.amazonaws.com/dvn-workshop/frontend=910661159891.dkr.ecr.us-east-1.amazonaws.com/dvn-workshop/frontend:<SHA>
```

## ArgoCD Auto-Sync

O ArgoCD está configurado para:
- ✅ **Auto-sync**: Detecta mudanças no Git e aplica automaticamente
- ✅ **Self-heal**: Corrige divergências automaticamente
- ✅ **Prune**: Remove recursos que não estão mais no Git

## Monitoramento

### Ver logs do pipeline

```bash
# No GitHub
# Actions > CI/CD Pipeline > Ver o workflow específico
```

### Ver status no ArgoCD

```bash
# Via CLI
kubectl get applications -n argocd

# Via UI
https://localhost:8080 (com port-forward ativo)
```

### Ver pods deployados

```bash
kubectl get pods -n default
kubectl get deployments -n default
```

## Troubleshooting

### Pipeline falha no login ECR

Verifique:
1. O `AWS_ROLE_ARN` está configurado corretamente no GitHub
2. O Terraform foi aplicado com sucesso
3. O OIDC provider está ativo no AWS IAM

```bash
aws iam list-open-id-connect-providers
```

### ArgoCD não sincroniza

Verifique:
1. A URL do repositório está correta
2. O ArgoCD tem acesso ao repositório (público ou com credenciais)
3. O path no Application está correto (`dvn-workshop-kubernetes`)

```bash
kubectl get application dvn-workshop -n argocd -o yaml
```

### Imagens não atualizam

Verifique:
1. O commit foi feito corretamente
2. O kustomization.yaml foi atualizado
3. O ArgoCD sincronizou

```bash
cat dvn-workshop-kubernetes/frontend/kustomization.yaml
cat dvn-workshop-kubernetes/backend/kustomization.yaml
```

## Segurança

### OIDC vs Access Keys

Este setup usa OIDC (OpenID Connect) ao invés de Access Keys:

✅ **Vantagens**:
- Sem credenciais de longo prazo
- Tokens temporários
- Controle granular via IAM policies
- Auditoria via CloudTrail
- Rotação automática

❌ **Access Keys** (não recomendado):
- Credenciais de longo prazo
- Risco de vazamento
- Difícil de rotacionar

## Próximos Passos

1. **Adicionar testes**: Integrar testes automatizados antes do build
2. **Staging environment**: Criar ambiente de staging
3. **Rollback automation**: Configurar rollback automático em falhas
4. **Notifications**: Integrar com Slack/Discord para notificações
5. **Security scanning**: Adicionar scan de vulnerabilidades nas imagens

## Referências

- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kubectl.docs.kubernetes.io/references/kustomize/)
