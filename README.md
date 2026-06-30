# ToggleMaster — Tech Challenge Fase 2

Plataforma de feature flags distribuída, evoluída do MVP monolítico da Fase 1 para um ecossistema de 5 microsserviços independentes orquestrados no Kubernetes (AWS EKS).

**Branch de execução:** `develop`

---

## Sumário

1. [Arquitetura](#arquitetura)
2. [Serviços](#serviços)
3. [Infraestrutura AWS](#infraestrutura-aws)
4. [Pré-requisitos](#pré-requisitos)
5. [Execução Local (Docker Compose)](#execução-local-docker-compose)
6. [Deploy em Produção (AWS EKS)](#deploy-em-produção-aws-eks)
7. [Teste de Carga](#teste-de-carga)
8. [Escalabilidade e Monitoramento](#escalabilidade-e-monitoramento)
9. [Troubleshooting](#troubleshooting)

---

## Arquitetura

```
                        ┌─────────────────────────────────────────────────┐
                        │                    AWS EKS                       │
                        │                                                  │
Internet ──► NLB ──► Nginx Ingress                                         │
                        │       │                                          │
                        │  /auth ──────► auth-service (Go)      ──► RDS PostgreSQL
                        │  /flags ─────► flag-service (Python)  ──► RDS PostgreSQL
                        │  /targeting ─► targeting-service (Py) ──► RDS PostgreSQL
                        │  /evaluate ──► evaluation-service (Go) ─► ElastiCache Redis
                        │                      │                           │
                        │                      └──► SQS ──► analytics-service (Py) ──► DynamoDB
                        │                                                  │
                        └─────────────────────────────────────────────────┘
```

**Fluxo de avaliação (hot path):**
1. Cliente chama `/evaluate?user_id=X&flag_name=Y`
2. evaluation-service verifica Redis (cache)
3. Cache miss → busca flag no flag-service + regra no targeting-service
4. Aplica lógica determinística (hash do user_id para % de usuários)
5. Retorna `true`/`false` e envia evento assíncrono ao SQS
6. analytics-service consome o SQS e persiste no DynamoDB

---

## Serviços

| Serviço | Linguagem | Porta | Banco | Responsabilidade |
|---|---|---|---|---|
| auth-service | Go 1.21 | 8001 | PostgreSQL | Criação e validação de chaves de API |
| flag-service | Python 3.9 | 8002 | PostgreSQL | CRUD das definições de feature flags |
| targeting-service | Python 3.9 | 8003 | PostgreSQL | Regras de segmentação (% de usuários, listas) |
| evaluation-service | Go 1.21 | 8004 | Redis | Hot path com cache — retorna true/false |
| analytics-service | Python 3.9 | 8005 | DynamoDB | Worker SQS → persiste eventos de avaliação |

Cada serviço tem seu próprio README com detalhes de endpoints e variáveis de ambiente:
- [auth-service/README.md](auth-service/README.md)
- [flag-service/README.md](flag-service/README.md)
- [targeting-service/README.md](targeting-service/README.md)
- [evaluation-service/README.md](evaluation-service/README.md)
- [analytics-service/README.md](analytics-service/README.md)

---

## Infraestrutura AWS

**Toda a infraestrutura é provisionada via Terraform** — não é necessário criar nada manualmente no console da AWS.

| Recurso | Serviço AWS | Para quê |
|---|---|---|
| Cluster EKS (v1.31) + Node Group | Amazon EKS | Orquestração dos pods (min 1, desired 2, max 4 nós) |
| 5 repositórios ECR | Amazon ECR | Imagens Docker de cada microsserviço |
| 3 instâncias RDS PostgreSQL 15 | Amazon RDS | auth_db, flag_db, targeting_db |
| 1 cluster Redis | Amazon ElastiCache | Cache do evaluation-service |
| 1 fila Standard | Amazon SQS | Eventos de avaliação (evaluation → analytics) |
| 1 tabela DynamoDB | Amazon DynamoDB | Persistência dos eventos (ToggleMasterAnalytics) |
| VPC + subnets + NAT Gateway | Amazon VPC | Rede isolada para todos os recursos |

> **Nota AWS Academy:** O Terraform está configurado para usar a `LabRole` existente. Não é possível criar novas roles IAM no Academy — todos os recursos herdam as permissões da LabRole.

---

## Pré-requisitos

- [Docker](https://docs.docker.com/get-docker/) e Docker Compose (execução local)
- [AWS CLI](https://aws.amazon.com/cli/) configurado (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Go](https://go.dev/doc/install) >= 1.21 (apenas para dev local sem Docker)

---

## Execução Local (Docker Compose)

Sobe todos os 10 contêineres (5 apps + 3 PostgreSQL + Redis + LocalStack emulando SQS/DynamoDB) com um único comando:

```bash
git checkout develop
docker compose up --build
```

Aguarde todos os serviços ficarem `healthy`. Para verificar:

```bash
docker compose ps
```

### Endpoints locais

| Serviço | URL |
|---|---|
| auth-service | http://localhost:8001/health |
| flag-service | http://localhost:8002/health |
| targeting-service | http://localhost:8003/health |
| evaluation-service | http://localhost:8004/health |
| analytics-service | http://localhost:8005/health |

### Fluxo de teste local

```bash
# 1. Criar uma chave de API
curl -X POST http://localhost:8001/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer master123" \
  -d '{"name": "meu-token"}'

# Guarde a chave retornada (tm_key_...)
API_KEY="tm_key_..."

# 2. Criar uma feature flag
curl -X POST http://localhost:8002/flags \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"name": "nova_ui", "description": "Nova interface", "is_enabled": true}'

# 3. Criar regra de segmentação (50% dos usuários)
curl -X POST http://localhost:8003/rules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_KEY" \
  -d '{"flag_name": "nova_ui", "is_enabled": true, "rules": {"type": "PERCENTAGE", "value": 50}}'

# 4. Avaliar a flag para um usuário
curl "http://localhost:8004/evaluate?user_id=user_42&flag_name=nova_ui"
# Retorna: {"flag_name":"nova_ui","user_id":"user_42","result":true}
```

Para derrubar o ambiente:

```bash
docker compose down -v
```

---

## Deploy em Produção (AWS EKS)

### Execução automática (recomendado)

```bash
git checkout develop
bash run-all.sh
```

O script executa todas as etapas abaixo em sequência, com verificações em cada passo.

---

### Execução manual (passo a passo)

#### 1. Instalar Helm

```bash
bash 01-install-helm.sh
helm version
```

#### 2. Provisionar infraestrutura AWS via Terraform

```bash
cd infra
terraform init
terraform apply -auto-approve
cd ..
```

> Isso cria o cluster EKS, node group, 3 instâncias RDS, Redis, SQS, DynamoDB e os repositórios ECR. Pode levar ~15-20 minutos.

#### 3. Configurar kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster
kubectl get nodes
```

#### 4. Build e push das imagens para o ECR

```bash
bash build-and-push.sh
```

#### 5. Instalar Metrics Server e Nginx Ingress

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

#### 6. Gerar e aplicar secrets do Kubernetes

Os secrets são gerados automaticamente a partir dos outputs do Terraform:

```bash
bash generate-secrets.sh
```

#### 7. Deploy dos manifests Kubernetes

```bash
bash deploy-k8s.sh
```

Aplica em ordem: namespace → secrets → configmap → deployments → services → ingress → HPA.

#### 8. Executar migrations dos bancos

```bash
bash run-migrations.sh
```

Conecta nos 3 RDS PostgreSQL e executa os scripts `db/init.sql` de cada serviço.

#### 9. Criar e configurar API key de produção

```bash
LB=$(kubectl get ingress togglemaster-ingress -n togglemaster \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

bash update-api-key.sh "http://$LB"
```

A chave é salva em `api_key.txt` e o K8s secret do evaluation-service é atualizado automaticamente.

#### 10. Validar o deploy

```bash
bash test-fluxo-completo.sh "http://$LB"
```

Testa health checks de todos os serviços, cria flag, cria regra de segmentação e valida avaliação end-to-end.

---

## Teste de Carga

Instalar a ferramenta `hey`:

```bash
bash tools/install-hey.sh
```

Executar carga por 3 minutos com 150 conexões concorrentes:

```bash
API_KEY=$(cat api_key.txt)
LB=$(kubectl get ingress togglemaster-ingress -n togglemaster \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

bash tools/hey-wrapper.sh -z 3m -c 150 \
  -H "Authorization: Bearer $API_KEY" \
  "http://$LB/evaluate/evaluate?flag_name=nova_ui&user_id=user_42&country=BR"
```

> Sempre use `tools/hey-wrapper.sh` — nunca o binário `hey` diretamente. O wrapper resolve o path do binário automaticamente em qualquer OS.

### Teste manual da fila SQS

```bash
SQS_URL=$(cd infra && terraform output -raw sqs_url)

for i in $(seq 1 100); do
  aws sqs send-message \
    --queue-url "$SQS_URL" \
    --message-body "{\"user_id\":\"u$i\",\"flag_name\":\"nova_ui\",\"result\":true}" \
    --region us-east-1
done
```

---

## Escalabilidade e Monitoramento

O projeto usa **Horizontal Pod Autoscaler (HPA)** para escalar automaticamente:

| Serviço | Métrica | Mín | Máx | Target |
|---|---|---|---|---|
| evaluation-service | CPU | 2 | 8 | 30% |
| analytics-service | CPU | 1 | 6 | 70% |

Monitorar em tempo real:

```bash
# Pods rodando
kubectl get pods -n togglemaster -w

# Status do HPA (atualiza durante o load test)
kubectl get hpa -n togglemaster -w

# Logs de um serviço
kubectl logs -n togglemaster -l app=evaluation-service -f
```

### Por que 3 data stores diferentes?

| Data store | Serviço AWS | Uso no projeto |
|---|---|---|
| **PostgreSQL (RDS)** | Relacional | Dados estruturados com garantia ACID — definições de flags, regras e chaves de API |
| **Redis (ElastiCache)** | Cache in-memory | Cache de curta duração para o hot path — sub-milissegundo, sem persistência necessária |
| **DynamoDB** | NoSQL gerenciado | Eventos de analytics em alta escala — escrita rápida, sem schema rígido, custo por requisição |

---

## Destruindo a Infraestrutura

Para remover todos os recursos AWS provisionados:

```bash
bash destroy-all.sh
```

O script tenta desinstalar o Nginx Ingress via Helm (o que remove o Load Balancer automaticamente). Se o cluster já não responder ao `kubectl`, ele lista os Load Balancers pendentes e aguarda confirmação manual antes de executar o `terraform destroy` — evitando o erro `DependencyViolation` na subnet/Internet Gateway.

> Se o script pausar pedindo para deletar LBs manualmente, use:
> ```bash
> aws elb delete-load-balancer --load-balancer-name NOME --region us-east-1
> # ou para NLB/ALB:
> aws elbv2 delete-load-balancer --load-balancer-arn ARN --region us-east-1
> ```

---

## Troubleshooting

| Problema | Solução |
|---|---|
| Helm não encontrado | `bash 01-install-helm.sh` |
| Cluster não aparece no kubectl | `aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster` |
| Terraform falha ao criar recursos | Verificar se `lab_role_arn` em `infra/terraform.tfvars` está correto |
| API key inválida | `bash update-api-key.sh "http://$LB"` |
| Pods em CrashLoopBackOff | `kubectl describe pod <nome-do-pod> -n togglemaster` |
| Pods não sobem (ImagePullBackOff) | `bash build-and-push.sh` para garantir imagens no ECR |
| hey não funciona | `bash tools/install-hey.sh` |
| Analytics não consome SQS | Verificar se o IMDS hop limit está configurado: `bash fix-imds-hop-limit.sh` |
| Destruir tudo | `bash destroy-all.sh` (aguarda remoção do Load Balancer antes do terraform destroy) |

### Regras do projeto

- Scripts sempre executados da raiz do projeto
- Terraform sempre executado dentro de `infra/`
- Load test sempre via `tools/hey-wrapper.sh`
- Branch de trabalho: `develop`
