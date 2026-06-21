#!/bin/bash
# build-and-push.sh
# Builda e publica as 5 imagens no ECR.
# Lê o account ID do arquivo gerado pelo 00-check-account.sh (evita hardcode).

set -e

if [ ! -f "account_id.txt" ]; then
  echo "!!! account_id.txt não encontrado. Rode infra/00-check-account.sh primeiro."
  exit 1
fi

ACCOUNT_ID=$(cat account_id.txt)
REGION="us-east-1"
ECR="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo ">>> Usando ECR: $ECR"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR

SERVICES="auth-service flag-service targeting-service evaluation-service analytics-service"

for svc in $SERVICES; do
  echo ">>> Building $svc"
  docker build -t $svc ./$svc
  docker tag $svc:latest $ECR/togglemaster/$svc:latest
  docker push $ECR/togglemaster/$svc:latest
  echo ">>> $svc done"
done

echo ""
echo ">>> Todas as imagens foram publicadas em $ECR"
