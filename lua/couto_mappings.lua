local map = vim.keymap.set

-- [ NAVEGAÇÃO ENTRE JANELAS ]
map('n', '<C-h>', '<C-w>h', { desc = 'Janela à esquerda' })
map('n', '<C-j>', '<C-w>j', { desc = 'Janela abaixo' })
map('n', '<C-k>', '<C-w>k', { desc = 'Janela acima' })
map('n', '<C-l>', '<C-w>l', { desc = 'Janela à direita' })

-- [ RENOMEAR O ARQUIVO ATUAL NO DISCO ]
map('n', '<leader>rn', function()
  local old_name = vim.api.nvim_buf_get_name(0)
  if old_name == '' then return print 'Erro: Arquivo não salvo no disco' end

  local new_name = vim.fn.input('Novo nome do arquivo: ', old_name, 'file')

  if new_name ~= '' and new_name ~= old_name then
    local uv = vim.uv or vim.loop
    local ok, err = uv.fs_rename(old_name, new_name)

    if ok then
      vim.cmd('edit ' .. vim.fn.fnameescape(new_name))
      vim.cmd('bwipeout ' .. vim.fn.fnameescape(old_name))
      print('\nArquivo renomeado para: ' .. new_name)
    else
      print('\nErro ao renomear: ' .. err)
    end
  end
end, { desc = 'Renomear arquivo físico' })

-- [ NAVEGAÇÃO DE BUSCA E LIMPEZA MANUAL ]
local function toggle_search_clean()
  if vim.v.hlsearch == 1 then
    vim.cmd 'nohlsearch'
    vim.api.nvim_command "echo ''"
    vim.cmd 'redraw'
  else
    local last_search = vim.fn.getreg '/'
    if last_search ~= '' then
      vim.opt.hlsearch = true
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('nN', true, false, true), 'n', true)
    end
  end
end

-- Mapeamento do '?' (Substitui a busca reversa nativa)
map('n', '?', toggle_search_clean, {
  desc = 'Toggle Search e Limpar Terminal',
  silent = true,
  nowait = true,
})

-- [ SALVAMENTO E FECHAMENTO ]
map('n', '<leader>w', '<cmd>w<cr>', { desc = 'salvar arquivo' })
map('n', '<leader>q', '<cmd>confirm q<cr>', { desc = 'fechar janela atual' })
map('n', '<leader><esc>', '<cmd>qa!<cr>', { desc = 'sair do neovim forçadamente' })

-- [ NAVEGAÇÃO ENTRE ABAS (BUFFERS - NVCHAD) ]
map('n', '<Tab>', function() require('nvchad.tabufline').next() end, { desc = 'Próxima Aba' })
map('n', '<S-Tab>', function() require('nvchad.tabufline').prev() end, { desc = 'Aba Anterior' })
map('n', '<leader>x', function() require('nvchad.tabufline').close_buffer() end, { desc = 'Fechar Aba' })

-- [ DIVISÃO DE TELA (SPLITS) ]
map('n', '<leader>v', '<cmd>vsp<cr>', { desc = 'Dividir Verticalmente' })
map('n', '<leader>h', '<cmd>sp<cr>', { desc = 'Dividir Horizontalmente' })

-- [ TERMINAIS NVCHAD ]
map({ 'n', 't' }, '<A-h>', function() require('nvchad.term').toggle { pos = 'sp', id = 'htoggle' } end)
map({ 'n', 't' }, '<A-i>', function() require('nvchad.term').toggle { pos = 'float', id = 'floatTerm' } end)

-------------------------------------------------------------------
-- [ CONFIGURAÇÕES ESPECÍFICAS DO OBSIDIAN ]
-------------------------------------------------------------------

-- Tecla ENTER: Seguir Link
map('n', '<CR>', function()
  local ok, obsidian = pcall(require, 'obsidian')
  if ok then
    local client = obsidian.get_client()
    if client and client:cursor_on_markdown_link() then
      vim.cmd 'ObsidianFollowLink'
      return ''
    end
  end
  return '<CR>'
end, { expr = true, desc = 'Obsidian: Seguir Link' })

-- Tecla Espaço + Shift + R: Renomear Inteligente
map('n', '<leader>R', function()
  if vim.bo.filetype == 'markdown' or vim.bo.filetype == 'quarto' then
    vim.cmd 'ObsidianRename'
  else
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<leader>rn', true, false, true), 'm', true)
  end
end, { desc = 'Renomear Inteligente' })

map('n', '<leader>oi', '<cmd>ObsidianPasteImg<CR>', { desc = 'Colar Imagem' })
map('n', '<leader>ob', '<cmd>ObsidianBacklinks<CR>', { desc = 'Ver Backlinks' })
