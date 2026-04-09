# Quarto.nvim Otimizado – Fluxo de Estudo Rápido (Beta!!)

Plugin para Neovim que integra o **Quarto**
de forma otimizada para escrita e execução
de código durante os estudos. Utiliza
diretório **shadow em RAM** (`/tmp`) para
acelerar compilações e previews, com
controle fino sobre ativos, extensões e
modos de compilação.

> **Nota:** Este plugin está em fase beta. Os autocomandos de sincronização com o Quarto e a estabilidade a longo prazo ainda precisam de mais testes e validação.

## ✨ Funcionalidades Principais

- ⚡ **Preview em RAM** – Renderização instantânea sem tocar no disco físico (exceto quando solicitado).
- 🔁 **Atualização inteligente** – Modo rápido atualiza automaticamente ao sair do modo de inserção; modo compilado apenas sob demanda (`:Quarto -r`).
- 🧩 **Execução de blocos** – Envia código para REPL (via `vim-slime`) ou copia para clipboard, com escolha interativa quando ambos estão disponíveis.
- 📦 **Gerenciamento de ativos** – Sincronização seletiva de pastas `Gerais/` e `Extens/` para o ambiente de compilação.
- 🗂️ **Templates** – Aplicação ou cópia de templates a partir de `~/Documents/Quarto/temp/`.
- 🎛️ **Configurações por buffer** – Salvas no frontmatter YAML de cada arquivo (ID persistente, modos, lista de ativos).
- 🖥️ **Integração com which-key** – Atalhos mnemônicos (`<leader>q` + ...) para todas as ações.
- ⌨️ **Shift+Enter inteligente** – Executa a célula atual em arquivos Quarto/Julia/Python/R; em outros tipos, exibe uma notificação amigável.
- 🧹 **LSP otimizado** – Servidores como `julials` só iniciam em arquivos relevantes (`.qmd`, `.jl`, `.md`), economizando recursos.

---

## 📁 Estrutura de Diretórios Esperada

```
~/Documents/Quarto/
├── Comp/           # Destino dos renders quando `comp_nativa = false`
├── Gerais/         # Arquivos/pastas copiados para raiz da compilação
├── Extens/         # Extensões Quarto (copiadas para _extensions/)
└── temp/           # Templates (.qmd, .md, etc.)
```

**Shadow (RAM):** `/tmp/nvim_quarto_shadow/<id>/` – cada buffer recebe um ID único (hash do caminho + timestamp) persistido no YAML.

---

## ⌨️ Comandos e Atalhos

### Comando principal: `:Quarto [flag] [opções]`

| Flag / Exemplo                     | Descrição                                                                                |
|------------------------------------|------------------------------------------------------------------------------------------|
| `:Quarto -h`                       | Exibe menu de ajuda (atalho `<leader>qh`)                                                 |
| `:Quarto -p [html\|pdf]`           | Preview **rápido** (código não executado). Atualiza ao sair do Insert.                    |
| `:Quarto -p -c [html\|pdf]`        | Preview **compilado** (executa blocos). Atualiza somente com `:Quarto -r`.                |
| `:Quarto -p -s ...`                | Força salvamento do resultado mesmo em caso de erro (experimental).                       |
| `:Quarto -r`                       | Atualiza manualmente o preview ativo.                                                     |
| `:Quarto -k`                       | Para o servidor de preview.                                                               |
| `:Quarto -c [pdf\|html]`           | Renderização final. Salva conforme configuração de `comp_nativa`.                         |
| `:Quarto -c -s ...`                | Força salvamento mesmo com erro de compilação.                                            |
| `:Quarto -b`                       | Lista blocos de código; pergunta se quer **enviar ao REPL** ou **copiar para clipboard** (se `vim-slime` disponível). |
| `:Quarto -l`                       | Abre visualização de logs (preview ou render).                                            |
| `:Quarto -m`                       | Menu de configurações (modos, ativos, extensões, templates).                              |

### Atalhos via `which-key` (prefixo `<leader>q` e `<leader>r`)

| Atalho        | Ação                                                    |
|---------------|---------------------------------------------------------|
| **Quarto (`<leader>q`)** |                                                         |
| `<leader>qh`  | Ajuda (`:Quarto -h`)                                    |
| `<leader>qp`  | Menu de Preview                                         |
| `<leader>qpf` | Preview rápido HTML                                     |
| `<leader>qpc` | Preview compilado PDF                                   |
| `<leader>qph` | Preview compilado HTML                                  |
| `<leader>qr`  | Atualizar preview                                       |
| `<leader>qk`  | Parar preview                                           |
| `<leader>qc`  | Menu de Renderização                                    |
| `<leader>qcp` | Renderizar PDF                                          |
| `<leader>qch` | Renderizar HTML                                         |
| `<leader>qb`  | Executar bloco de código (menu interativo)              |
| `<leader>qm`  | Abrir configurações                                     |
| `<leader>ql`  | Ver logs                                                |
| **Runner (`<leader>r`)** |                                                         |
| `<leader>rc`  | Executar célula atual                                   |
| `<leader>ra`  | Executar célula atual e acima                           |
| `<leader>rA`  | Executar todas as células (mesma linguagem)             |
| `<leader>rl`  | Executar linha atual                                    |
| `<leader>r`   | Executar seleção visual (modo visual)                   |
| `<leader>RA`  | Executar todas as células (todas as linguagens)         |

### Atalhos Globais Adicionais

| Atalho        | Ação                                                                                      |
|---------------|-------------------------------------------------------------------------------------------|
| `Shift+Enter` | Em arquivos Quarto/Julia/Python/R/bash: executa a célula atual. Caso contrário, exibe uma mensagem informativa. |

---

## 🧠 Mecanismo de Shadow e Configuração YAML

- Cada buffer `.qmd`/`.md` recebe um **ID único** (`quarto_id`) gerado na primeira operação de preview/render e salvo no frontmatter YAML.
- O diretório shadow é `/tmp/nvim_quarto_shadow/<id>/`. Nele são mantidos:
  - Cópia atualizada do conteúdo do buffer (sincronizada a cada `InsertLeave` e `BufWritePost`).
  - Ativos copiados conforme configuração (gerais e extensões).
- A **renderização** (`:Quarto -c`) pode ocorrer:
  - No **shadow** (padrão) – mais rápida, ideal para testes.
  - No **diretório físico original** se `quarto_usar_local_fisico = true` (útil para builds finais com estrutura estável).
- Após renderização bem‑sucedida, o arquivo de saída é copiado para:
  - `~/Documents/Quarto/Comp/<id>/` se `comp_nativa = false`
  - Pasta original do arquivo se `comp_nativa = true`

---

## ⚙️ Menu de Configurações (`:Quarto -m`)

| Opção | Descrição                                                                 |
|-------|----------------------------------------------------------------------------|
| **1. Compilação Nativa** | Se `true`, salva resultado da renderização na pasta original do arquivo.  |
| **2. Modo Escrita**      | (Reservado para uso futuro – atualmente não afeta comportamento).         |
| **3. Usar Local Físico** | Se `true`, renderização (`-c`) ocorre no diretório do arquivo (sem shadow).|
| **4. Ignorar Ativos**    | Se `true`, não copia gerais nem extensões durante compilação.              |
| **5. Ativos Gerais**     | Seleciona quais itens de `~/Documents/Quarto/Gerais/` serão copiados.      |
| **6. Extensões**         | Seleciona quais extensões (pastas em `~/Documents/Quarto/Extens/`) serão copiadas para `_extensions/`. |
| **7. Templates**         | Lista arquivos de `~/Documents/Quarto/temp/` para **Usar** (substitui buffer) ou **Copiar** (clipboard). |

> Todas as alterações são salvas imediatamente no YAML do buffer.

---

## ✅ Checklist de Funcionalidades (para validação)

Marque conforme testar:

- [ ] **Shadow em RAM**: Preview e render usam `/tmp`, não disco (exceto se `usar_local_fisico` ativo).
- [ ] **Atualização automática (modo rápido)**: Ao sair do Insert, preview HTML é atualizado sem intervenção.
- [ ] **Preview compilado**: Com `-c`, executa código e só atualiza com `:Quarto -r`.
- [ ] **Comando `:Quarto -r`**: Força atualização do preview ativo.
- [ ] **Parada do servidor**: `:Quarto -k` mata o processo do Quarto.
- [ ] **Renderização final (`-c`)**: Gera PDF/HTML e abre automaticamente.
- [ ] **Forçar salvamento (`-s`)**: Mesmo com erro, o arquivo de saída é mantido/copiado.
- [ ] **Execução de blocos (`-b`)**: Lista blocos, oferece escolha entre enviar ao REPL (se slime disponível) ou copiar.
- [ ] **Visualização de logs (`-l`)**: Abre split com log de preview ou render.
- [ ] **Configurações (`-m`)**: Menu interativo altera toggles e ativos; mudanças persistem no YAML.
- [ ] **Persistência do ID**: `quarto_id` no YAML mantém a mesma pasta shadow entre sessões.
- [ ] **Sincronização de Gerais**: Pastas/arquivos selecionados são copiados para raiz da compilação.
- [ ] **Sincronização de Extensões**: Pastas selecionadas são copiadas para `_extensions/`.
- [ ] **Templates**: Substituir buffer ou copiar conteúdo de template.
- [ ] **Atalhos which-key**: Todos os mapeamentos `<leader>q...` e `<leader>r...` funcionam.
- [ ] **Ignorar ativos**: Com toggle ativo, nenhum ativo extra é copiado.
- [ ] **Shift+Enter**: Em arquivos suportados, executa a célula; fora deles, exibe notificação amigável.
- [ ] **LSP condicional**: `julials` e outros servidores só iniciam nos filetypes configurados.

---

## 🔧 Dependências Recomendadas

- [Quarto CLI](https://quarto.org/docs/get-started/)
- [vim-slime](https://github.com/jpalardy/vim-slime) (para `:Quarto -b`)
- [which-key.nvim](https://github.com/folke/which-key.nvim) (para atalhos)
- [otter.nvim](https://github.com/jmbuhr/otter.nvim) (já incluso como dependência do quarto-nvim)

---

## 🚀 Instalação

Antes vale mencionar que o setup foi feito para sistema Linux, onde os discos são montados em árvore e temos o diretório `/tmp` que é um tmpfs (adeque a configuração para funcionar no seu sistema operacional).

Faça um fork do repositório e clone no seu `~/.config/nvim/`. Ou simplesmente clone direto.

Certifique-se de que os diretórios `~/Documents/Quarto/{Comp,Gerais,Extens,temp}` existam (ou serão criados automaticamente).

---

## 🔗 Links que auxiliaram na construção do dotfile

- [Neovim](https://github.com/neovim) (onde configurei o neovim limpo do zero e implementei lsp)
- [Aman9das/quarto-nvim-dotfiles](https://github.com/Aman9das/quarto-nvim-dotfiles) (exportei e atualizei algumas funções para a nova sintaxe do neovim)
- [quarto-dev/quarto-nvim](https://github.com/quarto-dev/quarto-nvim) (importante para entender funcionamento do Quarto, dependências etc)
- [jmbuhr/otter.nvim](https://github.com/jmbuhr/otter.nvim) (parte responsável por modular o lsp junto com o autocomplete, de escolha, nos blocos)
- Além de outras pesquisas...

---

**Divirta-se estudando e produzindo com velocidade!** 🚀
