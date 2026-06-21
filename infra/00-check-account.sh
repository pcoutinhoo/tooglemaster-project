set -e

echo ">>> Verificando identidade AWS atual..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo ">>> Account ID atual: $ACCOUNT_ID"

echo ">>> Buscando ARN da LabRole..."
LAB_ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
echo ">>> LabRole ARN: $LAB_ROLE_ARN"

TFVARS_FILE="terraform.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
  echo "!!! $TFVARS_FILE não encontrado nesta pasta. Rode este script de dentro de infra/"
  exit 1
fi

# Atualiza ou adiciona a linha lab_role_arn no tfvars
if grep -q "^lab_role_arn" "$TFVARS_FILE"; then
  # Usa | como delimitador no sed porque o ARN contém /
  sed -i "s|^lab_role_arn.*|lab_role_arn = \"$LAB_ROLE_ARN\"|" "$TFVARS_FILE"
else
  echo "lab_role_arn = \"$LAB_ROLE_ARN\"" >> "$TFVARS_FILE"
fi

echo ">>> terraform.tfvars atualizado com sucesso:"
grep "lab_role_arn" "$TFVARS_FILE"

echo ""
echo ">>> Salvando ACCOUNT_ID em account_id.txt para os outros scripts usarem"
echo "$ACCOUNT_ID" > ../account_id.txt

echo ""
echo ">>> Pronto. Pode rodar: terraform init && terraform plan && terraform apply -auto-approve"
