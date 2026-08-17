#!/bin/bash
# install-argocd.sh
# Instala (ou reinstala) o ArgoCD no cluster EKS atual e aplica o Application
# que sincroniza o repositorio GitOps do time (pcoutinhoo/togglemaster-gitops,
# branch develop, pasta k8s/). Compativel com Windows (Git Bash) e macOS.
#
# Uso: bash install-argocd.sh

set -e

echo "================================================================"
echo " 1/4 — Verificando cluster"
echo "================================================================"
kubectl cluster-info &>/dev/null || {
  echo "!!! kubectl nao consegue falar com o cluster."
  echo "!!! Rode: aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster"
  exit 1
}
kubectl get nodes

echo "================================================================"
echo " 2/4 — Instalando/atualizando ArgoCD (namespace argocd)"
echo "================================================================"
kubectl create namespace argocd 2>/dev/null || echo ">>> Namespace argocd ja existe."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update
helm upgrade --install argocd argo/argo-cd --namespace argocd --wait --timeout 5m
kubectl get pods -n argocd

echo "================================================================"
echo " 3/4 — Aplicando o Application"
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
echo " 4/4 — Pronto"
echo "================================================================"
kubectl get applications -n argocd
echo ""
echo ">>> Se ficar Degraded/ImagePullBackOff: a tag de imagem no repo GitOps"
echo ">>> ainda nao aponta pra uma imagem valida no ECR — isso e responsabilidade"
echo ">>> da pipeline de CI (job update-gitops), nao deste script."
echo ""
echo ">>> Senha do admin (usuario: admin):"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo ">>> Para ver a UI:"
echo ">>>   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ">>>   depois abra https://localhost:8080"
