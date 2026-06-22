#!/bin/bash
# generate-secrets.sh
# Gera o k8s/secrets.yaml automaticamente a partir dos outputs do Terraform.
# Elimina o trabalho manual de copiar endpoint, gerar base64 e colar no YAML.
#
# Rodar de dentro de infra/ DEPOIS do terraform apply.
# A SERVICE_API_KEY ainda precisa ser preenchida manualmente depois
# (porque ela só existe depois que você criar uma key via API, que só
# existe depois que o auth-service estiver rodando — ver passo 9 do fluxo).

set -e

cd infra/ 2>/dev/null || true

echo ">>> Lendo outputs do Terraform..."
AUTH_DB=$(terraform output -raw auth_db_endpoint)
FLAG_DB=$(terraform output -raw flag_db_endpoint)
TARGETING_DB=$(terraform output -raw targeting_db_endpoint)
REDIS_EP=$(terraform output -raw redis_endpoint)
SQS_URL=$(terraform output -raw sqs_url)

DB_PASS="SenhaMichuruca123"
MASTER_KEY="master123"

AUTH_DB_HOST=$(echo $AUTH_DB | cut -d: -f1)
FLAG_DB_HOST=$(echo $FLAG_DB | cut -d: -f1)
TARGETING_DB_HOST=$(echo $TARGETING_DB | cut -d: -f1)

AUTH_URL="postgres://postgres:${DB_PASS}@${AUTH_DB_HOST}:5432/auth_db?sslmode=require"
FLAG_URL="postgres://postgres:${DB_PASS}@${FLAG_DB_HOST}:5432/flag_db?sslmode=require"
TARGETING_URL="postgres://postgres:${DB_PASS}@${TARGETING_DB_HOST}:5432/targeting_db?sslmode=require"
REDIS_URL="redis://${REDIS_EP}:6379"

b64() { echo -n "$1" | base64 | tr -d '\n'; }

AUTH_DB_B64=$(b64 "$AUTH_URL")
FLAG_DB_B64=$(b64 "$FLAG_URL")
TARGETING_DB_B64=$(b64 "$TARGETING_URL")
REDIS_B64=$(b64 "$REDIS_URL")
SQS_B64=$(b64 "$SQS_URL")
MASTER_KEY_B64=$(b64 "$MASTER_KEY")

cd - > /dev/null

mkdir -p k8s

cat > k8s/secrets.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: auth-service-secret
  namespace: togglemaster
type: Opaque
data:
  DATABASE_URL: ${AUTH_DB_B64}
  MASTER_KEY: ${MASTER_KEY_B64}

---
apiVersion: v1
kind: Secret
metadata:
  name: flag-service-secret
  namespace: togglemaster
type: Opaque
data:
  DATABASE_URL: ${FLAG_DB_B64}

---
apiVersion: v1
kind: Secret
metadata:
  name: targeting-service-secret
  namespace: togglemaster
type: Opaque
data:
  DATABASE_URL: ${TARGETING_DB_B64}

---
apiVersion: v1
kind: Secret
metadata:
  name: evaluation-service-secret
  namespace: togglemaster
type: Opaque
data:
  REDIS_URL: ${REDIS_B64}
  AWS_SQS_URL: ${SQS_B64}
  SERVICE_API_KEY: $(b64 "PLACEHOLDER")

---
apiVersion: v1
kind: Secret
metadata:
  name: analytics-service-secret
  namespace: togglemaster
type: Opaque
data:
  AWS_SQS_URL: ${SQS_B64}
EOF

echo ">>> k8s/secrets.yaml gerado com sucesso."
echo ">>> ATENÇÃO: SERVICE_API_KEY ainda está como placeholder."
echo ">>> Depois de aplicar e rodar as migrations, gere uma API key e rode update-api-key.sh"
