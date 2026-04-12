# 🐙 Git‑Bug – Issues Offline no Neovim

O **git‑bug** é um rastreador de bugs/questões que armazena tudo no próprio repositório Git. Com os atalhos configurados, você pode criar e gerenciar issues **completamente offline** e sincronizar com o GitHub quando tiver internet.

## 🚀 Primeiros passos

1. **Inicialize o git‑bug** no repositório atual:
   - `<leader>gi` → `git bug init`

2. **Adote uma identidade** (necessário para assinar issues):
   - `<leader>gu` → `git bug user adopt`

3. (Online, uma vez) **Configure a bridge com o GitHub**:
   - `<leader>gb` → usa o token do `gh` para conectar ao repositório remoto.

## 📋 Atalhos principais

| Atalho      | Ação                                                                 |
|-------------|-----------------------------------------------------------------------|
| `<leader>ga`| **Nova issue**: abre janela flutuante para título e descrição.         |
| `<leader>gl`| **Interface TUI**: abre o terminal interativo do git‑bug (via Kitty float). |
| `<leader>gp`| **Push/Pull**: envia e recebe atualizações do GitHub.                  |
| `<leader>gf`| **Commit com referência**: cria um commit que menciona `Fixes <id>`.   |

## 🔄 Fluxo offline → online

1. **Offline**:
   - Crie issues com `<leader>ga` ou `<leader>gl`.
   - Adicione comentários, altere status, etc. (tudo fica armazenado no `.git`).
2. **Online**:
   - Execute `<leader>gp` para enviar tudo ao GitHub.
   - As issues aparecerão na interface web normalmente.

## 🖥️ Configuração do Kitty (para `<leader>gl`)

Adicione ao `~/.config/kitty/kitty.conf`:

```
allow_remote_control yes
listen_on unix:/tmp/kitty
```

## 🛠️ Comandos manuais úteis

| Comando                         | Descrição                               |
|---------------------------------|-----------------------------------------|
| `git bug bug new -t "Título"`   | Criar issue via linha de comando        |
| `git bug termui`                | Abrir TUI manualmente                   |
| `git bug bridge new`            | Configurar bridge interativamente       |
| `git bug pull` / `push`         | Sincronizar                             |

## 📌 Observações

- O git‑bug funciona em **qualquer repositório Git**, independentemente de estar conectado a um remote.
- As issues são armazenadas como objetos Git na branch `bugs` (oculta).
- Para colaboração, todos os envolvidos devem ter o git‑bug instalado e a bridge configurada.

**Documentação oficial:** [github.com/MichaelMure/git-bug](https://github.com/MichaelMure/git-bug)
