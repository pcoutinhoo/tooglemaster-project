#!/bin/bash
set -e
K8S="infra/app/k8s"

if [ ! -d "$K8S" ]; then
  echo "!!! Pasta $K8S não encontrada. Rode da RAIZ do projeto."
  exit 1
fi

if [ ! -f "account_id.txt" ]; then
  echo "!!! account_id.txt não encontrado. Rode: cd infra && bash 00-check-account.sh"
  exit 1
fi

ACCOUNT_ID=$(cat account_id.txt)
echo ">>> Account ID atual: $ACCOUNT_ID"

echo ">>> Corrigindo account ID das imagens ECR nos manifestos (evita hardcode desatualizado)..."
# Troca QUALQUER account ID .dkr.ecr pelo atual
sed -i "s/[0-9]\{12\}\.dkr\.ecr/${ACCOUNT_ID}.dkr.ecr/g" $K8S/*.yaml
echo ">>> Manifestos atualizados com o account ID correto."

echo ">>> [1/7] namespace"; kubectl apply -f $K8S/namespace.yaml
echo ">>> [2/7] secrets";   kubectl apply -f $K8S/secrets.yaml
echo ">>> [3/7] configmap"; kubectl apply -f $K8S/configmap.yaml
echo ">>> [4/7] deployments/services"
kubectl apply -f $K8S/auth-service.yaml
kubectl apply -f $K8S/flag-service.yaml
kubectl apply -f $K8S/targeting-service.yaml
kubectl apply -f $K8S/evaluation-service.yaml
kubectl apply -f $K8S/analytics-service.yaml
echo ">>> [5/7] ingress"; kubectl apply -f $K8S/ingress.yaml
echo ">>> [6/7] hpa";     kubectl apply -f $K8S/hpa.yaml

echo ">>> [7/7] Status:"
sleep 5
kubectl get pods -n togglemaster
kubectl get ingress -n togglemaster
kubectl get hpa -n togglemaster