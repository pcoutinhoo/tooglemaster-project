#!/bin/bash
# deploy-k8s.sh
# Aplica todos os manifestos K8s na ordem correta. TOP de mais !!!! 

set -e

echo ">>> Aplicando namespace"
kubectl apply -f k8s/namespace.yaml

echo ">>> Aplicando secrets"
kubectl apply -f k8s/secrets.yaml

echo ">>> Aplicando configmap"
kubectl apply -f k8s/configmap.yaml

echo ">>> Aplicando deployments e services"
kubectl apply -f k8s/auth-service.yaml
kubectl apply -f k8s/flag-service.yaml
kubectl apply -f k8s/targeting-service.yaml
kubectl apply -f k8s/evaluation-service.yaml
kubectl apply -f k8s/analytics-service.yaml

echo ">>> Aplicando ingress"
kubectl apply -f k8s/ingress.yaml

echo ">>> Aplicando HPA"
kubectl apply -f k8s/hpa.yaml

echo ">>> Tudo aplicado. Status dos pods:"
sleep 5
kubectl get pods -n togglemaster

echo ""
echo ">>> Status do ingress (pegue o ADDRESS para os testes):"
kubectl get ingress -n togglemaster
