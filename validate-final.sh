#!/bin/bash

set -u

NAMESPACE="togglemaster"
ARGO_NAMESPACE="argocd"
ARGO_APP="togglemaster"
AWS_REGION="${AWS_REGION:-us-east-1}"

SERVICES=(
  "auth-service"
  "flag-service"
  "targeting-service"
  "evaluation-service"
  "analytics-service"
)

HPAS=(
  "evaluation-service-hpa"
  "analytics-service-hpa"
)

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  echo "✓ $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "✗ $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  echo "⚠ $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

section() {
  echo
  echo "=========================================="
  echo "$1"
  echo "=========================================="
}

section "1. AWS"

if ! command -v aws >/dev/null 2>&1; then
  fail "AWS CLI não encontrada."
  ACCOUNT_ID=""
elif ! ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
  fail "Sessão AWS inválida ou expirada."
  ACCOUNT_ID=""
else
  pass "AWS autenticada."
  echo "  Account ID: ${ACCOUNT_ID}"
  echo "  Região:     ${AWS_REGION}"
fi

section "2. Kubernetes / EKS"

if ! command -v kubectl >/dev/null 2>&1; then
  fail "kubectl não encontrado."
else
  if kubectl cluster-info >/dev/null 2>&1; then
    pass "Cluster Kubernetes acessível."
  else
    fail "Cluster Kubernetes não está acessível."
  fi
fi

READY_NODES=$(kubectl get nodes \
  --no-headers \
  2>/dev/null |
  awk '$2 == "Ready" {count++} END {print count+0}')

TOTAL_NODES=$(kubectl get nodes \
  --no-headers \
  2>/dev/null |
  wc -l |
  tr -d ' ')

if [ "${TOTAL_NODES:-0}" -gt 0 ] && [ "$READY_NODES" -eq "$TOTAL_NODES" ]; then
  pass "Todos os nodes estão Ready (${READY_NODES}/${TOTAL_NODES})."
else
  fail "Nodes não estão totalmente Ready (${READY_NODES}/${TOTAL_NODES})."
fi

section "3. Namespace"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  pass "Namespace ${NAMESPACE} existe."
else
  fail "Namespace ${NAMESPACE} não existe."
fi

section "4. Deployments"

for service in "${SERVICES[@]}"; do
  if ! kubectl get deployment "$service" -n "$NAMESPACE" >/dev/null 2>&1; then
    fail "Deployment ${service} não existe."
    continue
  fi

  DESIRED=$(kubectl get deployment "$service" \
    -n "$NAMESPACE" \
    -o jsonpath='{.spec.replicas}' 2>/dev/null)

  AVAILABLE=$(kubectl get deployment "$service" \
    -n "$NAMESPACE" \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null)

  DESIRED="${DESIRED:-0}"
  AVAILABLE="${AVAILABLE:-0}"

  if [ "$AVAILABLE" -ge "$DESIRED" ] && [ "$AVAILABLE" -gt 0 ]; then
    pass "${service}: ${AVAILABLE}/${DESIRED} réplicas disponíveis."
  else
    fail "${service}: apenas ${AVAILABLE}/${DESIRED} réplicas disponíveis."
  fi
done

section "5. Services"

for service in "${SERVICES[@]}"; do
  if kubectl get service "$service" -n "$NAMESPACE" >/dev/null 2>&1; then
    pass "Service ${service} existe."
  else
    fail "Service ${service} não existe."
  fi
done

section "6. Secrets"

SECRETS=(
  "auth-service-secret"
  "flag-service-secret"
  "targeting-service-secret"
  "evaluation-service-secret"
  "analytics-service-secret"
)

for secret in "${SECRETS[@]}"; do
  if kubectl get secret "$secret" -n "$NAMESPACE" >/dev/null 2>&1; then
    pass "Secret ${secret} existe."
  else
    fail "Secret ${secret} não existe."
  fi
done

section "7. Imagens em execução"

for service in "${SERVICES[@]}"; do
  IMAGE=$(kubectl get deployment "$service" \
    -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' \
    2>/dev/null || true)

  if [ -z "$IMAGE" ]; then
    fail "${service}: imagem não encontrada."
    continue
  fi

  echo "  ${service}: ${IMAGE}"

  TAG="${IMAGE##*:}"

  if [ "$TAG" = "latest" ]; then
    fail "${service}: ainda está usando latest."
  elif [[ "$TAG" =~ ^[0-9a-f]{7,40}$ ]]; then
    pass "${service}: tag baseada em commit SHA (${TAG})."
  else
    warn "${service}: tag '${TAG}' não parece commit SHA."
  fi

  if [ -n "${ACCOUNT_ID:-}" ]; then
    EXPECTED_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    if [[ "$IMAGE" == "${EXPECTED_REGISTRY}/"* ]]; then
      pass "${service}: imagem pertence à conta AWS atual."
    else
      fail "${service}: imagem aponta para outra conta/registry."
    fi
  fi
done

section "8. HPA"

for hpa in "${HPAS[@]}"; do
  if kubectl get hpa "$hpa" -n "$NAMESPACE" >/dev/null 2>&1; then
    TARGET=$(kubectl get hpa "$hpa" \
      -n "$NAMESPACE" \
      -o jsonpath='{.spec.scaleTargetRef.name}' \
      2>/dev/null)

    MIN=$(kubectl get hpa "$hpa" \
      -n "$NAMESPACE" \
      -o jsonpath='{.spec.minReplicas}' \
      2>/dev/null)

    MAX=$(kubectl get hpa "$hpa" \
      -n "$NAMESPACE" \
      -o jsonpath='{.spec.maxReplicas}' \
      2>/dev/null)

    pass "${hpa}: alvo=${TARGET}, min=${MIN}, max=${MAX}."
  else
    fail "HPA ${hpa} não existe."
  fi
done

if kubectl top pods -n "$NAMESPACE" >/dev/null 2>&1; then
  pass "Metrics Server respondendo."
else
  warn "Metrics Server ainda não está respondendo."
fi

section "9. ArgoCD"

if ! kubectl get application "$ARGO_APP" \
  -n "$ARGO_NAMESPACE" >/dev/null 2>&1; then

  fail "Application ${ARGO_APP} não encontrada no ArgoCD."
else
  SYNC_STATUS=$(kubectl get application "$ARGO_APP" \
    -n "$ARGO_NAMESPACE" \
    -o jsonpath='{.status.sync.status}' \
    2>/dev/null)

  HEALTH_STATUS=$(kubectl get application "$ARGO_APP" \
    -n "$ARGO_NAMESPACE" \
    -o jsonpath='{.status.health.status}' \
    2>/dev/null)

  if [ "$SYNC_STATUS" = "Synced" ]; then
    pass "ArgoCD: Synced."
  else
    fail "ArgoCD: sync=${SYNC_STATUS:-desconhecido}."
  fi

  if [ "$HEALTH_STATUS" = "Healthy" ]; then
    pass "ArgoCD: Healthy."
  else
    fail "ArgoCD: health=${HEALTH_STATUS:-desconhecido}."
  fi
fi

section "10. Ingress / Load Balancer"

if kubectl get ingress togglemaster-ingress \
  -n "$NAMESPACE" >/dev/null 2>&1; then

  LB=$(kubectl get ingress togglemaster-ingress \
    -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
    2>/dev/null)

  if [ -n "$LB" ]; then
    pass "Ingress possui Load Balancer."
    echo "  http://${LB}"
  else
    warn "Ingress existe, mas o hostname do Load Balancer ainda não apareceu."
  fi
else
  fail "Ingress togglemaster-ingress não existe."
fi

section "RESUMO"

echo "Sucessos: ${PASS_COUNT}"
echo "Avisos:   ${WARN_COUNT}"
echo "Falhas:   ${FAIL_COUNT}"
echo

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "=========================================="
  echo " ✓ AMBIENTE PRONTO PARA GRAVAÇÃO"
  echo "=========================================="

  if [ "$WARN_COUNT" -gt 0 ]; then
    echo "Há ${WARN_COUNT} aviso(s) não bloqueante(s) para revisar."
  fi

  exit 0
else
  echo "=========================================="
  echo " ✗ AMBIENTE AINDA NÃO ESTÁ PRONTO"
  echo "=========================================="
  echo "Corrija as ${FAIL_COUNT} falha(s) acima antes da gravação."
  exit 1
fi
