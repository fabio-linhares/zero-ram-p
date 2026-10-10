#!/usr/bin/env bash
# scripts/collect-metrics.sh
# Coletor de telemetria contínua de memória, PSI e estatísticas do dispositivo ZRAM
# Gera CSV estruturado para análise comparativa posterior

set -euo pipefail

DEV_NAME="${1:-zram1}"
INTERVAL="${2:-1}"
OUT_CSV="${3:-results/telemetry_$(date +%Y%m%d_%H%M%S).csv}"

SYS_DEV="/sys/block/$DEV_NAME"
mkdir -p "$(dirname "$OUT_CSV")"

echo "timestamp,psi_mem_some_10,psi_mem_full_10,orig_data_size,compr_data_size,mem_used_total,same_pages,read_ios,write_ios" > "$OUT_CSV"

echo "[Telemetry] Iniciando amostragem em $SYS_DEV a cada ${INTERVAL}s. Saída: $OUT_CSV"

trap 'echo "[Telemetry] Finalizando coleta."; exit 0' SIGINT SIGTERM

while true; do
    TS=$(date +%s)
    
    # PSI memory
    if [ -r /proc/pressure/memory ]; then
        PSI_SOME=$(grep "some" /proc/pressure/memory | sed -n 's/.*avg10=\([0-9.]*\).*/\1/p')
        PSI_FULL=$(grep "full" /proc/pressure/memory | sed -n 's/.*avg10=\([0-9.]*\).*/\1/p')
    else
        PSI_SOME=0
        PSI_FULL=0
    fi

    # ZRAM mm_stat
    if [ -r "$SYS_DEV/mm_stat" ]; then
        read -r ORIG_DATA COMPR_DATA MEM_USED _ _ SAME_PAGES _ < "$SYS_DEV/mm_stat" || true
    else
        ORIG_DATA=0; COMPR_DATA=0; MEM_USED=0; SAME_PAGES=0
    fi

    # ZRAM io_stat
    if [ -r "$SYS_DEV/io_stat" ]; then
        read -r READ_IOS _ _ _ WRITE_IOS _ < "$SYS_DEV/io_stat" || true
    else
        READ_IOS=0; WRITE_IOS=0
    fi

    echo "$TS,$PSI_SOME,$PSI_FULL,$ORIG_DATA,$COMPR_DATA,$MEM_USED,$SAME_PAGES,$READ_IOS,$WRITE_IOS" >> "$OUT_CSV"
    sleep "$INTERVAL"
done
