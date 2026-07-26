#!/bin/bash
set -e

AUTH_SQL="auth-service/db/init.sql"
FLAG_SQL="flag-service/db/init.sql"
TARGETING_SQL="targeting-service/db/init.sql"

for f in "$AUTH_SQL" "$FLAG_SQL" "$TARGETING_SQL"; do
  [ -f "$f" ] || { echo "!!! $f não encontrado. Rode da RAIZ do projeto."; exit 1; }
done

echo ">>> Lendo endpoints (infra/app)..."
AUTH_DB=$(cd infra/app && terraform output -raw auth_db_endpoint | cut -d: -f1)
FLAG_DB=$(cd infra/app && terraform output -raw flag_db_endpoint | cut -d: -f1)
TARGETING_DB=$(cd infra/app && terraform output -raw targeting_db_endpoint | cut -d: -f1)
DB_PASS="${TF_VAR_db_password:-SenhaMichuruca123}"

kubectl delete pod psql-migrator -n togglemaster --force --grace-period=0 --ignore-not-found=true
kubectl delete configmap migration-sqls -n togglemaster --ignore-not-found=true

kubectl create configmap migration-sqls -n togglemaster \
  --from-file=init-auth.sql="$AUTH_SQL" \
  --from-file=init-flag.sql="$FLAG_SQL" \
  --from-file=init-targeting.sql="$TARGETING_SQL"

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
        psql "postgres://postgres:${DB_PASS}@${AUTH_DB}:5432/auth_db?sslmode=require" -f /sqls/init-auth.sql &&
        psql "postgres://postgres:${DB_PASS}@${FLAG_DB}:5432/flag_db?sslmode=require" -f /sqls/init-flag.sql &&
        psql "postgres://postgres:${DB_PASS}@${TARGETING_DB}:5432/targeting_db?sslmode=require" -f /sqls/init-targeting.sql &&
        echo "Migrations OK"
    volumeMounts:
      - name: sqls
        mountPath: /sqls
  volumes:
    - name: sqls
      configMap:
        name: migration-sqls
EOF

for i in $(seq 1 18); do
  PHASE=$(kubectl get pod psql-migrator -n togglemaster -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
  [ "$PHASE" = "Succeeded" ] || [ "$PHASE" = "Failed" ] && break
  sleep 5
done

kubectl logs -n togglemaster psql-migrator
kubectl delete pod psql-migrator -n togglemaster --ignore-not-found=true
kubectl delete configmap migration-sqls -n togglemaster --ignore-not-found=true