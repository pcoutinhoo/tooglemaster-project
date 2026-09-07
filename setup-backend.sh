#!/bin/bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"

echo "=========================================="
echo " ToggleMaster - Bootstrap do Backend"
echo "=========================================="

echo ""
echo ">>> [1/4] Validando sessão AWS Academy..."

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "!!! Credenciais AWS inválidas ou expiradas."
  echo "!!! Inicie o Lab e configure as credenciais da AWS Academy."
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
EXPECTED_BUCKET="togglemaster-tfstate-${ACCOUNT_ID}"

echo "✓ AWS autenticada"
echo "  Account ID: ${ACCOUNT_ID}"
echo "  Região: ${AWS_REGION}"

echo ""
echo ">>> [2/4] Preparando bootstrap Terraform..."

terraform -chdir=infra/bootstrap init -input=false

# Cada conta AWS Academy mantém seu próprio state local do bootstrap.
if terraform -chdir=infra/bootstrap workspace select "${ACCOUNT_ID}" >/dev/null 2>&1; then
  echo "✓ Workspace da conta ${ACCOUNT_ID} encontrado."
else
  terraform -chdir=infra/bootstrap workspace new "${ACCOUNT_ID}"
fi

echo ""
echo ">>> [3/4] Criando/validando bucket S3 do Terraform state..."

terraform -chdir=infra/bootstrap apply \
  -auto-approve \
  -input=false \
  -var="aws_region=${AWS_REGION}"

BUCKET=$(terraform -chdir=infra/bootstrap output -raw state_bucket_name)

if [ "${BUCKET}" != "${EXPECTED_BUCKET}" ]; then
  echo "!!! Bucket inesperado."
  echo "Esperado: ${EXPECTED_BUCKET}"
  echo "Recebido: ${BUCKET}"
  exit 1
fi

echo "✓ Backend S3 disponível: ${BUCKET}"

echo ""
echo ">>> [4/4] Gerando infra/app/backend.tf..."

cat > infra/app/backend.tf <<BACKEND
terraform {
  backend "s3" {
    bucket       = "${BUCKET}"
    key          = "togglemaster/terraform.tfstate"
    region       = "${AWS_REGION}"
    use_lockfile = true
  }
}
BACKEND

echo ""
echo "=========================================="
echo " ✓ BACKEND PRONTO"
echo "=========================================="
echo "Account: ${ACCOUNT_ID}"
echo "Bucket:  ${BUCKET}"
echo ""
echo "Próximo passo:"
echo "  cd infra/app"
echo "  terraform init -reconfigure"
