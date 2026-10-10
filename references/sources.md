# Fontes e Referências Oficiais - Projeto Zero RAM

## 1. Séries Oficiais de Patches (Upstream LKML & Patchwork)

### Série v2 (09 de Outubro de 2026 - Versão Corrente Recomendada)
* **Título:** `[PATCH v2 00/11] zram: redesign zcomp and rework backends`
* **Patchwork Series ID:** [1182147](https://patchwork.kernel.org/series/1182147/)
* **Autor:** Sergey Senozhatsky (`senozhatsky@chromium.org`)
* **Colaborador:** Barry Song (`v-songbaohua@oppo.com`)
* **Mbox Completo:** `patches/upstream/series-v2.mbox`
* **Patches Individuais:** `patches/upstream/v2/0001` a `patches/upstream/v2/0011`
* **Diferencial Crítico em v2:** O Patch 11/11 adiciona o uso de `rw_semaphore` para streams de descompressão (`zcomp_dstrm`), estendendo o paralelismo para leituras concorrentes em backends *stateless* e eliminando a inversão de prioridade entre múltiplos leitores.

### Série v1 (05 de Outubro de 2026 - Versão Inicial)
* **Título:** `[PATCH 00/10] zram: redesign zcomp and rework backends`
* **Patchwork Series ID:** [1179614](https://patchwork.kernel.org/series/1179614/)
* **LKML Cover Letter:** https://lkml.iu.edu/2610.0/08424.html
* **Mbox Completo:** `patches/upstream/series-v1.mbox`
* **Patches Individuais:** `patches/upstream/v1/0001` a `patches/upstream/v1/0010`

---

## 2. Literatura Científica e Conferências Relevantes

1. **Ariadne (IEEE HPCA 2025):**  
   *LIANG, Yu et al.* "Ariadne: A Hotness-Aware and Size-Adaptive Compressed Swap Technique for Fast Application Relaunch and Reduced CPU Usage on Mobile Devices". *HPCA 2025*, p. 1588–1602.  
   DOI: [10.1109/HPCA61900.2025.00118](https://doi.org/10.1109/HPCA61900.2025.00118) | [arXiv:2502.12826](https://arxiv.org/abs/2502.12826)

2. **Archer (USENIX FAST 2025):**  
   *LI, Changlong et al.* "Archer: Adaptive Memory Compression with Page-Association-Rule Awareness for High-Speed Response of Mobile Devices". *USENIX FAST '25*, p. 497–511.  
   Link: [USENIX FAST 2025](https://www.usenix.org/conference/fast25/presentation/li)

3. **ASAP (USENIX ATC 2021):**  
   *SON, Sam et al.* "ASAP: Fast Mobile Application Switch via Adaptive Prepaging". *USENIX ATC '21*.  
   Link: [USENIX ATC 2021](https://www.usenix.org/conference/atc21/presentation/son)

4. **TMO: Transparent Memory Offloading (ACM ASPLOS 2022):**  
   *WEINER, Johannes et al.* "TMO: Transparent Memory Offloading in Datacenters". *ASPLOS 2022*, p. 609–621.  
   DOI: [10.1145/3503222.3507731](https://doi.org/10.1145/3503222.3507731)

5. **Barry Song - Linux Plumbers Conference (2023–2024):**  
   Discussões sobre mitigação de contenção de travas e inversão de prioridade em sistemas interativos de 90Hz/120Hz.  
   Link: [Linux Plumbers LPC](https://lpc.events)
