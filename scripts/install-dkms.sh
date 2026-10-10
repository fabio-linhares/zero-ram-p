#!/usr/bin/env bash
# scripts/install-dkms.sh
# Instala o módulo experimental Zero RAM no DKMS para persistência automática
# Garante que o módulo seja recompilado automaticamente a cada atualização de kernel do Ubuntu/Debian

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DKMS_VERSION="2.0"
DKMS_NAME="zero-ram"
TARGET_DIR="/usr/src/${DKMS_NAME}-${DKMS_VERSION}"

echo "========================================================================"
echo "    PROJETO ZERO RAM - INSTALAÇÃO DO MÓDULO NO DKMS"
echo "========================================================================"

if ! command -v dkms >/dev/null 2>&1; then
    echo "Instalando o pacote dkms..."
    sudo apt-get update -qq && sudo apt-get install -y -qq dkms
fi

# 1. Remover versão anterior do DKMS se existir
if dkms status | grep -q "${DKMS_NAME}/${DKMS_VERSION}"; then
    echo "Removendo versão anterior registrada no DKMS..."
    sudo dkms remove -m "${DKMS_NAME}" -v "${DKMS_VERSION}" --all || true
fi

# 2. Copiar código-fonte para /usr/src
echo "Copiando fontes para $TARGET_DIR..."
sudo rm -rf "$TARGET_DIR"
sudo mkdir -p "$TARGET_DIR"
sudo cp -r "$REPO_ROOT/src/module/"* "$TARGET_DIR/"
sudo cp "$REPO_ROOT/packaging/dkms/dkms.conf.template" "$TARGET_DIR/dkms.conf"

# 3. Registrar, compilar e instalar no kernel ativo
echo "Registrando no DKMS..."
sudo dkms add -m "${DKMS_NAME}" -v "${DKMS_VERSION}"

echo "Compilando para o kernel atual ($(uname -r))..."
sudo dkms build -m "${DKMS_NAME}" -v "${DKMS_VERSION}"

echo "Instalando módulo no sistema..."
sudo dkms install -m "${DKMS_NAME}" -v "${DKMS_VERSION}"

echo ""
echo "========================================================================"
echo " [SUCESSO] Zero RAM registrado no DKMS!"
echo "========================================================================"
echo "A partir de agora, SEMPRE que o Ubuntu atualizar o kernel via apt upgrade,"
echo "o módulo será recompilado automaticamente em segundo plano."
dkms status | grep "${DKMS_NAME}" || true
