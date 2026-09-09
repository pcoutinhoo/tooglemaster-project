#!/bin/bash

echo "=========================================="
echo " ToggleMaster - Bootstrap do Backend"
echo "=========================================="

echo ""
echo ">>> [1/4] Validando sessão AWS Academy..."

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "✗ AWS não autenticada."
  echo "Execute aws configure e configure o Session Token."
  return 1 2>/dev/null || exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
AWS_REGION="${AWS_REGION:-us-east-1}"
STATE_BUCKET="togglemaster-tfstate-${ACCOUNT_ID}"

echo "✓ AWS autenticada"
echo "  Account ID: ${ACCOUNT_ID}"
echo "  Região: ${AWS_REGION}"

echo ""
echo ">>> [2/4] Criando/validando bucket S3..."

if aws s3api head-bucket \
  --bucket "${STATE_BUCKET}" \
  >/dev/null 2>&1; then

  echo "✓ Bucket já existe: ${STATE_BUCKET}"

else
  echo "Bucket não encontrado. Criando..."

  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "${STATE_BUCKET}" \
      --region "${AWS_REGION}"
  else
    aws s3api create-bucket \
      --bucket "${STATE_BUCKET}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration \
      LocationConstraint="${AWS_REGION}"
  fi

  echo "✓ Bucket criado: ${STATE_BUCKET}"
fi

echo ""
echo ">>> [3/4] Configurando segurança e versionamento..."

aws s3api put-bucket-versioning \
  --bucket "${STATE_BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-public-access-block \
  --bucket "${STATE_BUCKET}" \
  --public-access-block-configuration \
BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "✓ Versionamento habilitado"
echo "✓ Acesso público bloqueado"

echo ""
echo ">>> [4/4] Gerando backend Terraform..."

mkdir -p infra/app

cat > infra/app/backend.tf <<EOF
terraform {
  backend "s3" {
    bucket       = "${STATE_BUCKET}"
    key          = "togglemaster/terraform.tfstate"
    region       = "${AWS_REGION}"
    use_lockfile = true
  }
}
EOF

echo "✓ infra/app/backend.tf gerado"

echo ""
echo "=========================================="
echo " ✓ BACKEND CONFIGURADO COM SUCESSO!"
echo "=========================================="
echo ""
echo "Bucket: ${STATE_BUCKET}"
echo "State:  s3://${STATE_BUCKET}/togglemaster/terraform.tfstate"
echo ""
echo "Próximo passo:"
echo "  cd infra/app"
echo "  terraform init -reconfigure"