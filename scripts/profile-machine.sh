#!/usr/bin/env bash
# scripts/profile-machine.sh
# Perfilador Universal de Hardware e Memória para o Projeto Zero RAM
# Compatível com qualquer máquina Linux (Samsung, Dell, ThinkPad, servidores)
# Detecta distribuição, hardware, limites de memória e gera recomendações de tuning.

set -euo pipefail

echo "========================================================================"
echo "      PROJETO ZERO RAM - PERFILADOR DE HARDWARE E SISTEMA"
echo "========================================================================"
echo "Data: $(date -Iseconds)"
echo "Host: $(hostname)"
echo ""

# 1. Identificação do Equipamento e SO
echo "--- [1] Identificação do Equipamento e SO ---"
VENDOR="Desconhecido"
PRODUCT="Desconhecido"

if [ -r /sys/class/dmi/id/sys_vendor ]; then
    VENDOR=$(cat /sys/class/dmi/id/sys_vendor)
fi
if [ -r /sys/class/dmi/id/product_name ]; then
    PRODUCT=$(cat /sys/class/dmi/id/product_name)
fi
echo "Fabricante / Modelo: $VENDOR - $PRODUCT"

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "Distribuição: $PRETTY_NAME ($ID)"
else
    echo "Distribuição: Linux Genérico"
fi
echo "Kernel Ativo: $(uname -r) ($(uname -m))"

# 2. CPU e Topologia
echo ""
echo "--- [2] CPU e Recursos de Processamento ---"
CPUS=$(nproc)
CPU_MODEL=$(lscpu | grep "Nome do modelo\|Model name" | sed -e 's/.*:[[:space:]]*//' | head -n 1)
echo "Modelo de CPU: $CPU_MODEL"
echo "Núcleos / Threads lógicos: $CPUS"

# 3. Memória RAM e Swap
echo ""
echo "--- [3] Memória RAM e Estado do Swap ---"
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
TOTAL_RAM_GB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_RAM_MB / 1024}")
echo "RAM Física Total: ${TOTAL_RAM_MB} MiB (~${TOTAL_RAM_GB} GiB)"

SWAP_ACTIVE=0
if swapon --show | grep -q "partition\|file"; then
    SWAP_ACTIVE=1
    echo "Swap Convencional (disco/arquivo): ATIVO"
    swapon --show
else
    echo "Swap Convencional: NENHUM ou DESATIVADO"
fi

if swapon --show | grep -q "zram"; then
    echo "ZRAM: ATIVO"
    zramctl || true
else
    echo "ZRAM: NÃO ATIVO NO MOMENTO"
fi

# 4. Verificação de Zswap e MGLRU
echo ""
echo "--- [4] Recursos Avançados do Kernel ---"
if [ -r /sys/module/zswap/parameters/enabled ]; then
    ZSWAP_STATUS=$(cat /sys/module/zswap/parameters/enabled)
    echo "Zswap no Kernel: $ZSWAP_STATUS"
else
    echo "Zswap no Kernel: Não suportado ou módulo não carregado"
fi

if [ -r /sys/kernel/mm/lru_gen/enabled ]; then
    MGLRU_STATUS=$(cat /sys/kernel/mm/lru_gen/enabled)
    echo "MGLRU (Multi-Gen LRU): ATIVO ($MGLRU_STATUS)"
else
    echo "MGLRU: Não disponível neste kernel"
fi

# 5. Recomendação Automatizada de Dimensionamento para esta Máquina
echo ""
echo "========================================================================"
echo "      RECOMENDAÇÃO DE CONFIGURAÇÃO DO ZERO RAM PARA ESTE LAPTOP"
echo "========================================================================"

# Cálculo de tamanho de ZRAM recomendado:
# Regra de engenharia:
# - <= 8GB RAM: ZRAM = 100% da RAM (até 8192MB)
# - 16GB RAM: ZRAM = 50% a 75% da RAM (8192MB a 12288MB)
# - >= 32GB RAM: ZRAM = 50% da RAM (máx 16384MB)
if [ "$TOTAL_RAM_MB" -le 8500 ]; then
    REC_SIZE_MB=$TOTAL_RAM_MB
    REC_COMP="lz4"
    PERF_PROFILE="Economia de CPU e baixa latência (adequado para laptops leves)"
elif [ "$TOTAL_RAM_MB" -le 17000 ]; then
    REC_SIZE_MB=$((TOTAL_RAM_MB / 2))
    REC_COMP="zstd"
    PERF_PROFILE="Equilíbrio máximo: taxa de compressão alta (~2.5x) e rápida descompressão"
else
    REC_SIZE_MB=16384
    REC_COMP="zstd"
    PERF_PROFILE="Alta capacidade de memória com ZSTD multinúcleo"
fi

echo "Perfil de Hardware Identificado: $PERF_PROFILE"
echo "Tamanho ZRAM Recomendado: ${REC_SIZE_MB} MiB"
echo "Algoritmo Primário: $REC_COMP"
echo "Algoritmo Secundário (Recompressão com Singleton): zstd (nível 16)"
echo "Swappiness Recomendado: 150 (incentiva compressão de páginas frias antes de I/O em disco)"
echo "Page-Cluster Recomendado: 0 (leitura página a página de 4KB, sem prefetch de bloco lento)"
echo ""

# Gera arquivo com os parâmetros identificados
PROFILE_OUT="results/machine_profile_$(hostname).env"
mkdir -p results
cat << EOF > "$PROFILE_OUT"
# Perfil gerado automaticamente para $(hostname)
VENDOR="$VENDOR"
PRODUCT="$PRODUCT"
CPU_CORES=$CPUS
TOTAL_RAM_MB=$TOTAL_RAM_MB
RECOMMENDED_ZRAM_MB=$REC_SIZE_MB
RECOMMENDED_ALGO="$REC_COMP"
RECOMMENDED_SWAPPINESS=150
EOF

echo "Metadados de perfil gravados em: $PROFILE_OUT"
echo "Utilize estes valores no arquivo de configuração do ZRAM deste laptop."
