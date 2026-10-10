#!/usr/bin/env bash
# scripts/run-benchmarks.sh
# Orquestrador de benchmarks para o Projeto Zero RAM
# Executa testes controlados do fio com telemetria ativa

set -euo pipefail

PROFILE="${1:-priority-inversion}"
TARGET_DEV="${2:-/dev/zram1}"
RUN_NAME="${3:-run_$(date +%Y%m%d_%H%M%S)}"

FIO_FILE="benchmarks/fio/${PROFILE}.fio"
RESULTS_DIR="results/${RUN_NAME}"
mkdir -p "$RESULTS_DIR"

echo "========================================================================"
echo "PROJETO ZERO RAM - EXECUÇÃO DE BENCHMARK"
echo "Perfil: $PROFILE"
echo "Dispositivo Alvo: $TARGET_DEV"
echo "Diretório de Resultados: $RESULTS_DIR"
echo "========================================================================"

# Verificação de segurança: não rodar sobre zram0 se estiver ativo como swap do sistema!
if swapon --show | grep -q "$TARGET_DEV"; then
    echo "ERRO DE SEGURANÇA: $TARGET_DEV está ativo como SWAP do sistema hospedeiro!" >&2
    echo "Não execute testes de bloco destrutivos sobre dispositivo swap em uso." >&2
    exit 1
fi

if [ ! -b "$TARGET_DEV" ]; then
    echo "AVISO: Dispositivo de bloco $TARGET_DEV não encontrado."
    echo "Para testes em VM ou host com módulo zram carregado, inicialize com:"
    echo "  sudo zramctl --find --size 1G -a zstd"
    echo "Executando em modo de simulação/validação de sintaxe do FIO..."
    if command -v fio >/dev/null 2>&1; then
        fio --parse-only "$FIO_FILE"
        echo "Perfil FIO $FIO_FILE validado com sucesso!"
    else
        echo "FIO não instalado no host atual. Validação estática concluída."
    fi
    exit 0
fi

# Se o dispositivo existe e é seguro:
DEV_BASENAME=$(basename "$TARGET_DEV")
TELEMETRY_CSV="$RESULTS_DIR/telemetry.csv"

echo "Iniciando coletor de telemetria em segundo plano..."
scripts/collect-metrics.sh "$DEV_BASENAME" 1 "$TELEMETRY_CSV" &
TELEMETRY_PID=$!

echo "Disparando workload FIO..."
fio "$FIO_FILE" --filename="$TARGET_DEV" --output-format=json --output="$RESULTS_DIR/fio-output.json"

echo "Finalizando coletor de telemetria (PID: $TELEMETRY_PID)..."
kill -SIGTERM "$TELEMETRY_PID" 2>/dev/null || true
wait "$TELEMETRY_PID" 2>/dev/null || true

echo "========================================================================"
echo "Benchmark concluído! Resultados gravados em: $RESULTS_DIR"
echo "========================================================================"
