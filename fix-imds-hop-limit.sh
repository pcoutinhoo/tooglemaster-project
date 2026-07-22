#!/bin/bash
# fix-imds-hop-limit.sh
# FALLBACK: só é necessário se NÃO usar o eks.tf novo (com launch_template).
# Se usar o eks.tf corrigido deste pacote, este script é desnecessário —
# o hop limit já nasce correto.
#
# Corrige o IMDS hop limit das instâncias EC2 do node group, permitindo que
# pods acessem a LabRole via metadata da instância (resolve erro
# "NoCredentialProviders: no valid providers in chain" no SQS/DynamoDB).

set -e

REGION="us-east-1"
NODEGROUP_NAME="togglemaster-nodes"

echo ">>> Buscando instâncias do node group $NODEGROUP_NAME..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=$NODEGROUP_NAME" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --region $REGION \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "!!! Nenhuma instância encontrada. O node group já está pronto?"
  exit 1
fi

for ID in $INSTANCE_IDS; do
  echo ">>> Corrigindo hop limit em $ID"
  aws ec2 modify-instance-metadata-options \
    --instance-id $ID \
    --http-put-response-hop-limit 2 \
    --http-endpoint enabled \
    --region $REGION
done

echo ">>> Confirmando..."
aws ec2 describe-instances \
  --instance-ids $INSTANCE_IDS \
  --query 'Reservations[*].Instances[*].[InstanceId,MetadataOptions.HttpPutResponseHopLimit]' \
  --region $REGION \
  --output table

echo ">>> Hop limit corrigido. Reinicie os deployments que usam AWS SDK:"
echo "kubectl rollout restart deployment/evaluation-service -n togglemaster"
echo "kubectl rollout restart deployment/analytics-service -n togglemaster"
