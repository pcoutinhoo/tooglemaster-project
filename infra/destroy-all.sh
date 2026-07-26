#!/bin/bash
# destroy-all.sh
# Destrói a infra da aplicação (EKS, RDS, Redis, etc).
# O bucket S3 do backend NÃO é destruído — ele persiste entre sessões.
# Para destruir TUDO incluindo o bucket, use: bash destroy-all.sh --with-backend

set -e

WITH_BACKEND=false
if [ "$1" = "--with-backend" ]; then
  WITH_BACKEND=true
fi

echo "================================================================"
echo " PASSO 1/3 — Removendo Nginx Ingress (e o Load Balancer com ele)"
echo "================================================================"
if kubectl cluster-info &>/dev/null 2>&1; then
  if helm list -n ingress-nginx 2>/dev/null | grep -q ingress-nginx; then
    echo ">>> Desinstalando ingress-nginx via Helm..."
    helm uninstall ingress-nginx -n ingress-nginx
    echo ">>> Aguardando 90s para a AWS remover o Load Balancer e suas ENIs..."
    sleep 90
  else
    echo ">>> Nenhum release ingress-nginx encontrado. Pulando."
  fi
else
  echo ">>> kubectl não responde. Pulando Helm."
fi

echo ""
echo "================================================================"
echo " PASSO 2/3 — Terraform destroy (aplicação)"
echo "================================================================"
cd infra
terraform destroy -auto-approve
cd ..

echo ""
echo "================================================================"
echo " PASSO 3/3 — Limpeza de arquivos locais"
echo "================================================================"
rm -f account_id.txt api_key.txt
rm -f infra/k8s/secrets.yaml k8s/secrets.yaml
echo ">>> Arquivos locais limpos."

if [ "$WITH_BACKEND" = true ]; then
  echo ""
  echo "================================================================"
  echo " EXTRA — Destruindo bucket S3 do backend"
  echo "================================================================"
  if [ -f "backend_bucket.txt" ]; then
    BUCKET=$(cat backend_bucket.txt)
    echo ">>> Esvaziando bucket $BUCKET..."
    aws s3 rm "s3://$BUCKET" --recursive
    echo ">>> Deletando bucket $BUCKET..."
    aws s3api delete-bucket --bucket "$BUCKET" --region us-east-1
    rm -f backend_bucket.txt infra/backend.tf
    echo ">>> Bucket destruído."
  else
    echo ">>> backend_bucket.txt não encontrado. Pulando."
  fi
fi

echo ""
echo ">>> Destroy completo."
echo ">>> Para recriar: bash setup-backend.sh && bash run-all.sh"
