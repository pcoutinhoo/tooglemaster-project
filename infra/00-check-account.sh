#!/bin/bash
set -e
echo ">>> Verificando identidade AWS atual..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo ">>> Account ID: $ACCOUNT_ID"

LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
echo ">>> LabRole ARN: $LAB_ROLE_ARN"

export TF_VAR_lab_role_arn="$LAB_ROLE_ARN"
echo "$ACCOUNT_ID" > ../account_id.txt

echo ">>> OK. account_id.txt atualizado em: $(cd .. && pwd)/account_id.txt"
echo ">>> LEMBRETE: rode 'export TF_VAR_lab_role_arn=\"$LAB_ROLE_ARN\"' no shell principal"
echo ">>> (esse export só vale dentro deste script, não propaga pro terminal pai)"
