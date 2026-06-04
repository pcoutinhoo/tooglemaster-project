FROM golang:1.21-alpine AS builder

WORKDIR /app

# Instala git (necessário para go mod download)
RUN apk add --no-cache git

# Copia go.mod primeiro para cachear dependências
COPY go.mod ./

# Baixa as dependências (incluindo pgx)
RUN go mod download || true

# Copia todo o código
COPY . .

# Garante dependências atualizadas e compila
RUN go mod tidy && go build -o auth-service .

FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/auth-service .

EXPOSE 8001

CMD ["./auth-service"]