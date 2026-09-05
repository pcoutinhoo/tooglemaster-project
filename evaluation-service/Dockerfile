FROM golang:1.25.14-alpine3.24 AS builder
WORKDIR /app
COPY go.mod ./
COPY *.go ./
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

FROM alpine:3.24.1
WORKDIR /app
COPY --from=builder /app/main .
EXPOSE 8004
CMD ["./main"]