#!/bin/bash
# setup-env.sh
# Define as variáveis de ambiente necessárias para executar run-all.sh
# Execute: source setup-env.sh

# Não usar set -e neste arquivo: ele é carregado com source e afetaria o shell atual.

echo "=========================================="
echo "  TOGGLEMASTER - Setup Environment"
echo "=========================================="

# ─────────────────────────────────────────────────────────────────────────────
# 1. VALIDAÇÕES INICIAIS
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo ">>> [1/5] Validando pré-requisitos..."

REQUIRED_TOOLS=("aws" "terraform" "kubectl" "helm" "docker")
MISSING_TOOLS=()

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    MISSING_TOOLS+=("$tool")
  fi
done

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "!!! Ferramentas ausentes: ${MISSING_TOOLS[*]}"
  echo "!!! Instale antes de continuar."
  return 1 2>/dev/null || exit 1
fi

echo "✓ aws, terraform, kubectl, helm, docker OK"

# ─────────────────────────────────────────────────────────────────────────────
# 2. VALIDAÇÃO DE CREDENCIAIS AWS
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo ">>> [2/5] Validando credenciais AWS..."

if ! aws sts get-caller-identity &>/dev/null; then
  echo "!!! Credenciais AWS inválidas ou não configuradas."
  echo "!!! Execute: aws configure (ou configure AWS_PROFILE/AWS_REGION)"
  return 1 2>/dev/null || exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output text)
echo "✓ Autenticado como: $AWS_USER"
echo "  Account ID: $ACCOUNT_ID"

# ─────────────────────────────────────────────────────────────────────────────
# 3. CONFIGURAÇÃO DE REGIÃO E PROFILE
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo ">>> [3/5] Configurando AWS Region e Profile..."

# AWS_REGION (default: us-east-1)
export AWS_REGION="${AWS_REGION:-us-east-1}"
echo "✓ AWS_REGION = $AWS_REGION"

# AWS_PROFILE (opcional)
if [ -n "$AWS_PROFILE" ]; then
  echo "✓ AWS_PROFILE = $AWS_PROFILE"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. VARIÁVEIS TERRAFORM
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo ">>> [4/5] Configurando variáveis Terraform..."

# Projeto
export TF_VAR_aws_region="${AWS_REGION}"
export TF_VAR_project_name="togglemaster"

# Senha PostgreSQL
if [ -z "${TF_VAR_db_password:-}" ]; then
  read -r -s -p "Digite a senha PostgreSQL do ambiente: " TF_VAR_db_password
  echo
  export TF_VAR_db_password
fi

if [ -z "$TF_VAR_db_password" ]; then
  echo "!!! TF_VAR_db_password não pode ficar vazia."
  return 1 2>/dev/null || exit 1
fi

echo "✓ TF_VAR_db_password configurada"

# MASTER_KEY usada pelo auth-service
if [ -z "${MASTER_KEY:-}" ]; then
  read -r -s -p "Digite a MASTER_KEY do ambiente: " MASTER_KEY
  echo
  export MASTER_KEY
fi

if [ -z "$MASTER_KEY" ]; then
  echo "!!! MASTER_KEY não pode ficar vazia."
  return 1 2>/dev/null || exit 1
fi

echo "✓ MASTER_KEY configurada"

# LabRole ARN (obtém dinamicamente)
LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$LAB_ROLE_ARN" ]; then
  echo "!!! LabRole não encontrada."
  echo "!!! Se não estiver em AWS Academy, comente 'TF_VAR_lab_role_arn' em infra/app/main.tf"
  return 1 2>/dev/null || exit 1
fi

export TF_VAR_lab_role_arn="$LAB_ROLE_ARN"
echo "✓ TF_VAR_lab_role_arn = $LAB_ROLE_ARN"

# ─────────────────────────────────────────────────────────────────────────────
# 5. VARIÁVEIS DOCKER / ECR
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo ">>> [5/5] Configurando ECR..."

export ECR_REGION="${AWS_REGION}"
export ECR_ACCOUNT_ID="$ACCOUNT_ID"
export ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "✓ ECR_URL = $ECR_URL"

# ─────────────────────────────────────────────────────────────────────────────
# RESUMO
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "=========================================="
echo "  ✓ AMBIENTE CONFIGURADO COM SUCESSO!"
echo "=========================================="
echo ""
echo "Variáveis exportadas:"
echo "  • AWS_REGION             = $AWS_REGION"
echo "  • TF_VAR_project_name    = $TF_VAR_project_name"
echo "  • TF_VAR_db_password     = [***]"
echo "  • TF_VAR_lab_role_arn    = $TF_VAR_lab_role_arn"
echo "  • ECR_URL                = $ECR_URL"
echo ""
echo "Próximo passo: bash run-all.sh"
echo ""
