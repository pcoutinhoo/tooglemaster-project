#!/bin/bash
set -e

echo ">>> Instalando hey via Go..."

if ! command -v go >/dev/null 2>&1; then
  echo "ERRO: Go não está instalado"
  exit 1
fi

go install github.com/rakyll/hey@latest

echo ">>> hey instalado com sucesso"
echo "GOPATH: $(go env GOPATH)"