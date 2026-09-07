#!/bin/bash

set -euo pipefail

LB="${1:-}"

if [ -z "$LB" ]; then
  echo "Uso: bash update-api-key.sh <URL_DO_LOAD_BALANCER>"
  echo "Exemplo: bash update-api-key.sh http://abc123.elb.amazonaws.com"
  exit 1
fi

echo ">>> Obtendo MASTER_KEY..."

if [ -z "${MASTER_KEY:-}" ]; then
  MASTER_KEY_B64=$(kubectl get secret auth-service-secret \
    -n togglemaster \
    -o jsonpath='{.data.MASTER_KEY}')

  if [ -z "$MASTER_KEY_B64" ]; then
    echo "!!! MASTER_KEY não encontrada no auth-service-secret."
    exit 1
  fi

  MASTER_KEY=$(printf '%s' "$MASTER_KEY_B64" | base64 -d)
fi

echo "✓ MASTER_KEY disponível"

echo ">>> Criando API key..."

RESPONSE=$(curl \
  --fail \
  --silent \
  --show-error \
  --request POST \
  --url "$LB/auth/admin/keys" \
  --header "Authorization: Bearer ${MASTER_KEY}" \
  --header 'Content-Type: application/json' \
  --data '{"name":"tech-challenge-key"}')

API_KEY=$(printf '%s' "$RESPONSE" |
  sed -n 's/.*"key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ -z "$API_KEY" ]; then
  echo "!!! A API key não pôde ser extraída da resposta."
  exit 1
fi

echo "✓ API key criada"

API_KEY_B64=$(printf '%s' "$API_KEY" | base64 | tr -d '\n')

echo ">>> Atualizando evaluation-service-secret..."

kubectl patch secret evaluation-service-secret \
  -n togglemaster \
  --type merge \
  -p "{\"data\":{\"SERVICE_API_KEY\":\"${API_KEY_B64}\"}}" >/dev/null

echo "✓ Secret atualizado"

echo ">>> Reiniciando evaluation-service..."

kubectl rollout restart \
  deployment/evaluation-service \
  -n togglemaster >/dev/null

kubectl rollout status \
  deployment/evaluation-service \
  -n togglemaster \
  --timeout=120s

echo "✓ API key configurada com sucesso."
