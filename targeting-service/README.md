# targeting-service (Python)

Este é o serviço de regras de segmentação (targeting) do projeto ToggleMaster. Ele é responsável por gerenciar regras complexas (ex: "50% dos usuários", "usuários do país X") para uma feature flag específica.

**IMPORTANTE:** Este serviço também é protegido e depende que o `auth-service` esteja rodando (ex: em `http://localhost:8001`).

## 📦 Pré-requisitos (Local)

* [Python](https://www.python.org/) (versão 3.9 ou superior)
* [PostgreSQL](https://www.postgresql.org/download/)
* O `auth-service` deve estar rodando.

## 🚀 Rodando Localmente

1.  **Clone o repositório** e entre na pasta `targeting-service`.

2.  **Prepare o Banco de Dados:**
    * Crie um banco de dados no seu PostgreSQL (ex: `targeting_db`).
    * Execute o script `db/init.sql` para criar a tabela `targeting_rules`:
        ```bash
        psql -U seu_usuario -d targeting_db -f db/init.sql
        ```

3.  **Configure as Variáveis de Ambiente:**
    Crie um arquivo chamado `.env` na raiz desta pasta (`targeting-service/`) com o seguinte conteúdo:
    ```.env
    # String de conexão do seu banco de dados PostgreSQL
    DATABASE_URL="postgres://SEU_USUARIO:SUA_SENHA@localhost:5432/targeting_db"
    
    # Porta que este serviço (targeting-service) irá rodar
    PORT="8003"
    
    # URL do auth-service (que deve estar rodando na porta 8001)
    AUTH_SERVICE_URL="http://localhost:8001"
    ```

4.  **Instale as Dependências:**
    ```bash
    pip install -r requirements.txt
    ```

5.  **Inicie o Serviço:**
    ```bash
    gunicorn --bind 0.0.0.0:8003 app:app
    ```
    O servidor estará rodando em `http://localhost:8003`.

## 🧪 Testando os Endpoints

Lembre-se de obter sua `SUA_CHAVE_API` no `auth-service` (veja o README do `flag-service`).

**1. Verifique a Saúde (Health Check):**
```bash
curl http://localhost:8003/health
```
Saída esperada: `{"status":"ok"}`

**2. Crie uma nova Regra de Segmentação:** Vamos criar uma regra para a flag enable-new-dashboard (que você criou no flag-service). Esta regra fará a flag aparecer para 50% dos usuários.
```bash
curl -X POST http://localhost:8003/rules \
-H "Content-Type: application/json" \
-H "Authorization: Bearer SUA_CHAVE_API" \
-d '{
    "flag_name": "enable-new-dashboard",
    "is_enabled": true,
    "rules": {
        "type": "PERCENTAGE",
        "value": 50
    }
}'
```
Saída esperada: (Um JSON com os dados da regra criada).

**3. Busque a Regra que você criou:**
```bash
curl http://localhost:8003/rules/enable-new-dashboard \
-H "Authorization: Bearer SUA_CHAVE_API"
```
Saída esperada: (O JSON da regra que você acabou de criar).

**4. Atualize a Regra (mude para 75%):**
```bash
curl -X PUT http://localhost:8003/rules/enable-new-dashboard \
-H "Content-Type: application/json" \
-H "Authorization: Bearer SUA_CHAVE_API" \
-d '{
    "rules": {
        "type": "PERCENTAGE",
        "value": 75
    }
}'
```
Saída esperada: (O JSON da regra atualizada, com `"value": 75`).


# ToggleMaster — README de execução (Tech Challenge Fase 2)

Este README documenta a estrutura de pastas esperada e o passo a passo exato
para subir toda a infraestrutura do zero. Use o `run-all.sh` para rodar tudo
de forma semi-automática, ou siga os passos manuais se quiser mais controle.

---

## Estrutura de pastas esperada

```
tooglemaster-project/              <- RAIZ. Rode a maioria dos scripts daqui.
├── auth-service/
│   ├── db/init.sql
│   └── Dockerfile
├── flag-service/
│   ├── db/init.sql
│   └── Dockerfile
├── targeting-service/
│   ├── db/init.sql
│   └── Dockerfile
├── evaluation-service/
│   └── Dockerfile
├── analytics-service/
│   └── Dockerfile
├── infra/                          <- Terraform. Scripts de conta rodam daqui.
│   ├── eks.tf
│   ├── variables.tf
│   ├── terraform.tfvars
│   ├── rds.tf, vpc.tf, etc.
│   └── 00-check-account.sh
├── k8s/                            <- gerado automaticamente por generate-secrets.sh
│   ├── namespace.yaml
│   ├── secrets.yaml                <- GERADO, não editar manualmente
│   ├── configmap.yaml
│   ├── *-service.yaml (deployments + services)
│   ├── ingress.yaml
│   └── hpa.yaml
├── run-all.sh                      <- script mestre, roda tudo em sequência
├── 01-install-helm.sh
├── build-and-push.sh
├── generate-secrets.sh
├── run-migrations.sh
├── deploy-k8s.sh
├── update-api-key.sh
├── test-fluxo-completo.sh
└── fix-imds-hop-limit.sh           <- fallback, normalmente não precisa
```

**Regra de ouro**: scripts na raiz rodam *da raiz*. O único script que roda
de dentro de `infra/` é o `00-check-account.sh`. Todos os outros (`build-and-push.sh`,
`generate-secrets.sh`, `run-migrations.sh`, `deploy-k8s.sh`, `update-api-key.sh`,
`test-fluxo-completo.sh`) já fazem `cd infra` internamente quando precisam ler
outputs do Terraform — você não precisa entrar na pasta manualmente.

---

## OPÇÃO A — Rodar tudo de uma vez

```bash
cd tooglemaster-project/   # raiz do projeto
bash run-all.sh
```

Isso roda os 9 passos abaixo em sequência, com pausas de confirmação nos
pontos críticos (antes do `terraform apply`). Leva ~30-35 min no total,
a maior parte esperando RDS e EKS subirem.

Se o Helm não estiver instalado, o script para e te avisa — rode
`bash 01-install-helm.sh`, **feche e reabra o terminal**, e rode `run-all.sh`
de novo (ele retoma do zero, mas como o Terraform usa state, os passos já
feitos não são refeitos).

---

## OPÇÃO B — Passo a passo manual (se quiser mais controle)

### Passo 1 — Verifica o Helm
**Onde rodar:** raiz do projeto
```bash
bash 01-install-helm.sh
# se instalar agora, FECHE e REABRA o Git Bash antes de continuar
helm version
```
**O que faz:** confirma que o Helm (gerenciador de pacotes do Kubernetes,
usado para instalar o Nginx Ingress) está disponível no PATH.

---

### Passo 2 — Confirma a conta AWS e atualiza a LabRole
**Onde rodar:** dentro de `infra/`
```bash
cd infra
bash 00-check-account.sh
cd ..
```
**O que faz:** o account ID do AWS Academy muda toda vez que você abre uma
sessão nova. Este script descobre o ID atual e o ARN da `LabRole`
correspondente, e atualiza sozinho o `terraform.tfvars`. Sem isso, o
`terraform apply` falha com "Cross-account pass role is not allowed".

---

### Passo 3 — Sobe toda a infraestrutura
**Onde rodar:** dentro de `infra/`
```bash
cd infra
terraform init
terraform plan
terraform apply -auto-approve
cd ..
```
**O que faz:** cria VPC, subnets públicas/privadas, NAT Gateway, 3x RDS
PostgreSQL, ElastiCache Redis, DynamoDB, SQS, 5x ECR, o cluster EKS e o
node group (já com o `launch_template` que corrige o IMDS hop limit
automaticamente). **Demora ~20-25 min.** RDS e EKS são os mais lentos.
Não interrompa o comando no meio.

---

### Passo 4 — Configura o kubectl
**Onde rodar:** raiz do projeto (ou qualquer lugar)
```bash
aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster
kubectl get nodes
```
**O que faz:** aponta sua ferramenta `kubectl` para o cluster recém-criado.
Confirma que os 2 nodes aparecem como `Ready`.

---

### Passo 5 — Build e push das imagens Docker
**Onde rodar:** raiz do projeto
```bash
bash build-and-push.sh
```
**O que faz:** builda as 5 imagens (auth, flag, targeting, evaluation,
analytics) e publica cada uma no seu repositório ECR correspondente. Lê o
account ID automaticamente do `infra/account_id.txt` (gerado no Passo 2).
Pode rodar em paralelo com o Passo 3 (enquanto o Terraform sobe a infra),
numa segunda aba do terminal.

---

### Passo 6 — Instala Metrics Server + Nginx Ingress
**Onde rodar:** raiz do projeto (ou qualquer lugar, não depende de pasta)
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

kubectl get svc -n ingress-nginx -w
# espera o EXTERNAL-IP aparecer (hostname, não <pending>), Ctrl+C
```
**O que faz:** o Metrics Server coleta CPU/memória dos pods (pré-requisito
do HPA). O Nginx Ingress cria um Load Balancer público na AWS que vai
rotear as chamadas externas para os serviços certos.

⚠️ Se der `cannot reuse a name that is still in use` (release anterior
travado em estado `failed`):
```bash
helm uninstall ingress-nginx -n ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```

---

### Passo 7 — Gera os secrets do Kubernetes
**Onde rodar:** raiz do projeto
```bash
bash generate-secrets.sh
```
**O que faz:** lê os endpoints do RDS/Redis/SQS direto do `terraform output`
e monta o `k8s/secrets.yaml` automaticamente, em base64, com os nomes de
banco corretos (`auth_db`, `flag_db`, `targeting_db` — não `authdb`). Não
edite esse arquivo manualmente; se precisar mudar algo, mude o script.

---

### Passo 8 — Aplica os manifestos Kubernetes
**Onde rodar:** raiz do projeto
```bash
bash deploy-k8s.sh
```
**O que faz:** aplica, na ordem certa, namespace → secrets → configmap →
deployments+services dos 5 serviços → ingress → HPA. No final, mostra
`kubectl get pods` — confirme que os 6 pods (5 serviços, evaluation com
2 réplicas) ficam `1/1 Running`.

---

### Passo 9 — Roda as migrations SQL
**Onde rodar:** raiz do projeto (precisa achar `auth-service/db/init.sql` etc.)
```bash
bash run-migrations.sh
```
**O que faz:** o Terraform cria os bancos PostgreSQL **vazios** — as tabelas
(`api_keys`, `flags`, `targeting_rules`) são responsabilidade da aplicação,
não da infraestrutura. Este script sobe um pod temporário no cluster,
aplica os 3 `init.sql` que já existem no seu repo (um por serviço) contra
os bancos certos, e se autodestrói. Sem isso, os 3 serviços vão dar erro
`relation "X" does not exist` na primeira chamada.

Depois, reinicia os 3 serviços que dependem do banco para garantir que
não ficaram com conexões antigas em cache:
```bash
kubectl rollout restart deployment/auth-service -n togglemaster
kubectl rollout restart deployment/flag-service -n togglemaster
kubectl rollout restart deployment/targeting-service -n togglemaster
```

---

### Passo 10 — Gera a API key real
**Onde rodar:** raiz do projeto
```bash
LB=$(kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
bash update-api-key.sh "http://$LB"
```
**O que faz:** a `MASTER_KEY` (`master123`) só serve para criar chaves novas,
não para autenticar chamadas normais entre serviços. Este script chama
`POST /auth/admin/keys`, extrai a chave gerada, salva em `api_key.txt`, e
já atualiza sozinho o secret do `evaluation-service` com ela, reiniciando
o pod. Sem isso, toda chamada a `/evaluate` retorna 401 do flag-service.

---

### Passo 11 — Testa o fluxo completo
**Onde rodar:** raiz do projeto
```bash
bash test-fluxo-completo.sh "http://$LB"
```
**O que faz:** roda os 5 health checks, cria uma flag, cria uma regra de
targeting, e avalia a flag — tudo em sequência. Se o resultado final vier
um JSON limpo, a cadeia auth→flag→targeting→evaluate está 100% funcional.

---

## Depois de tudo funcionando: testes de carga e gravação

### Testa escalabilidade do evaluation-service
**Onde rodar:** raiz do projeto, 3 abas de terminal
```bash
# Aba 1
API_KEY=$(cat api_key.txt)
./hey.exe -z 3m -c 150 -H "Authorization: Bearer $API_KEY" \
  "http://$LB/evaluate/evaluate?flag_name=nova_ui&user_id=user_42&country=BR"

# Aba 2
kubectl get hpa -n togglemaster -w

# Aba 3
kubectl get pods -n togglemaster -w
```

### Testa escalabilidade do analytics-service (via SQS)
**Onde rodar:** raiz do projeto
```bash
SQS_URL=$(cd infra && terraform output -raw sqs_url)
for i in $(seq 1 100); do
  aws sqs send-message --queue-url $SQS_URL \
    --message-body "{\"user_id\":\"u$i\",\"flag_name\":\"nova_ui\",\"result\":true}" \
    --region us-east-1
done
kubectl get hpa -n togglemaster -w
```

### Confirma dados no DynamoDB
Via Console AWS (o CLI é bloqueado pelo Academy para leitura de dados):
Console → DynamoDB → Tables → `ToggleMasterAnalytics` → Explore table items → Run.

---

## Troubleshooting rápido (problemas já vistos e resolvidos)

| Sintoma | Causa | Solução |
|---|---|---|
| `helm: command not found` | Helm não instalado ou terminal não recarregou PATH | `bash 01-install-helm.sh`, depois feche e reabra o terminal |
| `bash: script.sh: No such file or directory` | Rodando script da pasta errada | Confira `pwd`; a maioria dos scripts roda da raiz, só `00-check-account.sh` roda de `infra/` |
| `namespaces "togglemaster" not found` | Rodou `run-migrations.sh` antes do `deploy-k8s.sh` | Rode `deploy-k8s.sh` primeiro, sempre |
| `Cross-account pass role is not allowed` | Account ID mudou (sessão Academy nova) | `cd infra && bash 00-check-account.sh` |
| `relation "api_keys" does not exist` | Tabelas não criadas no RDS | `bash run-migrations.sh` |
| `flag-service retornou status 401` | `SERVICE_API_KEY` é a master key, não uma key real | `bash update-api-key.sh "http://$LB"` |
| `NoCredentialProviders: no valid providers in chain` | IMDS hop limit = 1 (bloqueia pods) | Já corrigido no `eks.tf` via launch_template. Se persistir: `bash fix-imds-hop-limit.sh` |
| `cannot reuse a name that is still in use` (helm) | Release anterior travado em `failed` | `helm uninstall ingress-nginx -n ingress-nginx` antes de reinstalar |
| `terraform destroy` trava em Internet Gateway/subnet | Load Balancer do Helm não é gerenciado pelo Terraform | Delete o LB manualmente no Console/CLI antes do destroy |
| Tabela DynamoDB errada nos logs do analytics (`analytics-events` em vez de `ToggleMasterAnalytics`) | ConfigMap com nome errado | `kubectl patch configmap togglemaster-config -n togglemaster --type merge -p '{"data":{"AWS_DYNAMODB_TABLE":"ToggleMasterAnalytics"}}'` e reinicie o deployment |

---

## Valores fixos (não mudam entre recriações)

```
Região:          us-east-1
DB names:        auth_db, flag_db, targeting_db
DB user/senha:   postgres / SenhaMichuruca123
MASTER_KEY:      master123
DynamoDB table:  ToggleMasterAnalytics (chave: event_id)
SQS queue name:  togglemaster-events
EKS version:     1.31
Cluster name:    togglemaster-cluster
Node group:      togglemaster-nodes
```

## Valores que MUDAM a cada recriação (sempre regerar, nunca hardcode)

```
Account ID           -> 00-check-account.sh
RDS endpoints         -> generate-secrets.sh
Load Balancer URL     -> kubectl get ingress
API Key               -> update-api-key.sh
```
