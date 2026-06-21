#!/bin/bash
# run-migrations.sh
# Cria as tabelas (api_keys, flags, targeting_rules) nos 3 bancos RDS.
#   auth-service/db/init.sql
#   flag-service/db/init.sql
#   targeting-service/db/init.sql
# Rodar da RAIZ do projeto

set -e

AUTH_SQL="auth-service/db/init.sql"
FLAG_SQL="flag-service/db/init.sql"
TARGETING_SQL="targeting-service/db/init.sql"

# Confere se os 3 arquivos existem antes de continuar
for f in "$AUTH_SQL" "$FLAG_SQL" "$TARGETING_SQL"; do
  if [ ! -f "$f" ]; then
    echo "!!! Arquivo não encontrado: $f"
    echo "!!! Rode este script da RAIZ do projeto (onde estão as pastas auth-service/, flag-service/, etc.)"
    exit 1
  fi
done

echo ">>> Lendo endpoints do Terraform..."
AUTH_DB=$(cd infra && terraform output -raw auth_db_endpoint | cut -d: -f1)
FLAG_DB=$(cd infra && terraform output -raw flag_db_endpoint | cut -d: -f1)
TARGETING_DB=$(cd infra && terraform output -raw targeting_db_endpoint | cut -d: -f1)

DB_PASS="SenhaMichuruca123"

echo ">>> auth: $AUTH_DB"
echo ">>> flag: $FLAG_DB"
echo ">>> targeting: $TARGETING_DB"

echo ">>> Removendo pod psql-migrator antigo, se existir"
kubectl delete pod psql-migrator -n togglemaster --force --grace-period=0 --ignore-not-found=true
kubectl delete configmap migration-sqls -n togglemaster --ignore-not-found=true

echo ">>> Criando ConfigMap com os 3 SQLs reais do projeto"
kubectl create configmap migration-sqls -n togglemaster \
  --from-file=init-auth.sql="$AUTH_SQL" \
  --from-file=init-flag.sql="$FLAG_SQL" \
  --from-file=init-targeting.sql="$TARGETING_SQL"

echo ">>> Criando pod temporário que aplica os 3 SQLs"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: psql-migrator
  namespace: togglemaster
spec:
  restartPolicy: Never
  containers:
  - name: psql
    image: postgres:15
    command: ["/bin/sh", "-c"]
    args:
      - |
        echo ">>> auth_db" &&
        psql "postgres://postgres:${DB_PASS}@${AUTH_DB}:5432/auth_db?sslmode=require" -f /sqls/init-auth.sql &&
        echo ">>> flag_db" &&
        psql "postgres://postgres:${DB_PASS}@${FLAG_DB}:5432/flag_db?sslmode=require" -f /sqls/init-flag.sql &&
        echo ">>> targeting_db" &&
        psql "postgres://postgres:${DB_PASS}@${TARGETING_DB}:5432/targeting_db?sslmode=require" -f /sqls/init-targeting.sql &&
        echo ">>> Todas as migrations aplicadas com sucesso"
    volumeMounts:
      - name: sqls
        mountPath: /sqls
  volumes:
    - name: sqls
      configMap:
        name: migration-sqls
EOF

echo ">>> Aguardando o pod terminar (até 90s)..."
for i in $(seq 1 18); do
  PHASE=$(kubectl get pod psql-migrator -n togglemaster -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
  if [ "$PHASE" == "Succeeded" ] || [ "$PHASE" == "Failed" ]; then
    break
  fi
  sleep 5
done

echo ">>> Logs da migration:"
kubectl logs -n togglemaster psql-migrator

echo ">>> Limpando recursos temporários"
kubectl delete pod psql-migrator -n togglemaster --ignore-not-found=true
kubectl delete configmap migration-sqls -n togglemaster --ignore-not-found=true

echo ">>> Migrations concluídas."