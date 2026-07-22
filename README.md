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
---

# ToggleMaster Execução (Tech Challenge Fase 2)

## Estrutura do projeto

```
tooglemaster-project/
├── auth-service/
├── flag-service/
├── targeting-service/
├── evaluation-service/
├── analytics-service/
├── infra/
├── k8s/
├── tools/
│   ├── install-hey.sh
│   └── hey-wrapper.sh
├── run-all.sh
├── build-and-push.sh
├── generate-secrets.sh
├── run-migrations.sh
├── deploy-k8s.sh
├── update-api-key.sh
├── test-fluxo-completo.sh
```

---

# 1. Pré-requisitos

* AWS CLI configurado
* kubectl instalado
* Terraform instalado
* Helm instalado
* Go instalado

---

# 2. Instalação do hey

```bash
bash tools/install-hey.sh
```

---

# 3. Execução do load test (OBRIGATÓRIO)

```bash
bash tools/hey-wrapper.sh -z 3m -c 150 \
-H "Authorization: Bearer $(cat api_key.txt)" \
"http://$LB/evaluate/evaluate?flag_name=nova_ui&user_id=user_42&country=BR"
```

---

# 4. Execução completa do sistema

## 4.1 Rodar tudo automático

```bash
cd tooglemaster-project
bash run-all.sh
```

---

## 4.2 Execução manual

### 4.2.1 Helm

```bash
bash 01-install-helm.sh
helm version
```

---

### 4.2.2 Infraestrutura AWS

```bash
cd infra
bash 00-check-account.sh
terraform init
terraform apply -auto-approve
cd ..
```

---

### 4.2.3 kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster
kubectl get nodes
```

---

### 4.2.4 Build e push

```bash
bash build-and-push.sh
```

---

### 4.2.5 Metrics + Ingress

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
--namespace ingress-nginx --create-namespace
```

---

### 4.2.6 Secrets

```bash
bash generate-secrets.sh
```

---

### 4.2.7 Deploy Kubernetes

```bash
bash deploy-k8s.sh
```

---

### 4.2.8 Migrations

```bash
bash run-migrations.sh
```

---

### 4.2.9 API Key

```bash
LB=$(kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

bash update-api-key.sh "http://$LB"
```

---

### 4.2.10 Teste do fluxo

```bash
bash test-fluxo-completo.sh "http://$LB"
```

---

# 5. Monitoramento

```bash
kubectl get pods -n togglemaster -w
kubectl get hpa -n togglemaster -w
```

---

# 6. Teste de carga

```bash
API_KEY=$(cat api_key.txt)

LB=$(kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

bash tools/hey-wrapper.sh -z 3m -c 150 \
-H "Authorization: Bearer $API_KEY" \
"http://$LB/evaluate/evaluate?flag_name=nova_ui&user_id=user_42&country=BR"
```

---

# 7. Teste SQS

```bash
SQS_URL=$(cd infra && terraform output -raw sqs_url)

for i in $(seq 1 100); do
aws sqs send-message \
--queue-url $SQS_URL \
--message-body "{\"user_id\":\"u$i\",\"flag_name\":\"nova_ui\",\"result\":true}" \
--region us-east-1
done
```

---

# 8. Troubleshooting

| Problema            | Solução                          |
| ------------------- | -------------------------------- |
| helm não encontrado | reinstalar helm                  |
| cluster não aparece | rodar terraform apply            |
| API key inválida    | rodar update-api-key.sh          |
| pods não sobem      | kubectl get pods -n togglemaster |
| hey não funciona    | bash tools/install-hey.sh        |

---

# 9. Regras do projeto

* scripts executados da raiz
* infra executado dentro de infra/
* load test sempre via tools/hey-wrapper.sh
* nunca usar binário direto do hey

---