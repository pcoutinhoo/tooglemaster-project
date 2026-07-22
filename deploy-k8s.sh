#!/bin/bash
# deploy-k8s.sh
# Aplica todos os manifestos K8s na ordem correta.
# Compatível com Windows (Git Bash) e macOS.

set -e

K8S="infra/k8s"

if [ ! -d "$K8S" ]; then
  echo "!!! Pasta $K8S não encontrada."
  echo "!!! Rode da RAIZ do projeto (onde ficam as pastas auth-service/, infra/, etc.)"
  exit 1
fi

echo ">>> [1/7] Aplicando namespace..."
kubectl apply -f $K8S/namespace.yaml

echo ">>> [2/7] Aplicando secrets..."
kubectl apply -f $K8S/secrets.yaml

echo ">>> [3/7] Aplicando configmap..."
kubectl apply -f $K8S/configmap.yaml

echo ">>> [4/7] Aplicando deployments e services..."
kubectl apply -f $K8S/auth-service.yaml
kubectl apply -f $K8S/flag-service.yaml
kubectl apply -f $K8S/targeting-service.yaml
kubectl apply -f $K8S/evaluation-service.yaml
kubectl apply -f $K8S/analytics-service.yaml

echo ">>> [5/7] Aplicando ingress..."
kubectl apply -f $K8S/ingress.yaml

echo ">>> [6/7] Aplicando HPA..."
kubectl apply -f $K8S/hpa.yaml

echo ">>> [7/7] Verificando status..."
sleep 5
echo ""
echo "=== Pods ==="
kubectl get pods -n togglemaster

echo ""
echo "=== Ingress (copie o ADDRESS para os testes) ==="
kubectl get ingress -n togglemaster

echo ""
echo "=== HPA ==="
kubectl get hpa -n togglemaster