# Autoria & Créditos (Authors & Contributors)

O **Zero RAM** é um projeto de engenharia de sistemas, pesquisa empírica e automação de infraestrutura Linux, construído a partir das discussões e patches mais recentes da **Linux Kernel Mailing List (LKML)**.

---

## 👨‍💻 Autor & Arquiteto do Projeto Zero-RAM

* **Fábio Linhares** ([@fabio-linhares](https://github.com/fabio-linhares))
  * **Papel:** Concepção, arquitetura de sistemas, portabilidade e liderança do projeto.
  * **Contribuições para o repositório:**
    * **Portabilidade de Kernel:** Adaptação da série v2 de 11 patches da LKML para o Linux Kernel 7.0 (`7.0.0-38-generic`), resolvendo quebras de API em assinaturas de buffers de descompressão (`const void *` vs `struct scatterlist *`).
    * **Engenharia de Benchmarks:** Criação do harness automatizado com `fio` para reprodução adversarial do cenário de inversão de prioridade de locks (1 CPU, 4 escritores `nice 19` vs 1 leitor `nice -19`) e do perfil de estresse balanceado (50/50 R/W).
    * **Automação Multi-Máquina:** Desenvolvimento do perfilador inteligente de hardware (`scripts/profile-machine.sh`), instalador de produção (`scripts/deploy-zeroram.sh`), script de rollback atômico e verificador de integridade.
    * **Persistência DKMS:** Empacotamento de módulo fora da árvore (*out-of-tree*) com hooks DKMS para compilação transparente em atualizações de distribuição Ubuntu.
    * **Documentação & Relatórios:** Elaboração do playbook de instalação, relatórios de telemetria em tempo real, provas matemáticas de compressão e deduplicação de páginas.

---

## 🔬 Autores dos Patches Upstream (LKML Series v1/v2)

Os patches originais de redesenho do subsistema `zcomp` foram submetidos à LKML em Outubro de 2026 sob a série *"zram: redesign zcomp and rework backends"* (Patchwork Series [1182147](https://patchwork.kernel.org/series/1182147/)):

* **Sergey Senozhatsky** (`senozhatsky@chromium.org` / Google ChromeOS)
  * Autor principal da série de patches.
  * Arquiteto do desacoplamento dos fluxos de compressão (`zcomp_cstrm`) e descompressão (`zcomp_dstrm`), eliminando a contenção mútua de locks em UIs de 90Hz/120Hz.
  * Implementação do compressor singleton para recompressão (`recomp_cstream`), economizando até 5,3 MB de RAM física por dispositivo.
  * Implementação da sincronização via `rw_semaphore` para descompressão concorrente com leitura compartilhada.

* **Barry Song** (`v-songbaohua@oppo.com` / `baohua@kernel.org` / Xiaomi / OPPO)
  * Co-desenvolvedor dos backends de compressão e otimizações de concorrência em dispositivos multinúcleo e sistemas embarcados.

---

## 🏛️ Autores Originais do Módulo ZRAM no Kernel Linux

* **Nitin Gupta**
  * Criador e autor original do driver `compcache` / `zram` no kernel Linux (2008–2010).
* **Minchan Kim**
  * Mantenedor histórico, desenvolvedor de melhorias de alocação `zsmalloc`, recompressão e paginação (2012–2016).

---

## 🤝 Agradecimentos & Referências

* A toda a comunidade de desenvolvedores do **Linux Memory Management (linux-mm)** e mantenedores da LKML.
* Aos times do **Google ChromeOS** e **Android**, cujas demandas de fluidez de interface gráfica e altas taxas de atualização serviram como estímulo para o fim da contenção de locks de descompressão no kernel Linux.
