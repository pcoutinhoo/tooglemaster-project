#!/bin/bash
# install-argocd.sh
# Instala (ou reinstala) o ArgoCD no cluster EKS atual, garante que a tag de
# imagem fixa esteja publicada no ECR (senao os pods sincronizados pelo Argo
# ficam em ImagePullBackOff) e aplica o Application que sincroniza o
# repositorio GitOps dedicado. Compativel com Windows (Git Bash) e macOS.
#
# Uso: bash install-argocd.sh

set -e

IMAGE_TAG="v1.0.0-manual"
SERVICES="auth-service flag-service targeting-service evaluation-service analytics-service"

echo "================================================================"
echo " 1/5 — Verificando cluster"
echo "================================================================"
kubectl cluster-info &>/dev/null || {
  echo "!!! kubectl nao consegue falar com o cluster."
  echo "!!! Rode: aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster"
  exit 1
}
kubectl get nodes

echo "================================================================"
echo " 2/5 — Instalando/atualizando ArgoCD (namespace argocd)"
echo "================================================================"
kubectl create namespace argocd 2>/dev/null || echo ">>> Namespace argocd ja existe."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update
helm upgrade --install argocd argo/argo-cd --namespace argocd --wait --timeout 5m
kubectl get pods -n argocd

echo "================================================================"
echo " 3/5 — Garantindo a tag fixa ($IMAGE_TAG) no ECR"
echo "================================================================"
if [ ! -f "account_id.txt" ]; then
  echo "!!! account_id.txt nao encontrado. Rode 'bash run-all.sh' (ou infra/00-check-account.sh) primeiro."
  exit 1
fi
ACCOUNT_ID=$(cat account_id.txt)
ECR="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"

for svc in $SERVICES; do
  if docker image inspect "$svc:latest" &>/dev/null; then
    docker tag "$svc:latest" "$ECR/togglemaster/$svc:$IMAGE_TAG"
    docker push "$ECR/togglemaster/$svc:$IMAGE_TAG"
  else
    echo "!!! Imagem local $svc:latest nao encontrada — pulei o retag."
    echo "!!! Se o Application ficar Degraded por ImagePullBackOff, rode 'bash build-and-push.sh' e execute este script de novo."
  fi
done

echo "================================================================"
echo " 4/5 — Aplicando o Application"
echo "================================================================"
kubectl apply -f argocd/application.yaml

echo ">>> Aguardando o primeiro sync (ate 4 min)..."
for i in $(seq 1 24); do
  SYNC=$(kubectl get application togglemaster -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "?")
  HEALTH=$(kubectl get application togglemaster -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "?")
  echo "    ($i/24) sync=$SYNC health=$HEALTH"
  [ "$SYNC" = "Synced" ] && [ "$HEALTH" = "Healthy" ] && break
  sleep 10
done

echo "================================================================"
echo " 5/5 — Pronto"
echo "================================================================"
kubectl get applications -n argocd
echo ""
echo ">>> Senha do admin (usuario: admin):"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo ">>> Para ver a UI:"
echo ">>>   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ">>>   depois abra https://localhost:8080"
