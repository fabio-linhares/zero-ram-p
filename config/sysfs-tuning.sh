#!/usr/bin/env bash
# config/sysfs-tuning.sh
# Aplica parâmetros de alta performance para o subsistema de memória virtual com ZRAM

set -euo pipefail

echo "Aplicando otimizações de memória virtual do kernel..."

# Swappiness: 150 a 180 é o padrão moderno recomendado para ZRAM (ChromeOS e Android utilizam valores elevados)
# Garante que páginas de cache pouco usadas sejam comprimidas em RAM antes de descartar cache de disco
sudo sysctl -w vm.swappiness=150

# Desativa o boost de watermark para evitar que o kswapd acorde agressivamente quando ZRAM está ativo
sudo sysctl -w vm.watermark_boost_factor=0

# Garante que a recuperação de memória inicie suavemente
sudo sysctl -w vm.watermark_scale_factor=125

# page-cluster: 0 desativa a pré-leitura agrupada de blocos (swap de disco precisa de clusters de 8 a 16 páginas;
# ZRAM em RAM prefere leituras página a página de 4KB com latência mínima)
sudo sysctl -w vm.page-cluster=0

echo "Otimizações de VM aplicadas com sucesso!"
