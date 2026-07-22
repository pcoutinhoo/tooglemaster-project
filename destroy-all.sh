#!/bin/bash
# destroy-all.sh
# Destroy seguro e completo. Remove o Load Balancer criado pelo Helm ANTES
# de rodar terraform destroy — resolve o erro recorrente de DependencyViolation
# na subnet/Internet Gateway. Compatível com Windows (Git Bash) e macOS.


set -e

echo "================================================================"
echo " PASSO 1/4 — Removendo Nginx Ingress (e o Load Balancer com ele)"
echo "================================================================"

# Tenta desinstalar o Helm release se o kubectl ainda responder
if kubectl cluster-info &>/dev/null 2>&1; then
  if helm list -n ingress-nginx 2>/dev/null | grep -q ingress-nginx; then
    echo ">>> Desinstalando ingress-nginx via Helm..."
    helm uninstall ingress-nginx -n ingress-nginx
    echo ">>> Aguardando 90s para a AWS remover o Load Balancer e suas ENIs..."
    echo ">>> (não pule essa espera — as subnets só liberam depois que as ENIs somem)"
    sleep 90
  else
    echo ">>> Nenhum release ingress-nginx encontrado. Pulando."
  fi
else
  echo ">>> kubectl não responde (cluster pode já estar fora). Pulando Helm."
fi

echo ""
echo "================================================================"
echo " PASSO 2/4 — Verificando Load Balancers pendentes"
echo "================================================================"
echo ">>> Load Balancers ativos (elbv2 — NLB/ALB):"
aws elbv2 describe-load-balancers --region us-east-1 \
  --query 'LoadBalancers[*].[LoadBalancerName,DNSName]' \
  --output table 2>/dev/null || echo "(nenhum ou permissão negada)"

echo ""
echo ">>> Load Balancers clássicos (ELB):"
aws elb describe-load-balancers --region us-east-1 \
  --query 'LoadBalancerDescriptions[*].LoadBalancerName' \
  --output table 2>/dev/null || echo "(nenhum ou permissão negada)"

echo ""
echo "!!! Se algum Load Balancer do projeto aparecer acima, delete manualmente:"
echo "!!!   aws elbv2 delete-load-balancer --load-balancer-arn ARN --region us-east-1"
echo "!!!   aws elb delete-load-balancer --load-balancer-name NOME --region us-east-1"
echo ""
read -p ">>> Pressione ENTER quando confirmar que não há LBs pendentes (ou Ctrl+C para cancelar)..."

echo ""
echo "================================================================"
echo " PASSO 3/4 — Terraform destroy"
echo "================================================================"
cd infra
terraform destroy -auto-approve
cd ..

echo ""
echo "================================================================"
echo " PASSO 4/4 — Limpando arquivos locais de estado"
echo "================================================================"
rm -f account_id.txt api_key.txt
rm -f infra/k8s/secrets.yaml
echo ">>> Arquivos locais limpos."

echo ""
echo ">>> Destroy completo! Infra removida. Pronto para recriar com: bash run-all.sh"
