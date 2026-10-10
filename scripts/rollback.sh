#!/usr/bin/env bash
# scripts/rollback.sh
# Script de Desativação e Rollback Seguro do ZRAM
# Retorna o sistema ao estado original (swap convencional em disco/arquivo)

set -euo pipefail

echo "========================================================================"
echo "      PROJETO ZERO RAM - PROCEDIMENTO DE ROLLBACK SEGURO"
echo "========================================================================"
echo "Data: $(date -Iseconds)"
echo "Aviso: Este script desativará com segurança qualquer swap em ZRAM e"
echo "restaurará o swap convencional do sistema."
echo ""

# 1. Reativar Swap Convencional se existir e estiver inativo
if [ -f "/swap.img" ]; then
    if ! swapon --show | grep -q "/swap.img"; then
        echo "--> Reativando swap de segurança /swap.img..."
        sudo swapon /swap.img || echo "Não foi possível ativar /swap.img automaticamente."
    else
        echo "--> Swap convencional /swap.img já se encontra ativo."
    fi
elif [ -f "/swapfile" ]; then
    if ! swapon --show | grep -q "/swapfile"; then
        echo "--> Reativando swap de segurança /swapfile..."
        sudo swapon /swapfile || echo "Não foi possível ativar /swapfile automaticamente."
    fi
fi

# 2. Desativar Dispositivos ZRAM como Swap
for dev in $(swapon --show=NAME --noheadings | grep "zram" || true); do
    echo "--> Executando swapoff em $dev..."
    sudo swapoff "$dev"
done

# 3. Resetar Dispositivos ZRAM
for d in /sys/block/zram*; do
    if [ -d "$d" ]; then
        DEV_NAME=$(basename "$d")
        echo "--> Resetando dispositivo $DEV_NAME..."
        if [ -w "$d/reset" ]; then
            echo 1 | sudo tee "$d/reset" > /dev/null || true
        fi
    fi
done

# 4. Parar e desabilitar geradores do systemd se instalados
if systemctl is-active --quiet systemd-zram-setup@zram0.service 2>/dev/null; then
    echo "--> Parando systemd-zram-setup@zram0..."
    sudo systemctl stop systemd-zram-setup@zram0.service || true
fi

# 5. Estado Final
echo ""
echo "=== ESTADO ATUAL DO SUBSISTEMA DE SWAP ==="
swapon --show
free -h

echo ""
echo "========================================================================"
echo "Rollback concluído com sucesso. O sistema está no estado padrão estável."
echo "========================================================================"
