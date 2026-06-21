#!/bin/bash
# update-api-key.sh
# Roda DEPOIS que o auth-service estiver de pé e as migrations aplicadas.
# Cria uma API key real via /auth/admin/keys, atualiza o secret do
# evaluation-service automaticamente, e reinicia o deployment.
#
# Uso: bash update-api-key.sh <URL_DO_LOAD_BALANCER>
# Ex:  bash update-api-key.sh http://abc123.elb.amazonaws.com

set -e

LB=$1
if [ -z "$LB" ]; then
  echo "Uso: bash update-api-key.sh <URL_DO_LOAD_BALANCER>"
  echo "Pegue a URL com: kubectl get ingress -n togglemaster"
  exit 1
fi

echo ">>> Criando API key via $LB/auth/admin/keys"
RESPONSE=$(curl -s --request POST \
  --url "$LB/auth/admin/keys" \
  --header 'Authorization: Bearer master123' \
  --header 'Content-Type: application/json' \
  --data '{"name": "tech-challenge-key"}')

echo ">>> Resposta: $RESPONSE"

API_KEY=$(echo "$RESPONSE" | grep -o '"key":"[^"]*' | cut -d'"' -f4)

if [ -z "$API_KEY" ]; then
  echo "!!! Não foi possível extrair a API key. Verifique se o auth-service está de pé e as migrations rodaram."
  exit 1
fi

echo ">>> API key gerada: $API_KEY"
echo "$API_KEY" > api_key.txt
echo ">>> Salva em api_key.txt para reutilizar nos testes"

API_KEY_B64=$(echo -n "$API_KEY" | base64 | tr -d '\n')

echo ">>> Atualizando secret do evaluation-service"
kubectl patch secret evaluation-service-secret -n togglemaster \
  --type merge \
  -p "{\"data\":{\"SERVICE_API_KEY\":\"${API_KEY_B64}\"}}"

echo ">>> Reiniciando evaluation-service"
kubectl rollout restart deployment/evaluation-service -n togglemaster
kubectl rollout status deployment/evaluation-service -n togglemaster --timeout=120s

echo ">>> Pronto. Use esta key nos seus testes:"
echo "$API_KEY"
