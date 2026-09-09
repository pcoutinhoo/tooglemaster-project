#!/bin/bash

set -euo pipefail

AUTH_SQL="auth-service/db/init.sql"
FLAG_SQL="flag-service/db/init.sql"
TARGETING_SQL="targeting-service/db/init.sql"

for f in "$AUTH_SQL" "$FLAG_SQL" "$TARGETING_SQL"; do
  if [ ! -f "$f" ]; then
    echo "!!! $f não encontrado. Rode este script da raiz do projeto."
    exit 1
  fi
done

echo ">>> Validando namespace e Secrets..."

kubectl get namespace togglemaster >/dev/null
kubectl get secret auth-service-secret -n togglemaster >/dev/null
kubectl get secret flag-service-secret -n togglemaster >/dev/null
kubectl get secret targeting-service-secret -n togglemaster >/dev/null

echo ">>> Preparando SQLs..."

kubectl delete pod psql-migrator \
  -n togglemaster \
  --force \
  --grace-period=0 \
  --ignore-not-found=true >/dev/null 2>&1 || true

kubectl delete configmap migration-sqls \
  -n togglemaster \
  --ignore-not-found=true >/dev/null

kubectl create configmap migration-sqls \
  -n togglemaster \
  --from-file=init-auth.sql="$AUTH_SQL" \
  --from-file=init-flag.sql="$FLAG_SQL" \
  --from-file=init-targeting.sql="$TARGETING_SQL"

echo ">>> Executando migrations..."

cat <<'EOF_POD' | kubectl apply -f -
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
      env:
        - name: AUTH_DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: auth-service-secret
              key: DATABASE_URL
        - name: FLAG_DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: flag-service-secret
              key: DATABASE_URL
        - name: TARGETING_DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: targeting-service-secret
              key: DATABASE_URL
      command:
        - /bin/sh
        - -c
      args:
        - |
          set -e
          psql "$AUTH_DATABASE_URL" -f /sqls/init-auth.sql
          psql "$FLAG_DATABASE_URL" -f /sqls/init-flag.sql
          psql "$TARGETING_DATABASE_URL" -f /sqls/init-targeting.sql
          echo "Migrations OK"
      volumeMounts:
        - name: sqls
          mountPath: /sqls
  volumes:
    - name: sqls
      configMap:
        name: migration-sqls
EOF_POD

echo ">>> Aguardando migrator..."

for i in $(seq 1 36); do
  PHASE=$(kubectl get pod psql-migrator \
    -n togglemaster \
    -o jsonpath='{.status.phase}' \
    2>/dev/null || echo "Pending")

  if [ "$PHASE" = "Succeeded" ] || [ "$PHASE" = "Failed" ]; then
    break
  fi

  sleep 5
done

echo ""
kubectl logs -n togglemaster psql-migrator || true

PHASE=$(kubectl get pod psql-migrator \
  -n togglemaster \
  -o jsonpath='{.status.phase}')

kubectl delete pod psql-migrator \
  -n togglemaster \
  --ignore-not-found=true >/dev/null

kubectl delete configmap migration-sqls \
  -n togglemaster \
  --ignore-not-found=true >/dev/null

if [ "$PHASE" != "Succeeded" ]; then
  echo "!!! Migrations falharam."
  exit 1
fi

echo "✓ Migrations concluídas."
