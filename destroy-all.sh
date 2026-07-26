#!/bin/bash
# Uso: bash destroy-all.sh              -> destrói só a app
#      bash destroy-all.sh --with-backend -> destrói também o bucket S3

set -e
WITH_BACKEND=false
[ "$1" = "--with-backend" ] && WITH_BACKEND=true

echo "=== 1/3 Removendo Ingress/LB ==="
if kubectl cluster-info &>/dev/null 2>&1; then
  if helm list -n ingress-nginx 2>/dev/null | grep -q ingress-nginx; then
    helm uninstall ingress-nginx -n ingress-nginx
    echo ">>> Aguardando 90s (ENIs do LB)..."
    sleep 90
  fi
fi

echo "=== 2/3 Terraform destroy (infra/app) ==="
cd infra/app
terraform destroy -auto-approve
cd ../..

echo "=== 3/3 Limpeza local ==="
rm -f account_id.txt api_key.txt
rm -f infra/app/k8s/secrets.yaml

if [ "$WITH_BACKEND" = true ]; then
  echo ">>> Destruindo bucket S3 (bootstrap)..."
  cd infra/bootstrap
  terraform destroy -auto-approve
  cd ../..
  rm -f infra/app/backend.tf
fi

echo ">>> Destroy completo."
