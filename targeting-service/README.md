# targeting-service (Python)

Este é o serviço de regras de segmentação (targeting) do projeto ToggleMaster. Ele gerencia regras complexas — como "50% dos usuários" ou "usuários do país X" — associadas a uma feature flag específica.

**IMPORTANTE:** Este serviço é protegido e depende que o `auth-service` esteja rodando (ex: em `http://localhost:8001`).

> Para rodar o ecossistema completo localmente, prefira o Docker Compose na raiz do projeto: `docker compose up --build`.

## Pré-requisitos (Local)

* [Python](https://www.python.org/) (versão 3.9 ou superior)
* [PostgreSQL](https://www.postgresql.org/download/)
* O `auth-service` deve estar rodando.

## Rodando Localmente

1. **Clone o repositório** e entre na pasta `targeting-service`.

2. **Prepare o Banco de Dados:**
    ```bash
    psql -U seu_usuario -d targeting_db -f db/init.sql
    ```

3. **Configure as Variáveis de Ambiente:**
    Crie um arquivo `.env` na raiz desta pasta com o seguinte conteúdo:
    ```env
    DATABASE_URL="postgres://SEU_USUARIO:SUA_SENHA@localhost:5432/targeting_db"
    PORT="8003"
    AUTH_SERVICE_URL="http://localhost:8001"
    ```

4. **Instale as Dependências:**
    ```bash
    pip install -r requirements.txt
    ```

5. **Inicie o Serviço:**
    ```bash
    gunicorn --bind 0.0.0.0:8003 app:app
    ```
    O servidor estará rodando em `http://localhost:8003`.

## Testando os Endpoints

Você precisa de uma chave de API válida gerada pelo `auth-service`. Consulte o [auth-service/README.md](../auth-service/README.md) para criá-la.

**1. Health Check:**
```bash
curl http://localhost:8003/health
```
Saída esperada: `{"status":"ok"}`

**2. Criar uma Regra de Segmentação (50% dos usuários):**
```bash
curl -X POST http://localhost:8003/rules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SUA_CHAVE_API" \
  -d '{
    "flag_name": "enable-new-dashboard",
    "is_enabled": true,
    "rules": {"type": "PERCENTAGE", "value": 50}
  }'
```

**3. Buscar a Regra de uma Flag:**
```bash
curl http://localhost:8003/rules/enable-new-dashboard \
  -H "Authorization: Bearer SUA_CHAVE_API"
```

**4. Atualizar a Regra (mudar para 75%):**
```bash
curl -X PUT http://localhost:8003/rules/enable-new-dashboard \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer SUA_CHAVE_API" \
  -d '{"rules": {"type": "PERCENTAGE", "value": 75}}'
```

**5. Deletar a Regra:**
```bash
curl -X DELETE http://localhost:8003/rules/enable-new-dashboard \
  -H "Authorization: Bearer SUA_CHAVE_API"
```

## Formatos de Regra Suportados

```json
// Porcentagem de usuários
{"type": "PERCENTAGE", "value": 50}

// Lista específica de usuários
{"type": "USER_LIST", "values": ["user_1", "user_2", "user_3"]}
```
