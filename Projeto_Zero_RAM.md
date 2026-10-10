# PROJETO ZERO RAM
## Investigação, implementação experimental e avaliação do rework de ZRAM no Arch Linux

**Versão:** 1.0 — Projeto técnico-científico e plano de execução  
**Data de referência da pesquisa:** 9 de outubro de 2026  
**Plataforma-alvo:** Arch Linux, hardware a caracterizar  
**Estado:** proposta de pesquisa e engenharia; implementação e benchmarks próprios ainda não executados  
**Natureza:** software de sistemas, kernel Linux, compressão de memória, avaliação experimental

> **Nota de nomenclatura:** “Zero RAM” é o nome de trabalho deste projeto. Não significa funcionamento sem RAM ou multiplicação física da memória. A tecnologia investigada chama-se **ZRAM**. O escopo principal é a série de patches *“zram: redesign zcomp and rework backends”*, enviada por Sergey Senozhatsky à Linux Kernel Mailing List em 5/10/2026 [P01].

---

## RESUMO EXECUTIVO

Este projeto propõe estudar, portar quando necessário, compilar, testar e avaliar uma reformulação interna do subsistema ZRAM do kernel Linux em uma instalação Arch Linux, **sem substituir o kernel estável de produção**. ZRAM implementa dispositivos de bloco residentes em RAM que armazenam dados comprimidos e podem funcionar como swap. Sua utilidade depende do equilíbrio entre economia de capacidade, custo de CPU, padrões de acesso e comportamento da política de recuperação de memória (*page reclaim*) [D01, A01, A02].

A motivação imediata é a série de dez patches submetida em 5/10/2026. Seus dois últimos patches separam contextos de compressão e descompressão antes compartilhados em *streams* por CPU e substituem contextos redundantes de recompressão por um único contexto de compressão por dispositivo, preservando descompressores concorrentes [P01–P03]. Os resultados apresentados pelo autor são expressivos em testes sintéticos construídos para expor inversão de prioridade, mas **não constituem comprovação de aceleração geral de desktops, máquinas virtuais ou inferência de LLMs**.

A proposta tem quatro produtos: (i) kernel experimental Arch empacotado de forma reproduzível; (ii) protocolo e ferramentas de benchmark; (iii) análise comparativa A/B com medidas de latência, contenção, memória, CPU e estabilidade; e (iv) relatório de decisão sobre manter, rejeitar ou aguardar a incorporação *upstream*. A literatura científica dá forte sustentação à relevância da memória comprimida e da avaliação de latências de cauda, mas **o ganho concreto deste patch no equipamento de destino permanece uma hipótese a testar** [A01–A11].

### Parecer de viabilidade

- **Viabilidade conceitual:** alta. A alteração proposta pelo autor é tecnicamente específica e acompanhada de código e medições [P01–P03].
- **Viabilidade de portabilidade:** condicionada à identificação do *commit* base e ao estado da árvore Linux/Arch escolhida. Não se presume aplicação limpa ao kernel mais recente.
- **Risco operacional:** moderado a alto se implementado no sistema de produção sem isolamento, *backup*, kernel de retorno e testes.
- **Mérito acadêmico:** adequado a um estudo de engenharia experimental e replicação/validação independente; a mera aplicação dos patches não constitui inovação científica original.
- **Critério decisivo:** ganhos reproduzíveis em cargas relevantes, ausência de corrupção de dados e custo operacional aceitável.

---

## 1. QUESTÃO DE PESQUISA E ESCOPO

**Pergunta central:** Em comparação com um kernel Linux de mesma versão e configuração sem a série de patches, a separação dos caminhos de compressão e descompressão do ZRAM e a reorganização dos contextos de recompressão reduzem a latência de leitura, a contenção de *locks* e o consumo de memória dos contextos, sem introduzir regressões relevantes de throughput, estabilidade ou consumo de CPU em um sistema Arch Linux?

**Objetivo geral:** implementar uma construção experimental controlada do ZRAM reformulado e estimar seus efeitos de desempenho e consumo de memória por meio de benchmarks replicáveis e testes funcionais.

**Objetivos específicos:**

1. Documentar a arquitetura existente do ZRAM, suas interfaces e seu custo de execução.
2. Identificar exatamente os dez patches de outubro de 2026, sua versão e dependências.
3. Construir kernels de controle e intervenção a partir **do mesmo código-base**, preservando ferramentas, opções de compilação e configuração.
4. Reproduzir, quando tecnicamente viável, a condição de inversão de prioridade descrita no patch 9/10.
5. Avaliar memória reservada pelos contextos e efeitos do *singleton* de recompressão do patch 10/10.
6. Medir impactos em cargas representativas de desktop, desenvolvimento, contêineres e, exploratoriamente, IA local.
7. Produzir instruções de implantação e reversão seguras no Arch Linux.
8. Comparar as evidências obtidas com a literatura e registrar resultados nulos ou negativos.

**Fora do escopo inicial:** reescrever algoritmos LZ4/ZSTD, modificar o subsistema de swap inteiro, alterar o alocador zsmalloc, prometer aumento fixo de RAM, desenvolver mecanismo de hibernação em ZRAM, migrar para CRAM, ou alegar aumento de VRAM/disponibilidade de contexto de GPU. Essas atividades podem constituir projetos separados.

---

## 2. FUNDAMENTAÇÃO TÉCNICA

### 2.1. Hierarquia de memória e razão para comprimir páginas

A motivação histórica vem da diferença entre o custo de CPU de comprimir/descomprimir e o custo de recuperar páginas de níveis mais lentos da hierarquia. Douglis (1993) estudou o uso de compressão online para ampliar a capacidade *efetiva* de memória; Wilson, Kaplan e Smaragdakis (1999) formalizaram o cache comprimido como nível intermediário da hierarquia e mostraram que o benefício depende de carga de trabalho e adaptação da quantidade de memória comprimida [A01, A02].

**Consequência metodológica:** só haverá benefício se o custo de armazenar/recuperar dados comprimidos for compensado pela redução de pressão de memória ou de I/O evitado. Em workloads sem pressão de memória, o efeito pode ser próximo de zero; páginas pouco compressíveis ou muito acessadas podem gerar custo de CPU sem benefício correspondente.

### 2.2. ZRAM não é Zswap

- **ZRAM:** apresenta `/dev/zramN` como dispositivo de bloco; quando usado como swap, as páginas são armazenadas comprimidas em RAM [D01]. Não exige armazenamento secundário para manter o conteúdo, embora o ZRAM também ofereça funcionalidades opcionais de *writeback*.
- **Zswap:** é um cache comprimido de páginas em trânsito para swap, integrado ao subsistema de troca; quando seu conjunto comprimido precisa expulsar páginas, elas podem seguir para o dispositivo de swap subjacente [D02].
- **Swap em SSD:** transferência para dispositivo físico de armazenamento, com características distintas de latência, capacidade e desgaste.
- **CRAM:** linha experimental distinta, baseada em uma camada de memória comprimida associada a nós privados; não é sinônimo de ZRAM nem integra o escopo de implementação [F01, F02].

Executar ZRAM e Zswap concomitantemente pode alterar a trajetória das páginas e introduzir dupla compressão ou confundimento experimental, conforme a configuração. **Na comparação principal, o estado de Zswap será fixado e documentado**, preferencialmente desativado, se a auditoria indicar que essa mudança é segura. Não se modificará a configuração em produção sem avaliação prévia.

### 2.3. Por que o novo rework pode melhorar o desempenho?

No modelo descrito no patch, leitura e escrita de ZRAM compartilhavam um *stream* por CPU, protegido por exclusão mútua. Sob preempção, um escritor de baixa prioridade poderia segurar o *mutex*, ser interrompido e bloquear um leitor prioritário. A separação de *streams* de **compressão** (*write*, `zcomp_cstrm`) e **descompressão** (*read*, `zcomp_dstrm`) visa remover essa competição cruzada, pois seus buffers são independentes [P02].

Essa mudança não elimina **toda** contenção no ZRAM ou em outros componentes do kernel. Ela ataca um mecanismo específico: compartilhamento de um *mutex* entre caminhos de leitura e escrita.

A recompressão usa algoritmos secundários e, na implementação analisada, é serializada por um bloqueio de dispositivo. A proposta substitui contextos de **compressão secundária por CPU** por um único contexto de compressão por dispositivo, mas mantém contextos de descompressão concorrentes, evitando alocações redundantes [P03].

### 2.4. O que os autores dos patches realmente mediram?

No patch 9/10, Sergey Senozhatsky apresentou o seguinte teste `fio`, deliberadamente adversarial: uma CPU, `preempt=full`, ZSTD nível 12, quatro escritores de baixa prioridade (`nice 19`), uma tarefa intensiva de CPU (`nice 0`) e um leitor de alta prioridade (`nice -19`) [P02].

| Indicador | Baseline | Com patch | Resultado reportado |
|---|---:|---:|---:|
| IOPS de leitura, 1 CPU | 1.278 | 43,3 mil | 33,9× |
| Latência média, 1 CPU | 762,21 μs | 9,95 μs | redução de ~76,6× na razão de latências |
| Latência p99,99, 1 CPU | 387.974 μs | 53,50 μs | redução de ~7.252× na razão de latências |
| IOPS de leitura, 24 CPUs | 354 mil | 997 mil | 2,8× |
| Latência média, 24 CPUs | 53,20 μs | 11,00 μs | redução de ~4,8× na razão de latências |

Os valores são do **autor do patch**, não de experimentação independente. Eles demonstram plausibilidade e relevância sob condições que expõem o *lock*, mas **não devem aparecer na divulgação do projeto como promessa de desempenho em tarefas comuns**. O teste depende de preempção, afinidade, prioridades, simultaneidade e algoritmo. A reprodução independente é parte central do projeto.

No patch 10/10, para um sistema x86-64 de oito CPUs com páginas de 4 KiB, o autor estima a seguinte economia em contextos de recompressão [P03]:

| Backend / configuração | Economia reportada |
|---|---:|
| ZSTD nível 3, padrão | ~700 KiB |
| ZSTD níveis 12–22, sem dicionário | ~1,91 MiB |
| ZSTD níveis 14–22, dicionário de 110 KiB | ~5,33 MiB, com alocação preguiçosa (*lazy*) |
| DEFLATE, configuração padrão | ~1,04 MiB |
| LZ4HC | ~1,84 MiB |

Esses valores são **condicionais à configuração**, sobretudo ao uso de algoritmos secundários de recompressão. Não representam aumento equivalente de memória livre em todo boot nem economia garantida do sistema completo.

---

## 3. REVISÃO CRÍTICA DA LITERATURA

Esta revisão distingue resultados revisados por pares de documentação oficial, submissões de patches e divulgações. Os estudos abaixo foram selecionados pelo vínculo com memória comprimida, latência, custo computacional, recuperação de páginas ou rigor de medição, **não por todos analisarem especificamente o rework de outubro de 2026**.

### 3.1. Estudos fundamentais sobre memória comprimida

**Douglis (1993), *The Compression Cache: Using On-line Compression to Extend Physical Memory* [A01].** Trabalho fundador em USENIX. Sustenta a arquitetura conceitual de manter memória em representação comprimida e usar ciclos de CPU para reduzir pressão sobre outros níveis. **Limitação:** hardware, workloads e custos de I/O pertencem a outra geração; não é benchmark do Linux contemporâneo.

**Wilson, Kaplan e Smaragdakis (1999), *The Case for Compressed Caching in Virtual Memory Systems* [A02].** Analisa a viabilidade de cache comprimido em memória virtual e a necessidade de adaptação ao comportamento do programa. **Aplicação:** fundamenta hipóteses relativas à compressibilidade, frequência de acesso e regimes nos quais a solução deixa de compensar. **Limitação:** anterior à implementação moderna de ZRAM e aos SSDs NVMe.

### 3.2. Estudos atuais de compressão e swap em sistemas móveis

**Liang et al. (2025), *Ariadne* — HPCA [A03].** Estudo revisado por pares, diretamente relacionado ao ZRAM em Android. Propõe distinguir páginas quentes e frias, variar a granularidade de compressão e antecipar descompressão. Em Google Pixel 7, relata, em média, redução de 50% da latência de reabertura de aplicativos e 15% do uso de CPU relacionado à compressão/descompressão ante a referência testada. **Contribuição ao projeto:** mostra que organização e acesso a páginas importam tanto quanto a taxa de compressão. **Limitação:** usa um conjunto de técnicas diferente do rework ZCOMP e ambiente móvel, logo não permite transferir percentuais para Arch Linux.

**Li et al. (2025), *Archer* — FAST [A04].** Propõe compressão sensível às associações entre páginas e granulação flexível, com respostas mais rápidas em cargas móveis. **Contribuição:** sustenta a necessidade de testar padrões de acesso reais, não somente throughput de compressão isolada. **Limitação:** arquitetura e objetivos diferentes; não valida o patch de Senozhatsky.

**Son et al. (2021), *ASAP* — USENIX ATC [A05].** Analisa a latência de retomada de aplicativos móveis sob pressão de memória e evidencia que a descompressão e a recuperação de páginas continuam no caminho crítico, mesmo quando se evita matar processos. **Contribuição:** justifica latência de retomada e picos de acesso como métricas complementares ao IOPS. **Limitação:** solução focaliza pré-paginação adaptativa.

**Wang, Tsai e Chang (2021), “Killing Processes or Killing Flash?”, ACM TECS [A06].** Avalia recuperação de memória e troca com consciência da compressibilidade em dispositivos móveis. **Contribuição:** reforça que páginas têm compressibilidades distintas e que políticas de seleção/importação importam. **Limitação:** não é evidência de ganhos do rework analisado.

### 3.3. Custo de CPU e interferência em aplicações sensíveis

**Ji et al. (2023), *STYX* — USENIX ATC [A07].** A arquitetura transfere parte do trabalho de otimizações do kernel, inclusive Zswap, para SmartNICs. O estudo informa redução de 55–89% na latência p99 de aplicações concorrentes, em comparação ao cenário correspondente sem STYX. **Contribuição:** mostra que compressão no kernel consome recursos compartilhados e pode afetar aplicações não diretamente envolvidas com swap. **Limitação:** usa Zswap e hardware acelerador, não o ZRAM revisado.

**Xia et al. (2025), *Hardware-Accelerated Kernel-Space Memory Compression Using Intel QAT* — IEEE Computer Architecture Letters [A08].** Relata que Zswap executado na CPU elevou em 3,2–12,1× a latência de cauda de uma aplicação Redis concorrente nas condições avaliadas; a abordagem acelerada por QAT mitigou o efeito. **Contribuição:** fundamenta medições de interferência e custo de CPU. **Limitação:** trata de Zswap e CPUs de servidor com QAT; não implica que o usuário deva empregar QAT.

**Karandikar et al. (2023), *CDPU* — ISCA [A09].** Caracteriza custos de compressão/descompressão em serviços de nuvem e destaca a heterogeneidade entre algoritmos e cargas. **Contribuição:** apoia análise separada de compressão e descompressão e a necessidade de especificar algoritmo, nível e distribuição de dados. **Limitação:** escopo de hyperscale e co-design de hardware, não benchmark direto de ZRAM.

### 3.4. Gerenciamento de memória Linux e confiabilidade de alterações

**Weiner et al. (2022), *TMO: Transparent Memory Offloading in Datacenters* — ASPLOS [A13].** Investiga descarregamento transparente de páginas menos acessadas para camadas alternativas de memória e utiliza sinais de pressão para orientar decisões. Os autores reportam economia agregada de memória no ambiente de datacenter estudado, resultado dependente de políticas, dispositivos e workloads. Um exemplo particularmente relevante é a baixa compressibilidade (aproximadamente 1,3–1,4×) observada em determinados modelos de predição de anúncios quantizados em bytes. **Aplicação:** incluir dados incompressíveis ou pouco compressíveis nos testes e não pressupor que pesos de LLM quantizados sejam altamente compressíveis. **Limitação:** TMO não testa o rework de ZRAM nem demonstra que todo LLM terá aquela mesma taxa.

**Huang, Qureshi e Schwan (2016), *An Evolutionary Study of Linux Memory Management for Fun and Profit* — USENIX ATC [A10].** Estudo longitudinal de patches do gerenciador de memória Linux. **Contribuição:** sustenta a necessidade de processo rigoroso de validação e atenção a regressões em alterações do kernel. **Limitação:** não avalia a implementação aqui proposta.

**Yu Zhao e colaboradores, Multi-Gen LRU (MGLRU) [D04, K01].** Documentação e séries de patches explicam como recuperação de páginas, working set e *thrashing* influenciam desempenho sob pressão de memória. **Contribuição:** MGLRU deve ser mantido na mesma configuração nos dois kernels para não confundir resultados. **Classificação:** documentação técnica e patches, não um ensaio acadêmico independente sobre o rework.

### 3.5. Avaliação estatística e latência de cauda

**Curtsinger e Berger (2013), *STABILIZER: Statistically Sound Performance Evaluation* — ASPLOS [A11].** Demonstra que decisões de otimização baseadas em medições ocasionais podem ser afetadas pela variabilidade de compilação e de execução; recomenda desenho experimental e inferência estatística apropriados. **Aplicação:** replicações, controle ambiental, distribuição de resultados e relato de incerteza.

**Dean e Barroso (2013), *The Tail at Scale* — Communications of the ACM [A12].** Mostra a importância das caudas da distribuição de latência para sistemas responsivos. **Aplicação:** definir métricas p95, p99 e p99,9/p99,99 quando houver amostragem suficiente, além de médias. **Limitação:** estudo de serviços distribuídos; a motivação estatística é transferível, mas não os ganhos quantitativos.

### 3.6. Síntese e lacuna de conhecimento

**Evidência consolidada:** compressão de páginas pode ser útil sob determinadas condições de pressão de memória; CPU, compressibilidade, políticas de *reclaim* e latências de descompressão influenciam o resultado [A01–A09, A13, D01–D04].

**Evidência específica, porém preliminar:** os patches de 5/10/2026 apresentam um mecanismo plausível para reduzir inversão de prioridade e redundância de contextos, acompanhado de resultados sintéticos fornecidos pelo proponente [P01–P03].

**Ainda não demonstrado neste projeto:** que as alterações melhorem continuamente o desempenho do Arch Linux, que sejam benéficas para LLMs locais ou que a redução de latência se mantenha em workloads heterogêneos sob restrições térmicas reais.

A **lacuna** é uma replicação independente, controlada por versão de kernel e executada em plataforma x86-64 Arch Linux, que desagregue efeitos de contenção, recompressão, consumo de contexto e aplicações reais.

---

## 4. HIPÓTESES, VARIÁVEIS E CRITÉRIOS

**H1 — contenção:** em cenários mistos com leitores e escritores concorrentes de prioridades diferentes, o kernel com patch 9/10 reduz a latência p99/p99,9 das leituras de ZRAM comparado ao kernel base.

**H2 — memória:** em cenários com recompressão secundária habilitada, o kernel com patch 10/10 consome menos memória em contextos de compressão secundária do que o controle.

**H3 — compatibilidade:** sob cargas usuais, os patches não introduzem falhas de integridade, OOM injustificado, travamentos ou regressões relevantes de throughput.

**H4 — relevância prática:** qualquer ganho expressivo no benchmark artificial de prioridade não necessariamente se traduz em melhora significativa em carga desktop ou inferência local. Trata-se de hipótese de heterogeneidade, não de expectativa de ganho.

**Variáveis independentes:** kernel (controle/intervenção), algoritmo (LZ4/ZSTD e, se suportado, outros), nível, uso de recompressão, quantidade de CPUs habilitadas/afinidade, número de leitores/escritores, distribuição de prioridades, pressão de memória, tipo de carga.

**Variáveis dependentes:** p50/p95/p99/p99,9 de latência, IOPS, throughput, ciclos de CPU, tempo de espera por bloqueios, PSI de memória, falhas de alocação, medidas de memória de ZRAM/contextos e estabilidade.

**Controles:** mesmo código-base, `config`, compilador/toolchain, frequência/política de CPU, zswap, MGLRU, swappiness, cgroups, RAM disponível, algoritmo/dicionário, limites térmicos, processo de inicialização, serviços concorrentes e dados usados nos testes.

**Critérios de aceitação (definir limiares operacionais antes dos testes):**

- Nenhuma corrupção de dados em testes de escrita/leitura e integridade.
- Ausência de erros graves de kernel reproduzíveis ou regressões de boot/suspend relevantes.
- Melhora de H1/H2 mensurável e com incerteza quantificada, caso os cenários específicos se apliquem.
- Regressões práticas documentadas, ainda que a hipótese de ganho não seja confirmada.
- Processo de atualização/reversão compreensível e independente do pacote Linux padrão.

---

## 5. PROJETO DA IMPLEMENTAÇÃO

### 5.1. Princípio de isolamento

Serão mantidos **dois kernels empacotados e inicializáveis separadamente**:

1. `linux` do Arch Linux, preservado para operação normal e recuperação.
2. `linux-zeroram` (nome proposto, não oficial), derivado de uma versão fixa da árvore Linux compatível com a série de patches, com os dez commits experimentais aplicados.

**Para experimentação causal mais limpa**, haverá ainda dois artefatos de teste com mesmo código-base: `control-K` (sem os dez patches) e `patched-K` (com eles). O kernel usual de produção não substitui o controle científico caso tenha outra versão.

### 5.2. Caminho de construção recomendado

1. Registrar `uname -a`, arquitetura, CPU, RAM, versão do compilador, hardware, bootloader e condições de segurança.
2. Localizar as mensagens originais 00/10–10/10 por Message-ID e obter a série integral de fontes confiáveis. Verificar se há versões posteriores, alterações de contexto ou discussão de regressões.
3. Identificar a árvore-base efetivamente usada pelo autor e escolher um *commit/tag* fixo. Se houver conflitos, registrar adaptações locais separadas dos patches originais; **não forçar hunks nem aplicar automaticamente por offset**.
4. Compilar primeiro o controle, aplicar a série ao segundo build e comparar opções relevantes do kernel.
5. Executar `git diff --check`, análise de mudanças, testes estáticos disponíveis e testes próprios em máquina virtual, observando limitações de fidelidade de microbenchmarks em VM.
6. Empacotar o kernel e os headers usando o fluxo Arch `PKGBUILD`/`makepkg`, `pkgbase` próprio, versão local única, sem sobrescrever o kernel oficial [D06].
7. Gerar initramfs e entrada de boot dedicada somente após validação de drivers, partições, criptografia e espaço no ESP/`/boot`.
8. Implantar primeiro em boot experimental; manter kernel de retorno e mídia de recuperação.

**Observação:** as instruções exatas de compilação, formato de initramfs, assinatura de Secure Boot e drivers DKMS/NVIDIA dependem do inventário real da máquina. Este documento evita inserir comandos genéricos que possam inutilizar o boot.

### 5.3. Matriz de componentes modificados

A série inclui dez commits [P01]:

| Patch | Área | Finalidade anunciada |
|---|---|---|
| 01/10 | Logs dos backends | Prefixos de mensagens |
| 02/10 | Debugfs | Limpeza adequada em falha de inicialização |
| 03/10 | ZSTD | Evitar alocação de dicionários vazios |
| 04/10 | LZ4HC | Pré-inicializar contexto associado a dicionários |
| 05/10 | LZ4 | Usar descompressão com dicionário apropriado |
| 06/10 | LZ4HC | Ajuste análogo para dicionário |
| 07/10 | ZSTD | Revisar estratégia de alocação de memória |
| 08/10 | Reset/writeback | Reinicializar estado de writeback |
| **09/10** | **`zcomp`** | **Separar streams de leitura e escrita** |
| **10/10** | **`zcomp` e `zram_drv`** | **Singleton de compressor de recompressão** |

Arquivos previstos pela carta de apresentação: `backend_842.c`, `backend_deflate.c`, `backend_lz4.c`, `backend_lz4hc.c`, `backend_lzo.c`, `backend_lzorle.c`, `backend_zstd.c`, `zcomp.c`, `zcomp.h`, `zram_drv.c`. A carta informa 421 inserções e 293 remoções nos dez arquivos [P01].

### 5.4. Infraestrutura e organização do repositório

```text
zero-ram/
├── README.md
├── docs/
│   ├── PROJETO.md
│   ├── revisao_bibliografica.md
│   ├── protocolo_experimental.md
│   ├── riscos_e_rollback.md
│   └── log_decisoes.md
├── patches/
│   ├── upstream/              # patches originais, com proveniência
│   └── portabilidade/         # adaptações próprias, separadas
├── packaging/
│   └── arch/                  # PKGBUILD/presets conforme inventário
├── config/
│   ├── baseline/
│   └── experimental/
├── scripts/
│   ├── audit-readonly.sh
│   ├── collect-metrics.sh
│   ├── validate-environment.sh
│   └── analyze-results.py
├── benchmarks/
│   ├── fio/
│   ├── memory-pressure/
│   └── real-workloads/
├── results/
│   └── .gitkeep
└── references/
    ├── sources.md
    └── provenance.json
```

Registre *hash* do kernel, patches, configurações, `PKGBUILD`, scripts e dados de entrada. Publicar a procedência da série e respeitar licenças e identificação dos autores originais.

---

## 6. PROTOCOLO EXPERIMENTAL

### 6.1. Tratamentos

| Identificador | Kernel | Configuração de memória | Objetivo |
|---|---|---|---|
| C0 | Controle | ZRAM desabilitado, sob condições seguras | Referência contextual de uso comum; não é contraste causal principal |
| C1 | Controle K | ZRAM primário, algoritmo fixado | Baseline científico do rework |
| T1 | Patched K | Mesma configuração de C1 | Efeito da série sob ZRAM primário |
| C2 | Controle K | ZRAM com recompressão secundária | Baseline de memória dos contextos |
| T2 | Patched K | Mesma configuração de C2 | Efeito do contexto singleton |
| C3/T3 | K / Patched K | Prioridades e concorrência adversariais | Replicação do patch 09/10 |

**Não realizar testes de falta de swap ou exaustão indiscriminada de RAM na máquina de trabalho.** Usar VM ou ambientes controlados com limites de memória, *backup* e caminho de recuperação. Não sobrescrever `/dev/zram0` caso esteja ativo como swap: testes diretos de bloco exigem dispositivo separado e não montado, ou ambiente descartável.

### 6.2. Cenários

1. **Microbenchmark da mudança principal:** `fio` com fluxos concorrentes de leitura/escrita, diferenças de prioridade e afinidade; reproduzir inicialmente parâmetros da mensagem [P02] e depois explorar configurações usuais.
2. **Sem inversão de prioridade deliberada:** leituras e escritas equilibradas; identificar possíveis regressões e a magnitude do efeito sem situação patológica.
3. **Algoritmos:** LZ4 e ZSTD em configurações viáveis; distinguir compressão primária de recompressão secundária. Não misturar algoritmo e tratamento no mesmo contraste.
4. **Pressão de memória:** `stress-ng` ou aplicações controladas com limites de memória e monitoramento de PSI, *major faults*, `pswpin`, `pswpout`, `kswapd` e OOM.
5. **Uso real:** IDE, navegador, notebooks de dados, contêineres, processos concorrentes. Roteiros com duração e dados fixos, quando possível.
6. **IA local exploratória:** execução de modelo quantizado fixo com configuração idêntica de offload, número de threads, cache e contexto. Medir tokens/s, primeira resposta, latência, RSS e PSI. Não concluir que RAM comprimida equivale a VRAM ou acelera GPU.
7. **Ciclos de vida:** carregar/descarregar ZRAM, redefinição do dispositivo, reinício, hotplug de CPU quando suportado, recompressão, falhas de alocação simuladas e modo de suspensão, quando aplicável.

### 6.3. Métricas e instrumentos

**ZRAM:** `zramctl`, `swapon --show`, `/sys/block/zramN/mm_stat`, `io_stat`, `bd_stat`, `stat`, atributos de algoritmo e recompressão [D01].

**Memória:** `/proc/meminfo`, `/proc/vmstat`, `/proc/slabinfo`, `free`, `slabtop`, `vmstat`, cgroups. **Atenção:** `mm_stat` descreve métricas do dispositivo e não é prova suficiente de que toda alocação por CPU/contexto foi contabilizada; complementar com tracing de alocações e análise de slab quando necessário.

**Pressão:** `/proc/pressure/memory`, `/proc/pressure/io` e `/proc/pressure/cpu` (PSI), obtendo `some`, `full` e acumulados conforme disponíveis [D03].

**Custo e contenção:** `perf stat`, `perf record`, `perf lock`/`perf lock contention`, `trace-cmd`, ftrace/BPF, se disponíveis, com controle do *overhead* de instrumentação [D07].

**Estabilidade:** `journalctl -k -b`, mensagens OOM, avisos de lockdep/KASAN/KCSAN conforme build de teste, erros de I/O e checksums.

### 6.4. Definição correta da eficiência de memória

Para um dispositivo `/dev/zramN`, documentação oficial distingue [D01]:

- `orig_data_size`: volume lógico de dados antes da compressão.
- `compr_data_size`: volume comprimido dos dados armazenados.
- `mem_used_total`: memória contabilizada para o dispositivo, incluindo desperdício do alocador e metadados conforme o escopo dessa métrica.

Definições úteis:

```text
Razão de compressão (dados) = orig_data_size / compr_data_size
Eficiência residente do dispositivo = orig_data_size / mem_used_total
Overhead contabilizado = mem_used_total - compr_data_size
Economia de contexto do rework = contexto_base - contexto_patched
```

Excluir casos com denominador zero e registrar unidade. **Não confundir o tamanho lógico do dispositivo ZRAM com memória RAM fisicamente reservada**, e não atribuir automaticamente `orig_data_size - mem_used_total` a RAM “liberada” no sistema como um todo: política de reclaim, cache e ausência de ZRAM mudam a composição da memória do sistema.

### 6.5. Estratégia estatística

- Pré-registrar cenário, endpoint primário (sugestão: p99 de latência de leitura em C3/T3), limiar de regressão tolerável e regras de descarte.
- Executar rodadas independentes, com *warm-up* e ordem balanceada ABBA/BAAB quando operacionalmente possível; comparar distribuições completas.
- Realizar um piloto e dimensionar as repetições pela variabilidade observada; **20 rodadas por tratamento é ponto de partida ilustrativo, não tamanho amostral universal**.
- Reportar mediana, média, desvio-padrão, p95/p99/p99,9 com contagem de amostras suficiente, intervalos de confiança por reamostragem apropriada e tamanho de efeito.
- Evitar afirmar significância estatística apenas por diferenças percentuais. Quando houver dependência temporal, empregar unidade de reamostragem na rodada independente, e não em milhões de requisições correlacionadas.
- Registrar temperatura, throttling, frequência, serviços de fundo, reboot e ordem experimental. Documentar dados faltantes e resultados negativos [A11, A12].

### 6.6. Triangulação causal da intervenção

Para dissociar os mecanismos internos, se a portabilidade permitir, criar builds de ablação sobre a mesma árvore:

- **K0:** nenhum dos dez patches;
- **K1:** patches 01–08 (ajustes preparatórios);
- **K2:** patches 01–09 (separação R/W);
- **K3:** patches 01–10 (inclui singleton).

K1→K2 estima o efeito incremental da separação R/W; K2→K3 estima o efeito incremental do singleton nos cenários apropriados. A comparação K0→K3 mede o conjunto completo. **Não concluir independência de efeitos sem considerar dependências e interações.**

---

## 7. IMPLANTAÇÃO NO ARCH LINUX: PROCEDIMENTO SEGURO

### 7.1. Auditoria somente de leitura (primeira execução)

```bash
printf '\n=== SISTEMA ===\n'
uname -a
cat /etc/os-release
printf '\n=== CPU E RAM ===\n'
lscpu | grep -E 'Architecture|Model name|CPU\(s\)|Thread|Core|Socket'
free -h
printf '\n=== SWAP E ZRAM ===\n'
swapon --show
zramctl
for d in /sys/block/zram*; do
  [ -d "$d" ] || continue
  echo "[$d]"
  for f in comp_algorithm mm_stat io_stat; do
    [ -r "$d/$f" ] && { echo "$f:"; cat "$d/$f"; }
  done
done
printf '\n=== ZSWAP E PRESSÃO ===\n'
[ -r /sys/module/zswap/parameters/enabled ] && cat /sys/module/zswap/parameters/enabled
for f in /proc/pressure/{cpu,memory,io}; do
  [ -r "$f" ] && { echo "$f"; cat "$f"; }
done
printf '\n=== BOOT / MÓDULOS ===\n'
cat /proc/cmdline
findmnt /boot
findmnt /efi
pacman -Q | grep -E '^(linux|nvidia|mkinitcpio|dracut|systemd)' || true
printf '\n=== ESPAÇO ===\n'
df -h / /boot /efi 2>/dev/null
```

A saída pode conter nomes de máquina, caminhos ou detalhes de montagem: revisar antes de publicar. O script é apenas informativo e não modifica parâmetros.

### 7.2. Configuração controlada de ZRAM convencional

O `zram-generator` do systemd permite definir tamanho, algoritmo e prioridade [D05]. Exemplo **ilustrativo** para teste somente após verificar a configuração atual e necessidades de hibernação:

```ini
# /etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
swap-priority = 100
```

O valor de `zram-size` é **capacidade lógica em MiB**, não reserva física imediata. Não criar configuração duplicada se o sistema já usa outro gerenciador de ZRAM, e não mudar o compressor de um dispositivo ativo sem o procedimento adequado. Se o sistema depende de hibernação, manter mecanismo persistente de swap/resume separado; ZRAM é volátil.

### 7.3. Empacotamento e boot de retorno

Seguir o ArchWiki de construção de kernels, alterando `pkgbase`, instalando kernel e headers próprios e configurando uma entrada independente no bootloader [D06]. Não declarar o kernel experimental como provedor binário indistinto de `linux`/`linux-headers`. Conferir módulos externos, initramfs, LUKS, Btrfs, Secure Boot, NVIDIA/DKMS e espaço no ESP antes da instalação. Um snapshot de arquivos não substitui mídia de resgate em caso de falha de boot.

### 7.4. Política de rollback

Condição de abortar teste: corrupção/checksum incorreto, kernel oops/panic, OOM descontrolado, travamento, latência impraticável ou falha de inicialização. Retornar ao kernel estável no menu de boot, preservar logs e capturas e reverter a configuração experimental. **Não executar `swapoff`, `zramctl --reset` ou comandos que formatem `/dev/zramN` em dispositivo com dados ativos sem avaliação explícita**.

---

## 8. RISCOS E AMEAÇAS À VALIDADE

| Risco | Efeito possível | Mitigação |
|---|---|---|
| Patches incompatíveis com kernel escolhido | Falha de build ou regressão | Congelar *commit*; analisar dependências; portar em commits próprios |
| Driver externo incompatível | Falha de boot ou de GPU | Headers correspondentes, DKMS, módulo assinado se necessário, kernel estável paralelo |
| ZRAM como swap ativo durante benchmark destrutivo | Perda de dados e falha do sistema | VM/dispositivo de teste separado; validar alvo antes de `fio` |
| Hibernação configurada sobre swap volátil | Retomada inviável | Preservar swap/resume persistente e testar |
| Zswap, MGLRU e caches diferindo entre builds | Confundimento | Congelar parâmetros e registrar configuração |
| Throttling térmico | Falso efeito de performance | Monitorar frequência/temperatura e balancear rodadas |
| Algoritmo/compressibilidade divergentes | Comparação inválida | Dataset de entrada e níveis fixos |
| Overhead de tracing | Latência artificial | Medir com e sem instrumentação |
| Teste sintético artificialmente favorável | Baixa validade externa | Incluir tarefas reais e apresentar separadamente |
| Número insuficiente de rodadas | Alta incerteza | Piloto, planejamento amostral e ICs |
| Ganho apenas em memória do contexto | Benefício imperceptível | Distinguir significado técnico de utilidade prática |

---

## 9. ENTREGÁVEIS E PORTÕES DE DECISÃO

**E0 — Inventário validado:** dados de hardware/software, estado ZRAM/Zswap, riscos de boot, espaço e mecanismo de recuperação.

**E1 — Dossiê de proveniência:** URLs das dez mensagens, Message-IDs, hashes/versões, compatibilidade com árvore de destino, licença e histórico da série.

**E2 — Kernel baseline reprodutível:** artefatos compilados do controle, configuração congelada, documentação do ambiente de compilação.

**E3 — Kernel experimental reprodutível:** pacotes e instruções de build; execução dos testes básicos de integridade e regressão.

**E4 — Suite de benchmark:** cenários de `fio`, pressão de memória, recompressão e aplicações reais, com instrumentos e CSV/JSON versionados.

**E5 — Relatório comparativo:** distribuições, intervalos, perfis de CPU/lock, métricas de memória e análise de sensibilidade.

**E6 — Parecer técnico final:** aceitar para uso experimental, rejeitar por regressão/nulidade ou aguardar integração/amadurecimento *upstream*. Incluir rollback e política de atualizações.

**Portões obrigatórios:** nenhum kernel será instalado na máquina principal antes de E0–E3, e nenhum ganho será divulgado como conclusão do projeto antes de E4–E5.

---

## 10. RESULTADOS ESPERADOS E LIMITES DE INTERPRETAÇÃO

O resultado tecnicamente mais plausível é **redução da latência de leitura sob concorrência R/W com diferença de prioridade**, conforme o mecanismo do patch 9/10. A redução de memória alocada para compressão secundária é também diretamente plausível, mas será relevante principalmente quando houver recompressão configurada e backends com contextos custosos [P02, P03].

São resultados igualmente válidos: ganho apenas em benchmarks adversariais; economia de contexto pequena perante RAM total; neutralidade em desktop/LLM; ou regressões em algoritmos/cargas específicas. Nenhum desses achados invalida automaticamente o estudo. A contribuição será identificar **onde, por quê e sob quais condições** o rework compensa.

O projeto **não aumenta memória física, VRAM ou largura de banda**. O benefício de ZRAM na capacidade efetiva depende da compressibilidade dos dados e do custo de acessá-los. A promessa comercial de “dobrar a RAM” é inadequada como resultado genérico.

### Potencial científico

Um relatório técnico reproduzível tem valor em si. Para publicação acadêmica, um diferencial plausível seria um estudo causal de ablação 0–8/0–9/0–10, demonstração de inversão de prioridade com tracing, avaliação estatística robusta e cobertura representativa de sistemas desktop/LLM. A novidade estaria **na caracterização e evidência independente**, não na reivindicação de autoria dos patches originais.

---

## 11. FONTES E REFERÊNCIAS COM LINKS VERIFICADOS

### 11.1. Fonte primária do rework e materiais do kernel

- **[P01]** SENOZHATSKY, Sergey. **[PATCH 00/10] zram: redesign zcomp and rework backends**. *Linux Kernel Mailing List*, 5 out. 2026. Fonte primária da série e descrição dos dez patches. https://lkml.iu.edu/2610.0/08424.html
- **[P02]** SENOZHATSKY, Sergey. **[PATCH 09/10] zram: split zcomp into separate R/W streams**. *LKML*, 5 out. 2026. Mecanismo de inversão de prioridade e resultados `fio` reportados pelo autor. https://lkml.iu.edu/2610.0/08440.html
- **[P03]** SENOZHATSKY, Sergey. **[PATCH 10/10] zram: use a singleton compression context for recompression**. *LKML*, 5 out. 2026. Estimativas de economia por backend, arquitetura de recompressão. https://lkml.iu.edu/2610.0/08438.html
- **[D01]** THE LINUX KERNEL. **zram: Compressed RAM-based block devices**. Documentação oficial; atributos, `mm_stat`, recompressão e writeback. https://kernel.org/doc/html/next/admin-guide/blockdev/zram.html
- **[D02]** THE LINUX KERNEL. **zswap**. Documentação oficial da cache comprimida de swap. https://www.kernel.org/doc/html/latest/admin-guide/mm/zswap.html
- **[D03]** THE LINUX KERNEL. **PSI — Pressure Stall Information**. Documentação de contenda de CPU/memória/I/O. https://cdn.kernel.org/doc/html/latest/accounting/psi.html
- **[D04]** THE LINUX KERNEL. **Multi-Gen LRU**. Documentação do gerenciador de recuperação de páginas. https://kernel.org/doc/html/v6.10/mm/multigen_lru.html
- **[D05]** SYSTEMD. **zram-generator.conf(5)**. Configuração de ZRAM no systemd. https://github.com/systemd/zram-generator/blob/main/man/zram-generator.conf.md
- **[D06]** ARCHWIKI. **Kernel/Arch build system**. Compilação e empacotamento de kernel customizado para Arch Linux. https://wiki.archlinux.org/title/Kernel/Arch_build_system
- **[D07]** LINUX PERF. **perf-lock(1)**. Documentação de análise de contenção de locks. https://man7.org/linux/man-pages/man1/perf-lock.1.html
- **[D08]** LINUX KSELFTEST. **tools/testing/selftests/zram**. Testes funcionais oficiais e documentação. https://kernel.googlesource.com/pub/scm/linux/kernel/git/shuah/linux-kselftest/+/master/tools/testing/selftests/zram/
- **[D09]** ARCHWIKI. **zram**. Integração na distribuição e configuração. https://wiki.archlinux.org/title/zram
- **[K01]** ZHAO, Yu et al. **[PATCH v8 00/14] Multi-Gen LRU Framework**. LKML, 2022. Contexto técnico de avaliação de recuperação de páginas. https://lists.openwall.net/linux-kernel/2022/03/09/72

### 11.2. Artigos científicos e trabalhos acadêmicos

- **[A01]** DOUGLIS, Fred. **The Compression Cache: Using On-line Compression to Extend Physical Memory**. *USENIX Winter 1993 Conference*, 1993. Trabalho clássico de memória comprimida. https://www.usenix.org/conference/usenix-winter-1993-conference/compression-cache-using-line-compression-extend-physical
- **[A02]** WILSON, Paul R.; KAPLAN, Scott F.; SMARAGDAKIS, Yannis. **The Case for Compressed Caching in Virtual Memory Systems**. *USENIX Annual Technical Conference*, 1999, p. 101–116. https://www.usenix.org/conference/1999-usenix-annual-technical-conference/case-compressed-caching-virtual-memory-systems
- **[A03]** LIANG, Yu et al. **Ariadne: A Hotness-Aware and Size-Adaptive Compressed Swap Technique for Fast Application Relaunch and Reduced CPU Usage on Mobile Devices**. *IEEE HPCA*, 2025, p. 1588–1602. DOI: https://doi.org/10.1109/HPCA61900.2025.00118 ; versão aberta: https://arxiv.org/abs/2502.12826
- **[A04]** LI, Changlong et al. **Archer: Adaptive Memory Compression with Page-Association-Rule Awareness for High-Speed Response of Mobile Devices**. *USENIX FAST*, 2025, p. 497–511. https://www.usenix.org/conference/fast25/presentation/li
- **[A05]** SON, Sam et al. **ASAP: Fast Mobile Application Switch via Adaptive Prepaging**. *USENIX ATC*, 2021. https://www.usenix.org/conference/atc21/presentation/son
- **[A06]** WANG, Yong-Xuan; TSAI, Chung-Hsuan; CHANG, Li-Pin. **Killing Processes or Killing Flash? Escaping from the Dilemma Using Lightweight, Compression-Aware Swap for Mobile Devices**. *ACM Transactions on Embedded Computing Systems*, v. 20, n. 5s, art. 90, 2021. DOI: https://doi.org/10.1145/3477021
- **[A07]** JI, Houxiang et al. **STYX: Exploiting SmartNIC Capability to Reduce Datacenter Memory Tax**. *USENIX ATC*, 2023, p. 619–633. https://www.usenix.org/conference/atc23/presentation/ji
- **[A08]** XIA, Qirong; JI, Houxiang; ZHOU, Yang; KIM, Nam Sung. **Hardware-Accelerated Kernel-Space Memory Compression Using Intel QAT**. *IEEE Computer Architecture Letters*, v. 24, n. 1, 2025, p. 57–60. DOI https://doi.org/10.1109/LCA.2025.3534831
- **[A09]** KARANDIKAR, Sagar et al. **CDPU: Co-designing Compression and Decompression Processing Units for Hyperscale Systems**. *ISCA*, 2023. Página dos autores: https://skanev.org/papers/isca23cdpu.html
- **[A10]** HUANG, Jian; QURESHI, Moinuddin K.; SCHWAN, Karsten. **An Evolutionary Study of Linux Memory Management for Fun and Profit**. *USENIX ATC*, 2016, p. 465–478. https://www.usenix.org/conference/atc16/technical-sessions/presentation/huang
- **[A11]** CURTSINGER, Charlie; BERGER, Emery D. **STABILIZER: Statistically Sound Performance Evaluation**. *ASPLOS*, 2013, p. 219–228. DOI: https://doi.org/10.1145/2451116.2451141 ; manuscrito dos autores: https://people.cs.umass.edu/~emery/pubs/stabilizer-asplos13-draft.pdf
- **[A12]** DEAN, Jeffrey; BARROSO, Luiz André. **The Tail at Scale**. *Communications of the ACM*, v. 56, 2013, p. 74–80. https://research.google/pubs/the-tail-at-scale/ ; DOI: https://doi.org/10.1145/2408776.2408794
- **[A13]** WEINER, Johannes et al. **TMO: Transparent Memory Offloading in Datacenters**. *ASPLOS*, 2022, p. 609–621. DOI: https://doi.org/10.1145/3503222.3507731 ; texto aberto: https://www.cs.cmu.edu/~dskarlat/publications/tmo_asplos22.pdf

### 11.3. Fronteiras tecnológicas e propostas correlatas — não são provas do rework

- **[F01]** PRICE, Gregory. **[RFC PATCH v4 23/27] mm/cram: add compressed ram memory management subsystem**. LKML, fev. 2026. Proposta distinta para memória comprimida. https://lists.openwall.net/linux-kernel/2026/02/22/71
- **[F02]** PRICE, Gregory et al. **Discussão sobre `N_MEMORY_PRIVATE` e CRAM**. LKML, set. 2026. Indica evolução experimental e dependências. https://lkml.iu.edu/2609.0/09219.html
- **[F03]** LIN, Jihan. **[PATCH RFC v2 3/5] zram: Introduce zcomp-managed streams**. Discussão sobre abstrações alternativas de *streams* de compressão, mar. 2026. https://lists.openwall.net/linux-kernel/2026/03/09/1009
- **[F04]** SUA INTERNET. **Linux ZRAM recebe grande rework para economizar memória e aumentar performance do sistema**. 6 out. 2026. Fonte jornalística que motivou o estudo; caráter secundário. https://suainternet.com/linux-zram-rework-economia-memoria-performance/

**Hierarquia de evidência:** [A*] são literatura de pesquisa (com contexto e limitações próprios); [D*] são documentação oficial; [P*] são patches originais e resultados preliminares de seus proponentes; [F*] são propostas correlatas ou cobertura secundária. Citação de um artigo não implica validação empírica do rework de outubro de 2026.

---

## 12. PENDÊNCIAS ANTES DA EXECUÇÃO

- [ ] Receber inventário da máquina e verificar qual Arch Linux/bootloader está em uso.
- [ ] Verificar estado atual da série na árvore *upstream* e se já existe v2/v3 ou revisão incorporada.
- [ ] Obter a série **completa** e confirmar proveniência e versão-base.
- [ ] Verificar se ZRAM está ativado, qual gerenciador o configura e se Zswap está ativo.
- [ ] Analisar hibernação, Secure Boot, criptografia, NVIDIA/DKMS e espaço do ESP.
- [ ] Definir ambiente primário de benchmark e limites de memória seguros.
- [ ] Congelar projeto experimental e parâmetros estatísticos antes de medir.
- [ ] Construir kernel controle e experimental da mesma árvore.
- [ ] Executar kselftests, integridade, regressão e benchmarks.
- [ ] Publicar relatório com ganhos, resultados nulos e limitações.

**Decisão inicial recomendada:** prosseguir com a fase de auditoria e reprodução em ambiente isolado. **Não** substituir o kernel de produção antes de comprovar compatibilidade, estabilidade e uma justificativa prática de uso.

---

*Documento preparado como projeto de pesquisa aplicada e engenharia, com referência temporal em 9/10/2026. Não contém resultados experimentais próprios nem afirma que a série de patches tenha sido incorporada ao kernel estável nessa data.*
