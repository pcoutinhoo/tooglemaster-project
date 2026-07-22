#!/bin/bash
# run-all.sh
# Script THE FLASH HAHAHA — roda a sequência inteira do zero, na ordem certa,
# com checagens de pasta embutidas 
# RODAR SEMPRE DA RAIZ DO PROJETO (onde estão as pastas auth-service/,
# flag-service/, infra/, etc.)
#
# Uso: bash run-all.sh

set -e

PROJECT_ROOT=$(pwd)

# --- confirma que está na pasta certa ---
if [ ! -d "infra" ] || [ ! -d "auth-service" ]; then
  echo "!!! ERRO: rode este script da RAIZ do projeto."
  echo "!!! Esperado encontrar as pastas infra/ e auth-service/ aqui: $PROJECT_ROOT"
  exit 1
fi

echo "================================================================"
echo " PASSO 1/9 — Verificando Helm"
echo "================================================================"
if ! command -v helm &> /dev/null; then
  echo "!!! Helm não encontrado. Rode: bash 01-install-helm.sh"
  echo "!!! Depois FECHE e REABRA o terminal, e rode este script de novo."
  exit 1
fi
echo ">>> Helm OK: $(helm version --short 2>/dev/null || helm version)"

echo "================================================================"
echo " PASSO 2/9 — Verificando conta AWS e atualizando LabRole"
echo "================================================================"
cd "$PROJECT_ROOT/infra"
bash 00-check-account.sh
cd "$PROJECT_ROOT"

echo "================================================================"
echo " PASSO 3/9 — Aplicando infraestrutura Terraform"
echo "================================================================"
echo ">>> Isso demora ~20-25 min (RDS e EKS são lentos). Não interrompa."
cd "$PROJECT_ROOT/infra"
terraform init
terraform plan
read -p ">>> Confira o plan acima. Pressione ENTER para aplicar, ou Ctrl+C para cancelar..."
terraform apply -auto-approve
cd "$PROJECT_ROOT"

echo "================================================================"
echo " PASSO 4/9 — Configurando kubectl"
echo "================================================================"
aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster
echo ">>> Aguardando nodes ficarem Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes

echo "================================================================"
echo " PASSO 5/9 — Build e push das imagens Docker"
echo "================================================================"
bash build-and-push.sh

echo "================================================================"
echo " PASSO 6/9 — Instalando Metrics Server + Nginx Ingress"
echo "================================================================"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --wait --timeout 5m

echo ">>> Aguardando Load Balancer externo..."
for i in $(seq 1 30); do
  LB_CHECK=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
  if [ -n "$LB_CHECK" ]; then
    echo ">>> Load Balancer pronto: $LB_CHECK"
    break
  fi
  sleep 5
done

echo "================================================================"
echo " PASSO 7/9 — Gerando secrets a partir dos outputs do Terraform"
echo "================================================================"
bash generate-secrets.sh

echo "================================================================"
echo " PASSO 8/9 — Aplicando manifestos Kubernetes"
echo "================================================================"
bash deploy-k8s.sh

echo "================================================================"
echo " PASSO 9/9 — Rodando migrations SQL"
echo "================================================================"
bash run-migrations.sh
kubectl rollout restart deployment/auth-service -n togglemaster
kubectl rollout restart deployment/flag-service -n togglemaster
kubectl rollout restart deployment/targeting-service -n togglemaster
kubectl rollout status deployment/auth-service -n togglemaster --timeout=120s
kubectl rollout status deployment/flag-service -n togglemaster --timeout=120s
kubectl rollout status deployment/targeting-service -n togglemaster --timeout=120s

echo "================================================================"
echo " QUASE LÁ — falta só gerar a API key"
echo "================================================================"
LB=$(kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo ">>> Load Balancer: http://$LB"
bash update-api-key.sh "http://$LB"

echo "================================================================"
echo " TUDO PRONTO. Rodando teste de fluxo completo..."
echo "================================================================"
bash test-fluxo-completo.sh "http://$LB"

echo ""
echo ">>> INFRA COMPLETA E VALIDADA."
echo ">>> Load Balancer: http://$LB"
echo ">>> API Key salva em: api_key.txt"
echo ">>> Pronto para teste de carga e gravação do vídeo."