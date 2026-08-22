#!/bin/bash
set -e
PROJECT_ROOT=$(pwd)

[ -d "infra" ] && [ -d "auth-service" ] || { echo "!!! Rode da RAIZ do projeto."; exit 1; }

echo "=== 1/10 Helm ==="
command -v helm &>/dev/null || { echo "!!! Rode: bash 01-install-helm.sh (depois reabra o terminal)"; exit 1; }

echo "=== 2/10 Conta AWS + LabRole ==="
source setup-env.sh
(cd infra && bash 00-check-account.sh)

echo "=== 3/10 Backend S3 (bootstrap) ==="
bash setup-backend.sh

echo "=== 4/10 Terraform apply (infra/app) ==="
cd infra/app
terraform init
terraform plan
read -p ">>> ENTER para aplicar, Ctrl+C para cancelar..."
terraform apply -auto-approve
cd "$PROJECT_ROOT"

echo "=== 5/10 kubectl ==="
aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo "=== 6/10 Build e push imagens ==="
bash build-and-push.sh

echo "=== 7/10 Metrics Server + Nginx Ingress ==="
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace --wait --timeout 5m

echo "=== 8/10 Secrets + Deploy K8s ==="
bash generate-secrets.sh
bash deploy-k8s.sh

echo "=== 9/10 Migrations ==="
bash run-migrations.sh
kubectl rollout restart deployment/auth-service deployment/flag-service deployment/targeting-service -n togglemaster
kubectl rollout status deployment/auth-service -n togglemaster --timeout=120s
kubectl rollout status deployment/flag-service -n togglemaster --timeout=120s
kubectl rollout status deployment/targeting-service -n togglemaster --timeout=120s

echo "=== 10/10 API key + teste ==="
LB=$(kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
bash update-api-key.sh "http://$LB"
bash test-fluxo-completo.sh "http://$LB"

echo ">>> PRONTO. LB: http://$LB"