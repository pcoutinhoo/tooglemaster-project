#!/bin/bash
# 01-install-helm.sh
# Instala o Helm de forma compatível com Windows (Git Bash) e macOS.

if command -v helm &> /dev/null; then
  echo ">>> Helm já está instalado:"
  helm version
  exit 0
fi

OS="$(uname -s)"
echo ">>> Sistema operacional detectado: $OS"

case "$OS" in
  Darwin)
    # macOS — usa Homebrew
    if command -v brew &> /dev/null; then
      echo ">>> Instalando Helm via Homebrew..."
      brew install helm
    else
      echo ">>> Homebrew não encontrado. Instalando via script oficial..."
      curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    ;;
  Linux)
    echo ">>> Instalando Helm via script oficial..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows Git Bash
    echo ">>> Windows detectado. Instalando via winget..."
    powershell.exe -Command "winget install Helm.Helm --accept-package-agreements --accept-source-agreements"
    echo ""
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!! IMPORTANTE (Windows): feche e reabra o terminal completamente  !!!"
    echo "!!! para o PATH ser atualizado. Depois rode: helm version          !!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 0
    ;;
  *)
    echo "!!! Sistema operacional não reconhecido: $OS"
    echo "!!! Instale o Helm manualmente: https://helm.sh/docs/intro/install/"
    exit 1
    ;;
esac

echo ""
echo ">>> Helm instalado com sucesso:"
helm version