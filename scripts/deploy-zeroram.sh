#!/usr/bin/env bash
# scripts/deploy-zeroram.sh
# Instalador e Orquestrador de Implantação Automatizada do Zero RAM
# Suporta Ubuntu, Debian, Fedora, Arch Linux (Laptops Samsung, Dell, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================================================"
echo "      PROJETO ZERO RAM - INSTALAÇÃO E ATIVAÇÃO AUTOMATIZADA"
echo "========================================================================"
echo "Iniciando processo de implantação em: $(hostname)"
echo ""

# 1. Perfilamento da Máquina
echo "--> Passo 1: Executando perfilamento de hardware..."
"$REPO_ROOT/scripts/profile-machine.sh"

PROFILE_FILE="$REPO_ROOT/results/machine_profile_$(hostname).env"
if [ ! -f "$PROFILE_FILE" ]; then
    echo "ERRO: Arquivo de perfil não encontrado em $PROFILE_FILE" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$PROFILE_FILE"

echo ""
echo "Configurações selecionadas para esta máquina:"
echo "  Tamanho ZRAM: ${RECOMMENDED_ZRAM_MB} MiB"
echo "  Compressor:   ${RECOMMENDED_ALGO}"
echo "  Swappiness:   ${RECOMMENDED_SWAPPINESS}"

# 2. Verificação de Pacotes Necessários
echo ""
echo "--> Passo 2: Verificando ferramentas do sistema..."
NEED_INSTALL=()

if ! command -v zramctl >/dev/null 2>&1; then
    NEED_INSTALL+=("util-linux")
fi

if [ ${#NEED_INSTALL[@]} -gt 0 ]; then
    echo "Instalando utilitários necessários: ${NEED_INSTALL[*]}..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq "${NEED_INSTALL[@]}"
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm "${NEED_INSTALL[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y "${NEED_INSTALL[@]}"
    fi
fi

# 3. Configuração de Sysctl de Alta Performance para Memória Comprimida
echo ""
echo "--> Passo 3: Aplicando parâmetros de memória virtual (sysctl)..."
SYSCTL_CONF="/etc/sysctl.d/99-zeroram.conf"

cat << EOF | sudo tee "$SYSCTL_CONF" > /dev/null
# Otimizações de Kernel para Memória Comprimida ZRAM - Projeto Zero RAM
# Incentiva compressão de páginas antes de esgotamento e desativa latência de I/O de disco
vm.swappiness = ${RECOMMENDED_SWAPPINESS}
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF

sudo sysctl -p "$SYSCTL_CONF" > /dev/null || true
echo "Parâmetros aplicados em $SYSCTL_CONF:"
cat "$SYSCTL_CONF"

# 4. Ativação do Dispositivo ZRAM
echo ""
echo "--> Passo 4: Inicializando dispositivo /dev/zram0..."

# Garante que o módulo do kernel está carregado
sudo modprobe zram num_devices=1

# Se zram0 já estiver montado como swap, avisa
if swapon --show | grep -q "/dev/zram0"; then
    echo "Aviso: /dev/zram0 já se encontra ativo no subsistema de swap."
else
    # Configura algoritmo se estiver em modo reset
    if [ -w /sys/block/zram0/comp_algorithm ]; then
        echo "$RECOMMENDED_ALGO" | sudo tee /sys/block/zram0/comp_algorithm > /dev/null || true
    fi

    # Configura capacidade lógica em bytes
    BYTES=$((RECOMMENDED_ZRAM_MB * 1024 * 1024))
    echo "$BYTES" | sudo tee /sys/block/zram0/disksize > /dev/null

    # Formata como swap
    sudo mkswap /dev/zram0 > /dev/null

    # Ativa com prioridade 100 (mais prioritário que swap de disco que normalmente tem prioridade -1 ou -2)
    sudo swapon --priority 100 /dev/zram0
    echo "Dispositivo /dev/zram0 ativado com prioridade 100!"
fi

# 5. Verificação e Teste de Integridade
echo ""
echo "--> Passo 5: Verificando integridade da instalação..."
"$REPO_ROOT/scripts/verify-installation.sh" zram0

echo ""
echo "========================================================================"
echo "    IMPLANTAÇÃO CONCLUÍDA COM SUCESSO NO $(hostname)!"
echo "========================================================================"
echo "O ZRAM agora é o dispositivo primário de memória comprimida."
echo "Para reverter a qualquer momento, execute: sudo ./scripts/rollback.sh"
