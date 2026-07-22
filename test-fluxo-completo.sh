#!/bin/bash
# test-fluxo-completo.sh
# Testa o fluxo inteiro: cria flag, cria regra de targeting, avalia.
# Usa a API key salva em api_key.txt (gerada pelo update-api-key.sh).
#
# Uso: bash test-fluxo-completo.sh URL_DO_LOAD_BALANCER

set -e

LB=$1
if [ -z "$LB" ]; then
  echo "Uso: bash test-fluxo-completo.sh <URL_DO_LOAD_BALANCER>"
  exit 1
fi

if [ ! -f "api_key.txt" ]; then
  echo "!!! api_key.txt não encontrado. Rode update-api-key.sh primeiro."
  exit 1
fi

API_KEY=$(cat api_key.txt)

echo ">>> 1. Testando health checks..."
for svc in auth flags targeting evaluate analytics; do
  echo -n "  $svc: "
  curl -s "$LB/$svc/health" || echo "FALHOU"
  echo ""
done

echo ""
echo ">>> 2. Criando flag 'nova_ui'..."
curl -s --request POST \
  --url "$LB/flags/flags" \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{"name": "nova_ui", "description": "Testa nova interface", "is_enabled": true}'
echo ""

echo ">>> 3. Criando regra de targeting..."
curl -s --request POST \
  --url "$LB/targeting/rules" \
  --header "Authorization: Bearer $API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{"flag_name": "nova_ui", "is_enabled": true, "rules": {"type": "PERCENTAGE", "value": 50}}'
echo ""

echo ">>> 4. Avaliando a flag..."
curl -s --request GET \
  --url "$LB/evaluate/evaluate?flag_name=nova_ui&user_id=user_42&country=BR" \
  --header "Authorization: Bearer $API_KEY"
echo ""

echo ""
echo ">>> 5. Checando log do evaluation-service (procura por envio ao SQS)..."
sleep 2
kubectl logs -n togglemaster deployment/evaluation-service --tail=5

echo ""
echo ">>> Fluxo completo testado. Se o passo 4 retornou JSON sem erro, está tudo certo."
echo ">>> Para gerar carga e testar o HPA, rode:"
echo "./hey.exe -z 3m -c 150 -H \"Authorization: Bearer $API_KEY\" \"$LB/evaluate/evaluate?flag_name=nova_ui&user_id=user_42&country=BR\""
