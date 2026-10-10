#!/usr/bin/env bash
# scripts/audit-readonly.sh
# Auditoria somente-leitura do sistema hospedeiro para o Projeto Zero RAM
# Não modifica nenhum arquivo ou configuração do sistema.

set -euo pipefail

OUTFILE="${1:-results/audit-inventory.txt}"
mkdir -p "$(dirname "$OUTFILE")"

exec > >(tee "$OUTFILE") 2>&1

echo "========================================================================"
echo "PROJETO ZERO RAM - AUDITORIA DE HARDWARE, MEMÓRIA E KERNEL (E0)"
echo "Data da execução: $(date -Iseconds)"
echo "Host: $(hostname)"
echo "========================================================================"

echo ""
echo "=== 1. SISTEMA OPERACIONAL E KERNEL ==="
uname -a
if [ -r /etc/os-release ]; then
    cat /etc/os-release
fi

echo ""
echo "=== 2. TOPOLOGIA DE CPU E MEMÓRIA ==="
lscpu | grep -E 'Architecture|Model name|CPU\(s\)|Thread|Core|Socket|NUMA|L1|L2|L3|Flags' | head -n 25 || true
echo ""
free -h

echo ""
echo "=== 3. ESTADO DE SWAP E ZRAM ==="
swapon --show || true
echo ""
if command -v zramctl >/dev/null 2>&1; then
    zramctl || true
else
    echo "zramctl não disponível no PATH"
fi

for d in /sys/block/zram*; do
    if [ -d "$d" ]; then
        echo "--> Dispositivo encontrado: $d"
        for f in comp_algorithm mm_stat io_stat bd_stat disksize; do
            if [ -r "$d/$f" ]; then
                echo "  $f: $(cat "$d/$f")"
            fi
        done
    fi
done

echo ""
echo "=== 4. ZSWAP E PRESSURE STALL INFORMATION (PSI) ==="
if [ -r /sys/module/zswap/parameters/enabled ]; then
    echo "zswap.enabled: $(cat /sys/module/zswap/parameters/enabled)"
else
    echo "zswap não carregado ou sem parâmetro em sysfs"
fi

for p in cpu memory io; do
    if [ -r "/proc/pressure/$p" ]; then
        echo "--> /proc/pressure/$p:"
        cat "/proc/pressure/$p"
    fi
done

echo ""
echo "=== 5. LINHA DE COMANDO DE BOOT E MONTAGENS ==="
cat /proc/cmdline
echo ""
findmnt /boot || echo "/boot não é ponto de montagem separado"
findmnt /efi || findmnt /boot/efi || echo "/efi não montado diretamente"

echo ""
echo "=== 6. PACOTES DE KERNEL INSTALADOS ==="
if command -v dpkg >/dev/null 2>&1; then
    dpkg -l | grep -E 'linux-image|linux-headers|zram' || true
elif command -v pacman >/dev/null 2>&1; then
    pacman -Q | grep -E '^(linux|linux-headers|zram)' || true
fi

echo ""
echo "=== 7. ESPAÇO DISPONÍVEL EM DISCO ==="
df -h / /boot /boot/efi 2>/dev/null || df -h /

echo ""
echo "=== 8. MGLRU (MULTI-GEN LRU) ==="
if [ -r /sys/kernel/mm/lru_gen/enabled ]; then
    echo "mglru.enabled: $(cat /sys/kernel/mm/lru_gen/enabled)"
else
    echo "MGLRU não exposto em /sys/kernel/mm/lru_gen"
fi

echo ""
echo "Auditoria concluída com sucesso. Resultado gravado em: $OUTFILE"
