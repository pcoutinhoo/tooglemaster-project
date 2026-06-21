#!/bin/bash
# 01-install-helm.sh
# Verifica se o Helm está disponível. Se não estiver, instala via winget
# e avisa para reabrir o terminal (PATH só atualiza em sessão nova).

if command -v helm &> /dev/null; then
  echo ">>> Helm já está instalado:"
  helm version
  exit 0
fi

echo ">>> Helm não encontrado. Instalando via winget..."
echo ">>> (Isso roda no Windows via winget — se der erro, rode manualmente: winget install Helm.Helm)"

powershell.exe -Command "winget install Helm.Helm --accept-package-agreements --accept-source-agreements"

echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!!! IMPORTANTE: feche esta janela do Git Bash COMPLETAMENTE       !!!"
echo "!!! (não só a aba) e abra uma nova para o PATH ser atualizado.    !!!"
echo "!!! Depois rode: helm version                                     !!!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"