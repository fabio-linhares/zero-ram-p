# Playbook de Implantação Multi-Máquina (Laptops Samsung, Dell e Servidores)
**Projeto Zero RAM: Guia Operacional Passo a Passo para Novas Máquinas**  
*Referência Técnica: Outubro de 2026*  
*Repositório:* [fabio-linhares/zero-ram-p](https://github.com/fabio-linhares/zero-ram-p)

---

## 🎯 Objetivo deste Guia

Este documento orienta a implantação das otimizações do **Projeto Zero RAM** no seu **laptop Samsung** (ou em qualquer outra máquina Linux pessoal ou corporativa).

O processo é projetado para ser:
1. **Universal:** Funciona em Ubuntu, Debian, Fedora, Arch Linux ou derivados.
2. **Não-Destrutivo:** Preserva a swap de disco existente como rede de segurança.
3. **Comprovável:** Inclui testes de integridade e benchmark de latência.
4. **Reversível em 1 Segundo:** Qualquer alteração pode ser desfeita imediatamente pelo script de rollback.

---

## 📋 Pré-requisitos Mínimos no Laptop Samsung

No laptop Samsung, certifique-se de que o sistema possui os utilitários básicos instalados:

### No Ubuntu / Debian / Linux Mint:
```bash
sudo apt update
sudo apt install -y git build-essential util-linux fio
```

### No Arch Linux / Manjaro:
```bash
sudo pacman -Syu --needed git base-devel util-linux fio
```

### No Fedora:
```bash
sudo dnf install -y git make gcc util-linux fio
```

---

## 🚀 Roteiro de Execução Passo a Passo

### Passo 1: Transferir ou Clonar o Repositório para o Samsung

Você pode copiar a pasta do repositório via rede local (SSH/rsync), pendrive, ou clonar do seu servidor:

```bash
# Exemplo via rsync a partir desta máquina:
rsync -avz ~/zero-ram/ usuario_samsung@ip_do_samsung:~/zero-ram/

# Ou acesse o diretório diretamente no laptop Samsung:
cd ~/zero-ram
```

---

### Passo 2: Perfilamento Automático do Hardware Samsung

Execute o perfilador universal. Ele identificará o modelo exato do Samsung, número de núcleos de CPU, quantidade de RAM física e recomendará os parâmetros ideais:

```bash
./scripts/profile-machine.sh
```

**Exemplo de saída esperada:**
* Identifica: `Samsung Electronics - Galaxy Book / NP...`
* Informa CPU, threads e RAM disponível.
* Recomenda tamanho de ZRAM (ex: 8192 MiB se tiver 16GB RAM; 4096 MiB se tiver 8GB).
* Salva os parâmetros em `results/machine_profile_<hostname>.env`.

---

### Passo 3: Ativação Automatizada com Tuning de Kernel

Execute o script de implantação:

```bash
sudo ./scripts/deploy-zeroram.sh
```

**O que este script faz automaticamente:**
1. Lê o perfil gerado no Passo 2.
2. Aplica as regras de sysfs de alta performance em `/etc/sysctl.d/99-zeroram.conf`:
   * `vm.swappiness = 150` (incentiva compressão de páginas frias em RAM com prioridade).
   * `vm.watermark_boost_factor = 0` (evita desperdício de CPU com kswapd agressivo).
   * `vm.page-cluster = 0` (leituras página a página de 4KB com baixa latência).
3. Inicializa `/dev/zram0` com o algoritmo ideal (`zstd` ou `lz4`).
4. Ativa o swap comprimido com **prioridade 100** (precedência sobre SSD/HDD).
5. Executa automaticamente o teste de integridade.

---

### Passo 4: Verificação e Comprovação de Funcionamento

Para inspecionar o status do ZRAM e comprovar a taxa de compressão e integridade:

```bash
./scripts/verify-installation.sh zram0
```

Para verificar o status das swaps ativas:
```bash
swapon --show
zramctl
```

Você verá que `/dev/zram0` aparece com prioridade `100` e seu arquivo ou partição em disco tradicional permanece com prioridade `-1` ou `-2` (como reserva segura em caso de saturação extrema).

---

### Passo 5: Execução do Benchmark de Comprovação (FIO)

Para demonstrar a ausência de inversão de prioridade e comprovar os ganhos de latência na máquina:

```bash
# Teste de leitura/escrita balanceada:
./scripts/run-benchmarks.sh balanced-rw /dev/zram0 teste_samsung_balanceado

# Teste adversarial reproduzindo o cenário do autor (1 CPU com leitor prioritário):
./scripts/run-benchmarks.sh priority-inversion /dev/zram0 teste_samsung_adversarial
```

Os resultados detalhados (IOPS, latência média e percentis p95, p99 e p99.9) serão gravados em formato JSON e CSV em `results/`.

---

## 🛡️ Plano de Contingência e Rollback Zero-Risco

Se por qualquer motivo você desejar desativar o ZRAM e retornar o laptop Samsung exatamente ao estado de fábrica/anterior:

```bash
sudo ./scripts/rollback.sh
```

**O rollback garante:**
* Reativação imediata da swap convencional em disco.
* Execução segura de `swapoff` no dispositivo ZRAM.
* Liberação total da memória RAM alocada pelo ZRAM.
* Ausência de qualquer risco de perda de dados.
