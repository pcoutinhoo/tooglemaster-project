FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY . .

RUN go mod tidy

RUN go build -o evaluation-service .

FROM alpine:latest

WORKDIR /root/

COPY --from=builder /app/evaluation-service .

EXPOSE 8004

CMD ["./evaluation-service"]