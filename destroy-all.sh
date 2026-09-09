#!/bin/bash
set -e
WITH_BACKEND=false
[ "$1" = "--with-backend" ] && WITH_BACKEND=true

echo "=== 0/3 Garantindo credenciais e variáveis ==="
aws sts get-caller-identity > /dev/null || { echo "!!! Sessão AWS inválida. Renove no Academy antes de continuar."; exit 1; }
export TF_VAR_lab_role_arn="$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)"

# No destroy, o Terraform só precisa que a variável exista.
# Se a senha real já estiver no ambiente, ela é reutilizada.
# Caso contrário, usa um valor temporário apenas para validar a configuração.
export TF_VAR_db_password="${TF_VAR_db_password:-TerraformDestroyOnly123!}"

echo ">>> LabRole: $TF_VAR_lab_role_arn"

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
  cd infra/bootstrap
  terraform destroy -auto-approve
  cd ../..
  rm -f infra/app/backend.tf
fi

echo ">>> Destroy completo."