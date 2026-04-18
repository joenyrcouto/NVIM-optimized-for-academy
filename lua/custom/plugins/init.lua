-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

---@module 'lazy'
---@type LazySpec

-- Defina o caminho onde está o seu fork refatorado
local obsidian_fork_path = vim.fn.expand '~/Documents/git/obsidian.nvim'

-----------------------------------------------------------
-- INTEGRAÇÃO QUARTO / DATA SCIENCE
-----------------------------------------------------------
-- Isso carrega as pastas do repositório jmbuhr
require 'config.global'
require 'config.autocommands'
require 'config.keymap'
-- require 'config.lazy'
require 'config.redir'
require 'quarto_tmp'

-- Arruma para o ui obsidian nos .md e .qmd
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'quarto' },
  callback = function()
    -- 2: Esconde totalmente o texto oculto (links ficam limpos)
    -- 1: Substitui o texto oculto por um caractere (se definido)
    vim.opt_local.conceallevel = 2
  end,
})

-- Garante o uso do Treesitter para indentação e dobras
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'rmarkdown', 'julia', 'python', 'r' }, -- Adicionei as linguagens explicitamente
  callback = function()
    vim.treesitter.start()
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.wo.foldmethod = 'expr'
    -- Opcional: começa com todas as dobras abertas
    vim.wo.foldlevel = 99
  end,
})

-- Ativa o suporte de LSP dentro de blocos de código
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'quarto', 'markdown' },
  callback = function() require('otter').activate({ 'julia', 'python', 'r' }, true, true, nil) end,
})

-- Mapeamento global para Shift+Enter: envia célula ou linha, ou mostra aviso amigável
vim.keymap.set('n', '<S-CR>', function()
  local ft = vim.bo.filetype
  local supported = { quarto = true, markdown = true, rmarkdown = true, julia = true, python = true, r = true, sh = true }
  if supported[ft] then
    -- Tenta executar a célula atual (você pode adaptar para o seu runner preferido)
    local ok, runner = pcall(require, 'quarto.runner')

    if ok then
      runner.run_cell()
    else
      vim.cmd 'SlimeSendCurrentCell' -- fallback para vim-slime
    end
  else
    vim.notify('Shift+Enter: Nenhum REPL disponível para este tipo de arquivo (' .. ft .. ')', vim.log.levels.WARN)
  end
end, { desc = 'Run current cell or show warning' })

-- Opcional: também no modo inserção (se quiser)
vim.keymap.set('i', '<S-CR>', '<Esc><S-CR>', { desc = 'Run cell from insert mode' })

return {
  {
    'kdheepak/lazygit.nvim',
    cmd = 'LazyGit',
    keys = {
      { '<leader>gg', '<cmd>LazyGit<CR>', desc = 'Open LazyGit' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    config = function()
      local function get_working_dir()
        local bufpath = vim.api.nvim_buf_get_name(0)
        if bufpath ~= '' then
          return vim.fn.fnamemodify(bufpath, ':p:h')
        else
          return vim.fn.getcwd()
        end
      end

      -- Configura mapeamentos para o buffer do LazyGit quando ele abrir
      vim.api.nvim_create_autocmd('TermOpen', {
        pattern = '*lazygit*',
        callback = function(args)
          local bufnr = args.buf
          local opts = { buffer = bufnr, silent = true, nowait = true }

          -- q / Esc / Ctrl+q fecham a janela
          vim.keymap.set('n', 'q', '<cmd>close<CR>', opts)
          vim.keymap.set('n', '<Esc>', '<cmd>close<CR>', opts)
          vim.keymap.set('n', '<C-q>', '<cmd>close<CR>', opts)

          -- Navegação básica
          vim.keymap.set('n', 'j', 'j', opts)
          vim.keymap.set('n', 'k', 'k', opts)
          vim.keymap.set('n', 'gg', 'gg', opts)
          vim.keymap.set('n', 'G', 'G', opts)
          vim.keymap.set('n', '/', '/', opts)
          vim.keymap.set('n', 'n', 'n', opts)
          vim.keymap.set('n', 'N', 'N', opts)

          -- Enter e Espaço (enviam para o terminal)
          vim.keymap.set('n', '<CR>', 'i<CR>', opts)
          vim.keymap.set('n', '<Space>', 'i<Space>', opts)

          -- Teclas de ação do LazyGit (enviam para o terminal)
          local lazygit_keys = { 'a', 'c', 'd', 'p', 'r', 's', 't', 'v', 'x', 'z', 'A', 'C', 'D', 'P', 'R', 'S', 'T', 'V', 'X', 'Z' }
          for _, key in ipairs(lazygit_keys) do
            vim.keymap.set('n', key, 'i' .. key, opts)
          end
        end,
      })

      -- Sobrescreve o atalho <leader>gg para usar o diretório correto
      vim.keymap.set('n', '<leader>gg', function()
        local cwd = get_working_dir()
        vim.cmd('lcd ' .. vim.fn.fnameescape(cwd))
        require('lazygit').lazygit()
      end, { desc = 'Open LazyGit' })
    end,
  },

  -- 1. plugin principal: gestão do vault e notas
  {
    'joenyrcouto/obsidian.nvim',
    version = '*',
    -- Ajuste no evento para carregar apenas quando abrir arquivos no vault
    lazy = false,
    event = {
      'BufReadPre ' .. vim.fn.expand '~' .. '/documents/brain/**',
      'BufNewFile ' .. vim.fn.expand '~' .. '/documents/brain/**',
    },
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      workspaces = {
        { name = 'brain', path = '~/Documents/brain' },
      },

      -- CONFIGURAÇÃO DE EXTENSÕES (Obrigatório para o novo motor)
      -- allowed_extensions: o que o plugin consegue "enxergar" e pesquisar
      -- writable_extensions: o que o plugin tem permissão para criar/editar
      allowed_extensions = { '.md', '.qmd', '.base', '.js' },
      writable_extensions = { '.md', '.qmd', '.base' },

      templates = {
        folder = '99-brutos/templates', -- 'subdir' foi normalizado para 'folder' no upstream
        date_format = '%Y-%m-%d',
        time_format = '%H:%M',
        -- NOVO: Mapeamento de pastas para templates automáticos
        -- A chave é a pasta (relativa ao vault), o valor é o nome do arquivo de template
        template_mappings = {
          ['00-rápidas'] = '00-rápidas-tlp.md',
          ['01-notelm'] = '01-notelm-tlp.md',
          ['02-zettel'] = '02-zettel-tlp.md',
          ['03-moc'] = '03-moc-tlp.md',
          ['99-brutos/biblioteca'] = '99-acervo-tlp.md',
          ['99-brutos/tracking'] = '99-tracking-tlp.md',
          ['99-brutos/exercícios'] = '99-exercícios-tlp.md',
        },
        -- NOVO: Ativa a tradução de sintaxe do Templater (<% tp.date.now() %>)
        templater_compat = true,
      },

      daily_notes = {
        folder = '99-brutos/diárias',
        date_format = '%Y-%m-%d',
        template = '99-tracking-tlp.md',
      },

      completion = {
        nvim_cmp = true, -- Mude para true se usar nvim-cmp para autocompletar links
        min_chars = 2,
      },

      attachments = {
        folder = '99-brutos/anexos', -- Recomendo uma subpasta para não poluir a raiz de brutos
        img_folder = '99-brutos/anexos',
        -- NOVO: Formata o link como ![[imagem.png]] (Padrão Obsidian)
        img_text_func = function(client, path)
          local name = vim.fs.basename(tostring(path))
          return string.format('![[%s]]', name)
        end,
      },

      ui = { enable = true },
      -- Garante que comandos antigos não poluam o ambiente
      legacy_commands = false,
    },
    config = function(_, opts) require('obsidian').setup(opts) end,
  },

  -- 2. Plugin Bridge: Sincronização de Navegação (Neovim -> Obsidian)
  {
    'oflisback/obsidian-bridge.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    event = { 'BufReadPre *.md', 'BufNewFile *.md' },
    opts = {
      obsidian_server_address = 'http://localhost:27123', -- Verifique se o HTTP (sem SSL) está ativo no Obsidian
      scroll_sync = false, -- Deixe false a menos que use a versão modificada do REST API
      warnings = true,
      extensions = { '.md', '.qmd', '.base' },
      img_folder = '99-brutos/anexos',
    },
    config = function(_, opts)
      -- Só ativa o bridge se o arquivo atual estiver dentro do seu Vault
      local path = vim.fn.expand '%:p'
      if path:find '~/Documents/brain' then require('obsidian-bridge').setup(opts) end
    end,
  },

  {
    'olimorris/codecompanion.nvim',
    lazy = false,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      require('codecompanion').setup {
        adapters = {
          http = {
            lmstudio = function()
              return require('codecompanion.adapters').extend('openai_compatible', {
                name = 'lmstudio',
                env = {
                  url = 'http://localhost:1234',
                  api_key = 'sk-lm-Fz8AlBMF:ZuAbScWaKeURH6Wf67qf',
                },
                schema = {
                  model = {
                    default = 'google/gemma-4-e2b',
                  },
                },
              })
            end,
          },
        },
        strategies = {
          chat = {
            adapter = 'lmstudio',
          },
          inline = {
            adapter = 'lmstudio',
          },
          agent = {
            adapter = 'lmstudio',
          },
        },
      }
    end,
  },
}
