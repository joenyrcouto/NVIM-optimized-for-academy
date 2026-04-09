-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

---@module 'lazy'
---@type LazySpec

-----------------------------------------------------------
-- INTEGRAÇÃO QUARTO / DATA SCIENCE
-----------------------------------------------------------
-- Isso carrega as pastas do repositório jmbuhr
require 'config.global'
require 'config.autocommands'
require 'config.keymap'
-- require 'config.lazy'
require 'config.redir'
require 'quarto_autocmds'

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
  },
}
