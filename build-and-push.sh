#!/bin/bash
# build-and-push.sh
# Builda e publica as 5 imagens no ECR.
# Compatível com Windows (Git Bash) e macOS.

set -e

if [ ! -f "account_id.txt" ]; then
  echo "!!! account_id.txt não encontrado."
  echo "!!! Rode infra/00-check-account.sh primeiro."
  exit 1
fi

ACCOUNT_ID=$(cat account_id.txt)
REGION="us-east-1"
ECR="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo ">>> Usando ECR: $ECR"

# Login no ECR
aws ecr get-login-password --region "$REGION" | \
  docker login --username AWS --password-stdin "$ECR"

SERVICES="auth-service flag-service targeting-service evaluation-service analytics-service"

for svc in $SERVICES; do
  if [ ! -d "./$svc" ]; then
    echo "!!! Pasta ./$svc não encontrada. Está na raiz do projeto?"
    exit 1
  fi
  echo ""
  echo ">>> [$svc] Building..."
  # --platform linux/amd64 garante que a imagem funcione nos nodes Linux do EKS
  # mesmo que você esteja buildando num Mac M1/M2 (ARM)
  docker build --platform linux/amd64 -t "$svc" "./$svc"
  docker tag "$svc:latest" "$ECR/togglemaster/$svc:latest"
  echo ">>> [$svc] Pushing..."
  docker push "$ECR/togglemaster/$svc:latest"
  echo ">>> [$svc] OK"
done

echo ""
echo ">>> Todas as imagens publicadas em $ECR"