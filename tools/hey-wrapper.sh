#!/bin/bash
set -e

# 1. tenta direto no PATH
if command -v hey >/dev/null 2>&1; then
  exec hey "$@"
fi

# 2. tenta GOBIN
if [ -n "$GOBIN" ] && [ -f "$GOBIN/hey" ]; then
  exec "$GOBIN/hey" "$@"
fi

# 3. tenta GOPATH padrão
GOPATH_BIN="$(go env GOPATH)/bin/hey"
if [ -f "$GOPATH_BIN" ]; then
  exec "$GOPATH_BIN" "$@"
fi

# 4. fallback inteligente: tenta instalar automaticamente
echo ">>> hey não encontrado. Instalando automaticamente..."
go install github.com/rakyll/hey@latest

GOPATH_BIN="$(go env GOPATH)/bin/hey"

if [ -f "$GOPATH_BIN" ]; then
  exec "$GOPATH_BIN" "$@"
fi

echo "ERRO: não foi possível localizar o hey"
exit 1