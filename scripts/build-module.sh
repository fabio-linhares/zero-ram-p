#!/usr/bin/env bash
# scripts/build-module.sh
# Compilador autônomo do módulo de kernel zram.ko modificado (Série v2 com Rework de zcomp)
# Compatível com Ubuntu, Debian, Arch Linux, Fedora (requer linux-headers e build-essential)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULE_DIR="$REPO_ROOT/src/module"

echo "========================================================================"
echo "    PROJETO ZERO RAM - COMPILAÇÃO DO MÓDULO EXPERIMENTAL (v2)"
echo "========================================================================"
echo "Kernel de Destino: $(uname -r)"
echo "Compilador:        $(gcc --version | head -n 1)"
echo "Diretório-fonte:   $MODULE_DIR"
echo ""

if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
    echo "ERRO: Headers do kernel não encontrados em /lib/modules/$(uname -r)/build" >&2
    echo "Instale os headers antes de compilar (ex: sudo apt install linux-headers-$(uname -r))" >&2
    exit 1
fi

cd "$MODULE_DIR"
echo "Limpando artefatos anteriores..."
make clean > /dev/null 2>&1 || true

echo "Compilando módulo zram.ko com Rework de zcomp v2..."
make

if [ -f "$MODULE_DIR/zram.ko" ]; then
    echo ""
    echo "========================================================================"
    echo " [SUCESSO] Módulo zram.ko compilado com sucesso!"
    echo "========================================================================"
    modinfo "$MODULE_DIR/zram.ko" | grep -E 'filename|description|vermagic|depends'
    echo ""
    echo "Para testar ou carregar o módulo manualmente:"
    echo "  sudo rmmod zram 2>/dev/null || true"
    echo "  sudo insmod $MODULE_DIR/zram.ko num_devices=1"
else
    echo "ERRO: Falha na geração do arquivo zram.ko." >&2
    exit 2
fi
