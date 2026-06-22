#!/bin/bash
# deploy-k8s.sh
# Aplica todos os manifests Kubernetes na ordem correta.
# Rodar da RAIZ do projeto.

set -e

K8S_DIR="infra/k8s"

if [ ! -d "$K8S_DIR" ]; then
  echo "!!! Pasta $K8S_DIR não encontrada. Rode da RAIZ do projeto."
  exit 1
fi

echo ">>> Aplicando namespace..."
kubectl apply -f "$K8S_DIR/namespace.yaml"

echo ">>> Aplicando ConfigMap..."
kubectl apply -f "$K8S_DIR/configmap.yaml"

echo ">>> Aplicando Secrets..."
kubectl apply -f "$K8S_DIR/secrets.yaml"

echo ">>> Aplicando Deployments dos serviços..."
kubectl apply -f "$K8S_DIR/auth-service.yaml"
kubectl apply -f "$K8S_DIR/flag-service.yaml"
kubectl apply -f "$K8S_DIR/targeting-service.yaml"
kubectl apply -f "$K8S_DIR/evaluation-service.yaml"
kubectl apply -f "$K8S_DIR/analytics-service.yaml"

echo ">>> Aplicando Ingress..."
kubectl apply -f "$K8S_DIR/ingress.yaml"

echo ">>> Aplicando HPA..."
kubectl apply -f "$K8S_DIR/hpa.yaml"

echo ">>> Todos os manifestos aplicados."
kubectl get pods -n togglemaster
