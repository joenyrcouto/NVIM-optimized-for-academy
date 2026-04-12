# ⚡ Quarto Shadow System – Preview em RAM

O sistema de **Shadow** acelera drasticamente os previews do Quarto ao trabalhar exclusivamente em memória RAM (`/tmp`), evitando operações de disco e mantendo seus diretórios de projeto limpos.

## 🧠 Como funciona

1. **ID único**: Na primeira execução de `:Quarto -p` ou `-c`, um ID de 8 caracteres é gerado e salvo no frontmatter YAML do arquivo (`quarto_id`).
2. **Shadow directory**: Uma pasta `/tmp/nvim_quarto_shadow/<id>/` é criada e mantida durante a sessão.
3. **Sincronização**: O conteúdo do buffer (mesmo não salvo) é copiado para o shadow a cada `InsertLeave` e `BufWritePost`.
4. **Compilação**: O Quarto é executado **dentro do shadow**, usando os ativos copiados conforme configuração.
5. **Resultado**: O navegador abre o preview; ao renderizar (`-c`), o arquivo final é copiado para `~/Documents/Quarto/Comp/<id>/` (ou para a pasta original, se `comp_nativa = true`).

## 🎮 Comandos principais

| Comando               | Atalho     | Descrição                                                                 |
|-----------------------|------------|----------------------------------------------------------------------------|
| `:Quarto -p [fmt]`    | `<leader>tpf` | Preview rápido (código **não executado**). Atualiza ao sair do Insert.    |
| `:Quarto -p -c [fmt]` | `<leader>tpc` | Preview compilado (executa blocos). Atualiza **somente** com `:Quarto -r`.|
| `:Quarto -r`          | `<leader>tr`  | Atualiza manualmente o preview ativo.                                      |
| `:Quarto -k`          | `<leader>tk`  | Para o servidor de preview.                                                |
| `:Quarto -c [fmt]`    | `<leader>tcp` | Renderização final. Gera arquivo e abre.                                   |
| `:Quarto -m`          | `<leader>tm`  | Menu de configurações (ativos, modos, templates).                          |

## ⚙️ Menu de Configurações (`:Quarto -m`)

| Opção                  | Efeito                                                                 |
|------------------------|-------------------------------------------------------------------------|
| **Compilação Nativa**  | Salva resultado na pasta original do arquivo.                           |
| **Modo Escrita**       | Desliga execução de código (preview instantâneo).                       |
| **Usar Local Físico**  | Renderiza no diretório do arquivo (sem shadow).                         |
| **Ignorar Ativos**     | Não copia gerais nem extensões.                                         |
| **Ativos Gerais**      | Seleciona arquivos/pastas de `~/Documents/Quarto/Gerais/`.              |
| **Extensões**          | Seleciona extensões para `_extensions/`.                                |
| **Templates**          | Aplica ou copia templates de `~/Documents/Quarto/Temp/`.                |

## 📂 Estrutura de diretórios

```
~/Documents/Quarto/
├── Gerais/         # Copiados para a raiz da compilação
├── Extens/         # Copiados para _extensions/
├── Temp/           # Templates
└── Comp/           # Destino final dos renders (quando comp_nativa = false)
```

## 🔍 Logs e diagnóstico

- `:Quarto -l` → escolhe entre log de **Preview** ou **Render**.
- O arquivo de log fica no diretório shadow: `/tmp/nvim_quarto_shadow/<id>/preview.log` ou `render.log`.

## 💡 Dicas

- Para edições rápidas, use `<leader>tpf` – o preview é quase instantâneo.
- Se precisar testar código, use `<leader>tb` para enviar blocos ao REPL (via `vim-slime`) sem recompilar tudo.
- O ID no YAML garante que você sempre use o mesmo shadow, mesmo após fechar e reabrir o Neovim.

---

**Com o Shadow System, você edita e visualiza seus documentos científicos com latência mínima e zero poluição nos diretórios de trabalho.**
