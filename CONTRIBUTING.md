# Guia de Contribuição (Contributing)

Agradecemos o interesse em contribuir com o **Zero RAM**!

O projeto é voltado para engenharia de kernel Linux, sistemas operacionais e otimizações de memória compactada de alto desempenho.

---

## 🛠️ Como Contribuir

1. **Relato de Bugs & Sugestões:**
   * Abra uma [Issue](https://github.com/fabio-linhares/zero-ram-p/issues) detalhando sua distribuição, versão do kernel (`uname -r`), modelo de CPU e sintomas observados.
   * Se possível, anexe a saída de `./scripts/profile-machine.sh` e `dmesg | grep -i zram`.

2. **Submissão de Código (Pull Requests):**
   * Crie uma branch para sua funcionalidade ou correção:
     ```bash
     git checkout -b feature/sua-melhoria
     ```
   * Siga as convenções de código do Kernel Linux (`scripts/checkpatch.pl` quando aplicável ao C).
   * Mantenha scripts Bash compatíveis com `set -euo pipefail` e sem caminhos fixos dependentes do seu usuário.
   * Valide que o teste de compilação fora da árvore passa localmente:
     ```bash
     ./scripts/build-module.sh
     ```

3. **Verificação de Segurança & Privacidade:**
   * **NUNCA** inclua em commits dados sensíveis, tokens de autenticação, UUIDs reais de partições de hardware ou caminhos privados locais. Utilize identificadores genéricos ou variáveis de ambiente.

4. **Licenciamento das Contribuições:**
   * Ao submeter código a este repositório, você concorda que suas contribuições para o módulo de kernel serão licenciadas sob **Dual BSD/GPL-2.0** e suas contribuições para scripts e automações sob **GPL-2.0**.
