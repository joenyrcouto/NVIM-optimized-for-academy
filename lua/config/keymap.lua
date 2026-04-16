-- required in which-key plugin spec in plugins/ui.lua as `require 'config.keymap'`
local wk = require 'which-key'
local ms = vim.lsp.protocol.Methods
local map = vim.keymap.set

P = vim.print

vim.g['quarto_is_r_mode'] = nil
vim.g['reticulate_running'] = false

local nmap = function(key, effect, desc) vim.keymap.set('n', key, effect, { silent = true, noremap = true, desc = desc }) end
local vmap = function(key, effect, desc) vim.keymap.set('v', key, effect, { silent = true, noremap = true, desc = desc }) end
local imap = function(key, effect, desc) vim.keymap.set('i', key, effect, { silent = true, noremap = true, desc = desc }) end
local cmap = function(key, effect, desc) vim.keymap.set('c', key, effect, { silent = true, noremap = true, desc = desc }) end

-- Apagar arquivo (dar um kill nele)
map('n', '<C-S-K>', function()
  local file = vim.fn.expand '%:p'
  vim.ui.select({ 'Sim', 'Não' }, {
    prompt = 'Excluir ' .. file .. '?',
  }, function(choice)
    if choice == 'Sim' then
      vim.fn.delete(file)
      vim.cmd 'bd!'
      vim.notify('Arquivo excluído.', vim.log.levels.INFO)
    end
  end)
end, { desc = 'Excluir arquivo atual' })

-- select last paste
nmap('gV', '`[v`]')

-- move in command line
cmap('<C-a>', '<Home>')

-- save with ctrl+s
imap('<C-s>', '<esc>:update<cr><esc>')
nmap('<C-s>', '<cmd>:update<cr><esc>')

-- Move between windows using <ctrl> direction
nmap('<C-j>', '<C-W>j')
nmap('<C-k>', '<C-W>k')
nmap('<C-h>', '<C-W>h')
nmap('<C-l>', '<C-W>l')

-- Resize window using <shift> arrow keys
nmap('<S-Up>', '<cmd>resize +2<CR>')
nmap('<S-Down>', '<cmd>resize -2<CR>')
nmap('<S-Left>', '<cmd>vertical resize -2<CR>')
nmap('<S-Right>', '<cmd>vertical resize +2<CR>')

-- Add undo break-points
imap(',', ',<c-g>u')
imap('.', '.<c-g>u')
imap(';', ';<c-g>u')

nmap('Q', '<Nop>')

--- Send code to terminal with vim-slime
--- If an R terminal has been opend, this is in r_mode
--- and will handle python code via reticulate when sent
--- from a python chunk.
--- TODO: incorpoarate this into quarto-nvim plugin
--- such that QuartoSend functions get the same capabilities
--- TODO: figure out bracketed paste for reticulate python repl.
local function send_cell()
  local has_molten, molten_status = pcall(require, 'molten.status')
  local molten_works = false
  local molten_active = ''
  if has_molten then
    molten_works, molten_active = pcall(molten_status.kernels)
  end
  if molten_works and molten_active ~= vim.NIL and molten_active ~= '' then molten_active = molten_status.initialized() end
  if molten_active ~= vim.NIL and molten_active ~= '' and molten_status.kernels() ~= 'Molten' then
    vim.cmd.QuartoSend()
    return
  end

  if vim.b['quarto_is_r_mode'] == nil then
    vim.fn['slime#send_cell']()
    return
  end
  if vim.b['quarto_is_r_mode'] == true then
    vim.g.slime_python_ipython = 0
    local is_python = require('otter.tools.functions').is_otter_language_context 'python'
    if is_python and not vim.b['reticulate_running'] then
      vim.fn['slime#send']('reticulate::repl_python()' .. '\r')
      vim.b['reticulate_running'] = true
    end
    if not is_python and vim.b['reticulate_running'] then
      vim.fn['slime#send']('exit' .. '\r')
      vim.b['reticulate_running'] = false
    end
    vim.fn['slime#send_cell']()
  end
end

--- Send code to terminal with vim-slime
--- If an R terminal has been opend, this is in r_mode
--- and will handle python code via reticulate when sent
--- from a python chunk.
local slime_send_region_cmd = ':<C-u>call slime#send_op(visualmode(), 1)<CR>'
slime_send_region_cmd = vim.api.nvim_replace_termcodes(slime_send_region_cmd, true, false, true)
local function send_region()
  if vim.bo.filetype ~= 'quarto' or vim.b['quarto_is_r_mode'] == nil then
    vim.cmd('normal' .. slime_send_region_cmd)
    return
  end
  if vim.b['quarto_is_r_mode'] == true then
    vim.g.slime_python_ipython = 0
    local is_python = require('otter.tools.functions').is_otter_language_context 'python'
    if is_python and not vim.b['reticulate_running'] then
      vim.fn['slime#send']('reticulate::repl_python()' .. '\r')
      vim.b['reticulate_running'] = true
    end
    if not is_python and vim.b['reticulate_running'] then
      vim.fn['slime#send']('exit' .. '\r')
      vim.b['reticulate_running'] = false
    end
    vim.cmd('normal' .. slime_send_region_cmd)
  end
end

-- send code with ctrl+Enter
nmap('<c-cr>', send_cell)
nmap('<s-cr>', send_cell)
imap('<c-cr>', send_cell)
imap('<s-cr>', send_cell)

--- Show R dataframe in the browser
local function show_r_table()
  local node = vim.treesitter.get_node { ignore_injections = false }
  assert(node, 'no symbol found under cursor')
  local text = vim.treesitter.get_node_text(node, 0)
  local cmd = [[call slime#send("DT::datatable(]] .. text .. [[)" . "\r")]]
  vim.cmd(cmd)
end

-- keep selection after indent/dedent
vmap('>', '>gv')
vmap('<', '<gv')

-- center after search and jumps
nmap('n', 'nzz')
nmap('<c-d>', '<c-d>zz')
nmap('<c-u>', '<c-u>zz')

-- move between splits and tabs
nmap('<c-h>', '<c-w>h')
nmap('<c-l>', '<c-w>l')
nmap('<c-j>', '<c-w>j')
nmap('<c-k>', '<c-w>k')
nmap('H', '<cmd>tabprevious<cr>')
nmap('L', '<cmd>tabnext<cr>')

local function toggle_light_dark_theme()
  if vim.o.background == 'light' then
    vim.o.background = 'dark'
  else
    vim.o.background = 'light'
  end
end

---Is the current context a code chunk?
local is_code_chunk = function(lang)
  local current = require('otter.keeper').get_current_language_context()
  return current == lang
end

local insert_a_code_chunk = function(lang, curly)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<esc>', true, false, true), 'n', true)
  local keys
  if curly == nil then curly = true end
  if is_code_chunk(lang) then
    if curly then
      keys = [[o```<cr><cr>```{]] .. lang .. [[}<esc>o]]
    else
      keys = [[o```<cr><cr>```]] .. lang .. [[<esc>o]]
    end
  else
    if curly then
      keys = [[o```{]] .. lang .. [[}<cr>```<esc>O]]
    else
      keys = [[o```]] .. lang .. [[<cr>```<esc>O]]
    end
  end
  keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
  vim.api.nvim_feedkeys(keys, 'n', false)
end

local insert_code_chunk = function(lang) insert_a_code_chunk(lang, true) end
local insert_plain_code_chunk = function(lang) insert_a_code_chunk(lang, false) end

local insert_r_chunk = function() insert_code_chunk 'r' end
local insert_py_chunk = function() insert_code_chunk 'python' end
local insert_lua_chunk = function() insert_code_chunk 'lua' end
local insert_julia_chunk = function() insert_code_chunk 'julia' end
local insert_bash_chunk = function() insert_code_chunk 'bash' end
local insert_ojs_chunk = function() insert_code_chunk 'ojs' end

local insert_plain_r_chunk = function() insert_plain_code_chunk 'r' end
local insert_plain_py_chunk = function() insert_plain_code_chunk 'python' end
local insert_plain_lua_chunk = function() insert_plain_code_chunk 'lua' end
local insert_plain_julia_chunk = function() insert_plain_code_chunk 'julia' end
local insert_plain_bash_chunk = function() insert_plain_code_chunk 'bash' end
local insert_plain_ojs_chunk = function() insert_plain_code_chunk 'ojs' end

-- normal mode
wk.add({
  { '<c-LeftMouse>', '<cmd>lua vim.lsp.buf.definition()<CR>', desc = 'go to definition' },
  { '<c-q>', '<cmd>q<cr>', desc = 'close buffer' },
  { '<cm-i>', insert_py_chunk, desc = 'python code chunk' },
  { '<esc>', '<cmd>noh<cr>', desc = 'remove search highlight' },
  { '<m-I>', insert_py_chunk, desc = 'python code chunk' },
  { '<m-j>', insert_julia_chunk, desc = 'j code chunk' },
  { '[q', ':silent cprev<cr>', desc = '[q]uickfix prev' },
  { ']q', ':silent cnext<cr>', desc = '[q]uickfix next' },
  { 'gN', 'Nzzzv', desc = 'center search' },
  { 'gf', ':e <cfile><CR>', desc = 'edit file' },
  { 'gl', '<c-]>', desc = 'open help link' },
  { 'n', 'nzzzv', desc = 'center search' },
  { 'z?', ':setlocal spell!<cr>', desc = 'toggle [z]pellcheck' },
  { 'zl', ':Telescope spell_suggest<cr>', desc = '[l]ist spelling suggestions' },
}, { mode = 'n', silent = true })

-- visual mode
wk.add {
  {
    mode = { 'v' },
    { '.', ':norm .<cr>', desc = 'repat last normal mode command' },
    { '<M-j>', ":m'>+<cr>`<my`>mzgv`yo`z", desc = 'move line down' },
    { '<M-k>', ":m'<-2<cr>`>my`<mzgv`yo`z", desc = 'move line up' },
    { '<cr>', send_region, desc = 'run code region' },
    { 'q', ':norm @q<cr>', desc = 'repat q macro' },
  },
}

-- visual with <leader>
wk.add({
  { '<leader>d', '"_d', desc = 'delete without overwriting reg', mode = 'v' },
  { '<leader>p', '"_dP', desc = 'replace without overwriting reg', mode = 'v' },
}, { mode = 'v' })

-- insert mode
wk.add({
  {
    mode = { 'i' },
    { '<c-x><c-x>', '<c-x><c-o>', desc = 'omnifunc completion' },
    { '<cm-i>', insert_py_chunk, desc = 'python code chunk' },
    { '<m-->', ' <- ', desc = 'assign' },
    { '<m-I>', insert_py_chunk, desc = 'python code chunk' },
    { '<m-j>', insert_julia_chunk, desc = 'julia code chunk' },
    { '<m-m>', ' |>', desc = 'pipe' },
  },
}, { mode = 'i' })

local function new_terminal(lang) vim.cmd('vsplit term://' .. lang) end
local function new_terminal_python() new_terminal 'python' end
local function new_terminal_r() new_terminal 'R --no-save' end
local function new_terminal_ipython() new_terminal 'ipython --no-confirm-exit --no-autoindent' end
local function new_terminal_julia() new_terminal 'julia' end
local function new_terminal_shell() new_terminal '$SHELL' end

local function get_otter_symbols_lang()
  local otterkeeper = require 'otter.keeper'
  local main_nr = vim.api.nvim_get_current_buf()
  local langs = {}
  for i, l in ipairs(otterkeeper.rafts[main_nr].languages) do
    langs[i] = i .. ': ' .. l
  end
  local i = vim.fn.inputlist(langs)
  local lang = otterkeeper.rafts[main_nr].languages[i]
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(),
    otter = { lang = lang },
  }
  vim.lsp.buf_request(main_nr, ms.textDocument_documentSymbol, params, nil)
end

vim.keymap.set('n', '<leader>ros', get_otter_symbols_lang, { desc = 'otter [s]ymbols' })

local function toggle_conceal()
  local lvl = vim.o.conceallevel
  if lvl > DefaultConcealLevel then
    vim.o.conceallevel = DefaultConcealLevel
  else
    vim.o.conceallevel = FullConcealLevel
  end
end

local function clear_image_cache()
  local cache_dir = vim.fn.stdpath 'cache' .. '/snacks/image'
  if vim.fn.isdirectory(cache_dir) == 1 then vim.fn.delete(cache_dir, 'rf') end
end

-- normal mode with <leader>
wk.add({
  {
    { '<leader><cr>', send_cell, desc = 'run code cell' },
    { '<leader>c', group = '[c]ode / [c]ell / [c]hunk' },
    { '<leader>cj', new_terminal_julia, desc = 'new [j]ulia terminal' },
    { '<leader>cn', new_terminal_shell, desc = '[n]ew terminal with shell' },
    { '<leader>cp', new_terminal_python, desc = 'new [p]ython terminal' },
    { '<leader>cr', new_terminal_r, desc = 'new [R] terminal' },
    { '<leader>d', group = '[d]ebug' },
    { '<leader>dt', group = '[t]est' },
    { '<leader>e', group = '[e]dit' },
    { '<leader>e', group = '[t]mux' },
    { '<leader>fd', [[eval "$(tmux showenv -s DISPLAY)"]], desc = '[d]isplay fix' },
    { '<leader>f', group = '[f]ind (telescope)' },
    { '<leader>f<space>', '<cmd>Telescope buffers<cr>', desc = '[ ] buffers' },
    { '<leader>fM', '<cmd>Telescope man_pages<cr>', desc = '[M]an pages' },
    { '<leader>fb', '<cmd>Telescope current_buffer_fuzzy_find<cr>', desc = '[b]uffer fuzzy find' },
    { '<leader>fc', '<cmd>Telescope git_commits<cr>', desc = 'git [c]ommits' },
    { '<leader>fd', '<cmd>Telescope buffers<cr>', desc = '[d] buffers' },
    { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = '[f]iles' },
    { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = '[g]rep' },
    { '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = '[h]elp' },
    { '<leader>fj', '<cmd>Telescope jumplist<cr>', desc = '[j]umplist' },
    { '<leader>fk', '<cmd>Telescope keymaps<cr>', desc = '[k]eymaps' },
    { '<leader>fl', '<cmd>Telescope loclist<cr>', desc = '[l]oclist' },
    { '<leader>fm', '<cmd>Telescope marks<cr>', desc = '[m]arks' },
    { '<leader>fq', '<cmd>Telescope quickfix<cr>', desc = '[q]uickfix' },
    { '<leader>g', group = '[g]it' },
    { '<leader>gb', group = '[b]lame' },
    { '<leader>gbb', ':GitBlameToggle<cr>', desc = '[b]lame toggle virtual text' },
    { '<leader>gbc', ':GitBlameCopyCommitURL<cr>', desc = '[c]opy' },
    { '<leader>gbo', ':GitBlameOpenCommitURL<cr>', desc = '[o]pen' },
    { '<leader>gc', ':GitConflictRefresh<cr>', desc = '[c]onflict' },
    { '<leader>gd', group = '[d]iff' },
    { '<leader>gs', ':Gitsigns<cr>', desc = 'git [s]igns' },
    { '<leader>gwc', ":lua require('telescope').extensions.git_worktree.create_git_worktree()<cr>", desc = 'worktree create' },
    { '<leader>gws', ":lua require('telescope').extensions.git_worktree.git_worktrees()<cr>", desc = 'worktree switch' },
    { '<leader>h', group = '[h]elp / [h]ide / debug' },
    { '<leader>hc', group = '[c]onceal' },
    { '<leader>hc', toggle_conceal, desc = '[c]onceal toggle' },
    { '<leader>ht', group = '[t]reesitter' },
    { '<leader>htt', vim.treesitter.inspect_tree, desc = 'show [t]ree' },
    { '<leader>i', group = '[i]mage/[i]nsert' },
    { '<leader>ic', clear_image_cache, desc = '[c]lear image cache' },
    { '<leader>l', group = '[l]anguage/lsp' },
    { '<leader>ld', group = '[d]iagnostics' },
    { '<leader>ldd', function() vim.diagnostic.enable(false) end, desc = '[d]isable' },
    { '<leader>lde', vim.diagnostic.enable, desc = '[e]nable' },
    { '<leader>le', vim.diagnostic.open_float, desc = 'diagnostics (show hover [e]rror)' },
    { '<leader>lg', ':Neogen<cr>', desc = 'neo[g]en docstring' },
    { '<leader>ro', group = '[o]tter & c[o]de' },
    { '<leader>roa', require('otter').activate, desc = 'otter [a]ctivate' },
    { '<leader>roc', 'O# %%<cr>', desc = 'magic [c]omment code chunk # %%' },
    { '<leader>rod', require('otter').activate, desc = 'otter [d]eactivate' },
    { '<leader>roj', insert_julia_chunk, desc = '[j]ulia code chunk' },
    { '<leader>rol', insert_lua_chunk, desc = '[l]lua code chunk' },
    { '<leader>roo', insert_ojs_chunk, desc = '[o]bservable js code chunk' },
    { '<leader>rop', insert_py_chunk, desc = '[p]ython code chunk' },
    { '<leader>ror', insert_r_chunk, desc = '[r] code chunk' },
    { '<leader>rob', insert_bash_chunk, desc = '[b]ash code chunk' },
    { '<leader>Ro', group = 'plain c[O]de' },
    { '<leader>ROj', insert_plain_julia_chunk, desc = '[j]ulia code chunk' },
    { '<leader>ROl', insert_plain_lua_chunk, desc = '[l]lua code chunk' },
    { '<leader>ROo', insert_plain_ojs_chunk, desc = '[o]bservable js code chunk' },
    { '<leader>ROp', insert_plain_py_chunk, desc = '[p]ython code chunk' },
    { '<leader>ROr', insert_plain_r_chunk, desc = '[r] code chunk' },
    { '<leader>ROb', insert_plain_bash_chunk, desc = '[b]ash code chunk' },
    { '<leader>q', group = '[q]uarto' },
    { '<leader>qE', function() require('otter').export(true) end, desc = '[E]xport with overwrite' },
    { '<leader>qa', ':QuartoActivate<cr>', desc = '[a]ctivate' },
    { '<leader>qe', require('otter').export, desc = '[e]xport' },
    { '<leader>qh', ':QuartoHelp ', desc = '[h]elp' },
    { '<leader>qp', ":lua require'quarto'.quartoPreview()<cr>", desc = '[p]review' },
    { '<leader>qu', ":lua require'quarto'.quartoUpdatePreview()<cr>", desc = '[u]pdate preview' },
    { '<leader>qq', ":lua require'quarto'.quartoClosePreview()<cr>", desc = '[q]uiet preview' },
    { '<leader>qr', group = '[r]un' },
    { '<leader>qra', ':QuartoSendAll<cr>', desc = 'run [a]ll' },
    { '<leader>qrb', ':QuartoSendBelow<cr>', desc = 'run [b]elow' },
    { '<leader>qrr', ':QuartoSendAbove<cr>', desc = 'to cu[r]sor' },
    { '<leader>r', group = '[r] R specific tools' },
    { '<leader>rt', show_r_table, desc = 'show [t]able' },
    { '<leader>v', group = '[v]im' },
    { '<leader>vc', ':Telescope colorscheme<cr>', desc = '[c]olortheme' },
    { '<leader>vh', ':execute "h " . expand("<cword>")<cr>', desc = 'vim [h]elp for current word' },
    { '<leader>vl', ':Lazy<cr>', desc = '[l]azy package manager' },
    { '<leader>vm', ':Mason<cr>', desc = '[m]ason software installer' },
    { '<leader>vs', ':e $MYVIMRC | :cd %:p:h | split . | wincmd k<cr>', desc = '[s]ettings, edit vimrc' },
    { '<leader>vt', toggle_light_dark_theme, desc = '[t]oggle light/dark theme' },
    { '<leader>x', group = 'e[x]ecute' },
    { '<leader>xx', ':w<cr>:source %<cr>', desc = '[x] source %' },
  },
}, { mode = 'n' })

-- CodeCompanion
map({ 'n', 'v' }, '<leader>ca', '<cmd>CodeCompanionActions<cr>', { desc = 'CodeCompanion: Ações' })
map({ 'n', 'v' }, '<leader>cc', '<cmd>CodeCompanionChat Toggle<cr>', { desc = 'CodeCompanion: Alternar Chat' })
map({ 'n', 'v' }, '<leader>ci', '<cmd>CodeCompanion<cr>', { desc = 'CodeCompanion: Prompt Inline' })
map('v', 'ga', '<cmd>CodeCompanionChat Add<cr>', { desc = 'CodeCompanion: Adicionar ao Chat' })

-- Navegação entre janelas
map('n', '<C-h>', '<C-w>h', { desc = 'Janela à esquerda' })
map('n', '<C-j>', '<C-w>j', { desc = 'Janela abaixo' })
map('n', '<C-k>', '<C-w>k', { desc = 'Janela acima' })
map('n', '<C-l>', '<C-w>l', { desc = 'Janela à direita' })

-- Renomear arquivo
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

-- Toggle search
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

map('n', '?', toggle_search_clean, { desc = 'Toggle Search e Limpar Terminal', silent = true, nowait = true })

-- Splits
map('n', '<leader>v', '<cmd>vsp<cr>', { desc = 'Dividir Verticalmente' })
map('n', '<leader>h', '<cmd>sp<cr>', { desc = 'Dividir Horizontalmente' })

-- Terminais
local term_h_buf = nil
local term_h_win = nil
map({ 'n', 't' }, '<A-h>', function()
  if term_h_win and vim.api.nvim_win_is_valid(term_h_win) then
    vim.api.nvim_win_close(term_h_win, true)
    term_h_win = nil
    term_h_buf = nil
  else
    vim.cmd 'split | terminal'
    term_h_win = vim.api.nvim_get_current_win()
    term_h_buf = vim.api.nvim_get_current_buf()
    vim.cmd 'startinsert'
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = term_h_buf,
      callback = function()
        term_h_win = nil
        term_h_buf = nil
      end,
      once = true,
    })
  end
end, { desc = 'Terminal horizontal (toggle)' })

local term_v_buf = nil
local term_v_win = nil
map({ 'n', 't' }, '<A-v>', function()
  if term_v_win and vim.api.nvim_win_is_valid(term_v_win) then
    vim.api.nvim_win_close(term_v_win, true)
    term_v_win = nil
    term_v_buf = nil
  else
    vim.cmd 'vsplit | terminal'
    term_v_win = vim.api.nvim_get_current_win()
    term_v_buf = vim.api.nvim_get_current_buf()
    vim.cmd 'startinsert'
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = term_v_buf,
      callback = function()
        term_v_win = nil
        term_v_buf = nil
      end,
      once = true,
    })
  end
end, { desc = 'Terminal vertical (toggle)' })

local term_float_win = nil
local term_float_buf = nil
map({ 'n', 't' }, '<A-i>', function()
  if term_float_win and vim.api.nvim_win_is_valid(term_float_win) then
    vim.api.nvim_win_close(term_float_win, true)
    term_float_win = nil
  elseif term_float_buf and vim.api.nvim_buf_is_valid(term_float_buf) then
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local opts = {
      relative = 'editor',
      width = width,
      height = height,
      col = (vim.o.columns - width) / 2,
      row = (vim.o.lines - height) / 2,
      style = 'minimal',
      border = 'rounded',
      title = ' Terminal ',
      title_pos = 'center',
    }
    term_float_win = vim.api.nvim_open_win(term_float_buf, true, opts)
    vim.cmd 'startinsert'
  else
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local opts = {
      relative = 'editor',
      width = width,
      height = height,
      col = (vim.o.columns - width) / 2,
      row = (vim.o.lines - height) / 2,
      style = 'minimal',
      border = 'rounded',
      title = ' Terminal ',
      title_pos = 'center',
    }
    term_float_buf = vim.api.nvim_create_buf(false, true)
    term_float_win = vim.api.nvim_open_win(term_float_buf, true, opts)
    vim.fn.termopen(vim.o.shell, { detach = 0 })
    vim.cmd 'startinsert'
    vim.api.nvim_create_autocmd('TermClose', {
      buffer = term_float_buf,
      callback = function()
        if term_float_win and vim.api.nvim_win_is_valid(term_float_win) then vim.api.nvim_win_close(term_float_win, true) end
        term_float_win = nil
        term_float_buf = nil
      end,
      once = true,
    })
  end
end, { desc = 'Terminal flutuante (hide/show, exit to destroy)' })

-------------------------------------------------------------------
-- [ CONFIGURAÇÕES ESPECÍFICAS DO OBSIDIAN ]
-------------------------------------------------------------------

local function is_obsidian_context()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= '' then
    local ext = vim.fn.fnamemodify(bufname, ':e')
    if ext ~= 'md' and ext ~= 'qmd' and ext ~= 'base' then return false end
    local vault_path = vim.fn.expand '~/Documents/brain'
    if bufname:find(vault_path, 1, true) then return true end
  end
  local cwd = vim.fn.getcwd()
  local vault_path = vim.fn.expand '~/Documents/brain'
  if cwd:find(vault_path, 1, true) then return true end
  return false
end

local function ensure_in_vault()
  if not is_obsidian_context() then
    local vault_path = vim.fn.expand '~/Documents/brain'
    vim.cmd('cd ' .. vault_path)
    vim.notify('Diretório alterado para o vault: ' .. vault_path, vim.log.levels.INFO)
  end
end

-- ATALHO: Comandos Obsidian
vim.keymap.set('n', '<leader>oo', function()
  ensure_in_vault()
  local obsidian_commands = {
    { name = 'Quick Switch (Abrir nota)', cmd = 'ObsidianQuickSwitch' },
    { name = 'Pesquisar notas', cmd = 'ObsidianSearch' },
    { name = 'Nova nota', cmd = 'ObsidianNew' },
    { name = 'Nota de hoje', cmd = 'ObsidianToday' },
    { name = 'Nota de ontem', cmd = 'ObsidianYesterday' },
    { name = 'Notas diárias', cmd = 'ObsidianDailies' },
    { name = 'Backlinks', cmd = 'ObsidianBacklinks' },
    { name = 'Tags', cmd = 'ObsidianTags' },
    { name = 'Colar imagem', cmd = 'ObsidianPasteImg' },
    { name = 'Renomear nota', cmd = 'ObsidianRename' },
    { name = 'Seguir link', cmd = 'ObsidianFollowLink' },
    { name = 'Template', cmd = 'ObsidianTemplate' },
    { name = 'Abrir no navegador', cmd = 'ObsidianOpen' },
    { name = 'Workspace', cmd = 'ObsidianWorkspace' },
  }
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  pickers
    .new({}, {
      prompt_title = 'Comandos Obsidian',
      finder = finders.new_table {
        results = obsidian_commands,
        entry_maker = function(entry) return { value = entry, display = entry.name, ordinal = entry.name } end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then vim.cmd(selection.value.cmd) end
        end)
        return true
      end,
    })
    :find()
end, { desc = 'Obsidian: Comandos (Telescope)' })

-- Templates por pasta
local folder_template_map = {
  ['00-rápidas'] = '00-rápidas-tlp.md',
  ['01-notelm'] = '01-notelm-tlp.md',
  ['02-zettel'] = '02-zettel-tlp.md',
  ['03-MOC'] = '03-MOC-tlp.md',
  ['99-brutos/biblioteca'] = '99-Acervo-tlp.md',
  ['99-brutos/tracking'] = '99-tracking-tlp.md',
  ['99-brutos/exercícios'] = '99-exercícios-tlp.md',
}

local function translate_template(content, title)
  local now = os.date
  local date = now '%Y-%m-%d'
  local time = now '%H:%M'
  local datetime = date .. ' ' .. time
  local datetime_t = date .. 'T' .. time
  local patterns = {
    { '<%% tp%.date%.now%("YYYY%-MM%-DD HH:mm"%) %%>', datetime },
    { '<%% tp%.date%.now%("YYYY%-MM%-DDTHH:mm"%) %%>', datetime_t },
    { '<%% tp%.date%.now%("YYYY%-MM%-DD"%) %%>', date },
    { '<%% tp%.file%.title %%>', title },
    { '{{title}}', title },
    { '{{date}}', date },
    { '{{time}}', time },
  }
  local translated = content
  for _, pat in ipairs(patterns) do
    translated = translated:gsub(pat[1], pat[2])
  end
  return translated
end

local function get_vault_directories(vault_path)
  local dirs = {}
  local function scan(current_path, depth)
    local items = vim.fn.readdir(current_path)
    for _, item in ipairs(items) do
      local full = current_path .. '/' .. item
      if vim.fn.isdirectory(full) == 1 then
        if not item:match '^%.' then
          table.insert(dirs, { path = full, depth = depth })
          scan(full, depth + 1)
        end
      end
    end
  end
  scan(vault_path, 1)
  table.sort(dirs, function(a, b)
    if a.depth == b.depth then
      return a.path < b.path
    else
      return a.depth < b.depth
    end
  end)
  local relative_dirs = {}
  for _, d in ipairs(dirs) do
    local rel = d.path:sub(#vault_path + 2)
    table.insert(relative_dirs, rel)
  end
  return relative_dirs
end

-- NOVA NOTA COM SELEÇÃO DE DIRETÓRIO (aceita pré-seleção via opts)
local function new_obsidian_note_with_directory_telescope(opts)
  opts = opts or {}
  ensure_in_vault()
  local vault_path = vim.fn.expand '~/Documents/brain'
  local template_dir = vault_path .. '/99-brutos/templates/'
  local directories = get_vault_directories(vault_path)
  table.insert(directories, 1, '')

  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  pickers
    .new({}, {
      prompt_title = 'Escolha o diretório para a nova nota',
      finder = finders.new_table {
        results = directories,
        entry_maker = function(dir)
          local display = dir == '' and '[raiz do vault]' or dir
          return { value = dir, display = display, ordinal = display }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if not selection then return end
          local chosen_dir = opts.default_dir or selection.value
          local default_name = opts.default_name or ''
          vim.ui.input({
            prompt = 'Nome da nota (sem extensão): ',
            default = default_name,
          }, function(filename)
            if not filename or filename == '' then return end
            local rel_path = chosen_dir == '' and filename or chosen_dir .. '/' .. filename
            if not rel_path:match '%.%w+$' then rel_path = rel_path .. '.md' end
            local full_path = vault_path .. '/' .. rel_path
            local title = vim.fn.fnamemodify(filename, ':r')

            local template_name = nil
            local clean_rel = rel_path:gsub('^/', '')
            for folder, tpl in pairs(folder_template_map) do
              if clean_rel == folder or vim.startswith(clean_rel, folder .. '/') then
                template_name = tpl
                break
              end
            end

            local content
            if template_name then
              local f = io.open(template_dir .. template_name, 'r')
              if f then
                content = f:read '*a'
                f:close()
                content = translate_template(content, title)
              else
                content = string.format('---\ntitle: %s\ndate: %s %s\n---\n', title, os.date '%Y-%m-%d', os.date '%H:%M')
              end
            else
              content = string.format('---\ntitle: %s\ndate: %s %s\n---\n', title, os.date '%Y-%m-%d', os.date '%H:%M')
            end

            if vim.fn.filereadable(full_path) == 1 then
              vim.ui.select({ 'Sim', 'Não' }, { prompt = 'O arquivo já existe. Deseja sobrescrevê-lo?' }, function(choice)
                if choice == 'Sim' then
                  vim.fn.mkdir(vim.fn.fnamemodify(full_path, ':h'), 'p')
                  local file = io.open(full_path, 'w')
                  if file then
                    file:write(content)
                    file:close()
                    vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
                  end
                end
              end)
            else
              vim.fn.mkdir(vim.fn.fnamemodify(full_path, ':h'), 'p')
              local file = io.open(full_path, 'w')
              if file then
                file:write(content)
                file:close()
                vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
              end
            end
          end)
        end)
        return true
      end,
    })
    :find()
end

-- Extensões suportadas
local obsidian_extensions = { 'excalidraw', 'md', 'qmd', 'js', 'base' }

-- QUICK SWITCH PERSONALIZADO
local function obsidian_quick_switch_telescope()
  ensure_in_vault()
  local vault_path = vim.fn.expand '~/Documents/brain'
  local glob_pattern = '**/*.{' .. table.concat(obsidian_extensions, ',') .. '}'
  local cmd = {
    'rg',
    '--files',
    '--iglob',
    glob_pattern,
    '--iglob',
    '!**/.*',
    '--color',
    'never',
    '--no-heading',
    '--with-filename',
    '--line-number',
    '--column',
    vault_path,
  }
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local original_buf = vim.api.nvim_get_current_buf()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  pickers
    .new({}, {
      prompt_title = 'Notes | <CR> confirm | <C-l> insert link',
      finder = finders.new_oneshot_job(cmd, {
        entry_maker = function(line)
          local full_path = line:match '^([^:]+)'
          if not full_path then return nil end
          local rel_path = full_path:sub(#vault_path + 2)
          local name_with_ext = vim.fn.fnamemodify(rel_path, ':t')
          local name_base = vim.fn.fnamemodify(rel_path, ':t:r')
          local ext = vim.fn.fnamemodify(rel_path, ':e')
          local link_name = (ext == 'md' or ext == 'qmd') and name_base or name_with_ext
          return { value = full_path, display = rel_path, ordinal = rel_path, link_name = link_name }
        end,
      }),
      sorter = conf.generic_sorter {},
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then vim.cmd('edit ' .. vim.fn.fnameescape(selection.value)) end
        end)
        local function insert_link()
          local selection = action_state.get_selected_entry()
          if not selection then return end
          actions.close(prompt_bufnr)
          local link_text = '[[' .. selection.link_name .. ']]'
          local row = cursor_pos[1] - 1
          local col = cursor_pos[2]
          vim.api.nvim_buf_set_text(original_buf, row, col, row, col, { link_text })
          vim.notify('Link inserido: ' .. link_text, vim.log.levels.INFO)
        end
        map('i', '<C-l>', insert_link)
        map('n', '<C-l>', insert_link)
        return true
      end,
    })
    :find()
end

vim.keymap.set('n', '<leader>of', obsidian_quick_switch_telescope, { desc = 'Obsidian: Quick Switch (Telescope)' })

-- Demais atalhos Obsidian
vim.keymap.set('n', '<leader>os', function()
  ensure_in_vault()
  vim.cmd 'ObsidianSearch'
end, { desc = 'Obsidian: Pesquisar notas' })
vim.keymap.set('n', '<leader>on', new_obsidian_note_with_directory_telescope, { desc = 'Obsidian: Nova nota (escolher diretório)' })
vim.keymap.set('n', '<leader>ot', function()
  ensure_in_vault()
  vim.cmd 'ObsidianToday'
end, { desc = 'Obsidian: Nota de hoje' })
vim.keymap.set('n', '<leader>oy', function()
  ensure_in_vault()
  vim.cmd 'ObsidianYesterday'
end, { desc = 'Obsidian: Nota de ontem' })
vim.keymap.set('n', '<leader>od', function()
  ensure_in_vault()
  vim.cmd 'ObsidianDailies'
end, { desc = 'Obsidian: Notas diárias' })
vim.keymap.set('n', '<leader>ob', function()
  ensure_in_vault()
  vim.cmd 'ObsidianBacklinks'
end, { desc = 'Obsidian: Backlinks' })
vim.keymap.set('n', '<leader>og', function()
  ensure_in_vault()
  vim.cmd 'ObsidianTags'
end, { desc = 'Obsidian: Tags' })
vim.keymap.set('n', '<leader>oi', function()
  ensure_in_vault()
  vim.cmd 'ObsidianPasteImg'
end, { desc = 'Obsidian: Colar imagem' })
vim.keymap.set('n', '<leader>or', function()
  ensure_in_vault()
  vim.cmd 'ObsidianRename'
end, { desc = 'Obsidian: Renomear nota' })
vim.keymap.set('n', '<leader>op', function()
  ensure_in_vault()
  vim.cmd 'ObsidianTemplate'
end, { desc = 'Obsidian: Template' })
vim.keymap.set('n', '<leader>ow', function()
  ensure_in_vault()
  vim.cmd 'ObsidianWorkspace'
end, { desc = 'Obsidian: Workspace' })
vim.keymap.set('n', '<leader>ov', function() vim.cmd('cd ' .. vim.fn.expand '~/Documents/brain') end, { desc = 'Obsidian: Abrir caminho do vault' })

-- NOVA FUNÇÃO PARA SEGUIR LINKS (com suporte a criação)
local function find_note_by_link(link)
  local vault_path = vim.fn.expand '~/Documents/brain'
  -- Remove âncoras
  local clean_link = link:match '([^#]+)' or link
  -- Tenta encontrar arquivo com extensões suportadas (busca recursiva)
  for _, ext in ipairs(obsidian_extensions) do
    local pattern = vault_path .. '/**/' .. clean_link .. '.' .. ext
    local files = vim.fn.glob(pattern, false, true)
    if #files > 0 then return files[1], ext end
  end
  -- Tenta também se o link já inclui extensão
  if clean_link:match '%.%w+$' then
    local full = vault_path .. '/' .. clean_link
    if vim.fn.filereadable(full) == 1 then
      local ext = vim.fn.fnamemodify(full, ':e')
      return full, ext
    end
  end
  return nil, nil
end

vim.keymap.set('n', '<CR>', function()
  if not is_obsidian_context() then return '<CR>' end

  -- Tenta primeiro os métodos nativos do obsidian.nvim
  local ok, obsidian = pcall(require, 'obsidian')
  if ok then
    local client = obsidian.get_client()
    if client and pcall(client.follow_link, client) then return '' end
  end
  if pcall(vim.cmd, 'ObsidianFollowLink') then return '' end

  -- Fallback manual
  local line = vim.api.nvim_get_current_line()
  local link = line:match '%[%[([^%]]+)%]%]' or line:match '%[.-%]%(([^%)]+)%)'
  if not link then return '<CR>' end

  local file_path, ext = find_note_by_link(link)
  if file_path then
    if ext == 'md' or ext == 'qmd' then
      vim.cmd('edit ' .. vim.fn.fnameescape(file_path))
    else
      vim.cmd('tabnew ' .. vim.fn.fnameescape(file_path))
    end
    return ''
  end

  -- Arquivo não existe: pergunta se quer criar
  vim.ui.select({ 'Sim', 'Não' }, {
    prompt = 'Arquivo "' .. link .. '" não existe. Deseja criá-lo?',
  }, function(choice)
    if choice == 'Sim' then
      -- Extrai diretório e nome do link
      local dir, name = link:match '^(.*)/([^/]+)$'
      local opts = {}
      if dir then
        opts.default_dir = dir
        opts.default_name = name
      else
        opts.default_name = link
      end
      new_obsidian_note_with_directory_telescope(opts)
    end
  end)
  return ''
end, { expr = true, desc = 'Obsidian: Seguir Link (com criação)' })

-- Atalhos visuais
vim.keymap.set('v', '<leader>ol', function()
  if is_obsidian_context() then vim.cmd 'ObsidianLink' end
end, { desc = 'Obsidian: Criar link' })
vim.keymap.set('v', '<leader>ox', function()
  if is_obsidian_context() then vim.cmd 'ObsidianExtractNote' end
end, { desc = 'Obsidian: Extrair para nova nota' })

vim.api.nvim_create_user_command('ObsidianVault', function()
  vim.cmd('cd ' .. vim.fn.expand '~/Documents/brain')
  vim.cmd 'ObsidianQuickSwitch'
end, { desc = 'Abrir vault do Obsidian' })

-- Which-key
wk.add {
  { '<leader>o', group = '[o]bsidian' },
  { '<leader>oo', desc = 'Comandos (Telescope)' },
  { '<leader>os', desc = 'Pesquisar' },
  { '<leader>on', desc = 'Nova nota' },
  { '<leader>ot', desc = 'Hoje' },
  { '<leader>oy', desc = 'Ontem' },
  { '<leader>od', desc = 'Diárias' },
  { '<leader>ob', desc = 'Backlinks' },
  { '<leader>og', desc = 'Tags' },
  { '<leader>oi', desc = 'Colar imagem' },
  { '<leader>or', desc = 'Renomear' },
  { '<leader>op', desc = 'Template' },
  { '<leader>ow', desc = 'Workspace' },
  { '<leader>ov', desc = 'Abrir vault' },
  { '<leader>t', group = '[t]mp Tools/Quarto' },
  { '<leader>to', desc = 'Obsidian Quick Switch' },
}

-- ==========================================
-- INTEGRAÇÃO GIT-BUG (ATUALIZADA - BRIDGE AUTH)
-- ==========================================

-- ---------- Funções auxiliares ----------

local function adopt_identity_in_repo(git_root, id)
  local cmd = string.format('cd %s && git bug user adopt %s', vim.fn.shellescape(git_root), id)
  local ok = os.execute(cmd .. ' > /dev/null 2>&1')
  return ok == 0
end

local function get_working_dir()
  local bufpath = vim.api.nvim_buf_get_name(0)
  if bufpath ~= '' then
    return vim.fn.fnamemodify(bufpath, ':p:h')
  else
    return vim.fn.getcwd()
  end
end

local function get_git_root(cwd)
  local output = vim.fn.system('cd ' .. vim.fn.shellescape(cwd) .. ' && git rev-parse --show-toplevel 2>/dev/null')
  if vim.v.shell_error ~= 0 then return nil end
  return output:gsub('%s+', '')
end

local function kitty_remote_available() return os.execute 'kitty @ ls > /dev/null 2>&1' end

local function clean_locks(git_root)
  os.execute('cd ' .. vim.fn.shellescape(git_root) .. ' && rm -f .git/refs/bugs/lock .git/refs/bugs.lock .git/git-bug.lock 2>/dev/null')
end

local function kitty_float_exec(cmd, git_root)
  if not kitty_remote_available() then return false end
  local script_path = vim.fn.stdpath 'cache' .. '/kitty_gitbug.sh'
  local script_content = string.format(
    [[
#!/bin/bash
cd %s
export EDITOR=nvim
%s
]],
    vim.fn.shellescape(git_root),
    cmd
  )
  local file = io.open(script_path, 'w')
  if not file then return false end
  file:write(script_content)
  file:close()
  os.execute('chmod +x ' .. script_path)
  local kitty_cmd = string.format(
    'kitty @ launch --type=overlay --title "Git Bug" bash -c %s 2>/dev/null || ' .. 'kitty @ launch --type=window --title "Git Bug" bash -c %s',
    vim.fn.shellescape(script_path),
    vim.fn.shellescape(script_path)
  )
  return os.execute(kitty_cmd) == 0
end

local function nvim_term_exec(cmd, git_root, interactive, wait_after)
  clean_locks(git_root)
  local prefix = 'cd ' .. vim.fn.shellescape(git_root) .. ' && clear; '
  local suffix = wait_after and "; echo; echo '--- PROCESSO CONCLUÍDO. PRESSIONE ENTER PARA SAIR ---'; read" or '; exit'
  local full_cmd = prefix .. cmd .. suffix
  vim.cmd('split | terminal bash -c ' .. vim.fn.shellescape(full_cmd))
  if interactive then vim.cmd 'startinsert' end
end

-- ---------- IDENTIDADES ----------

local function get_local_identities(git_root)
  local output = vim.fn.system('cd ' .. vim.fn.shellescape(git_root) .. ' && git bug user show 2>/dev/null')
  if vim.v.shell_error ~= 0 then return {}, nil end
  local identities = {}
  local active_short = nil
  for line in output:gmatch '[^\r\n]+' do
    local short_id, name = line:match '^([%x]+)%s+(.+)$'
    if short_id and name then table.insert(identities, { short_id = short_id, name = name }) end
    if not active_short then active_short = short_id end
  end
  return identities, active_short
end

local function create_local_identity(git_root)
  local cmd = 'cd ' .. vim.fn.shellescape(git_root) .. ' && export EDITOR=nvim; git bug user new'
  vim.cmd('split | terminal bash -c "' .. cmd .. "; echo; echo '--- PROCESSO CONCLUÍDO. PRESSIONE ENTER PARA SAIR ---'; read\"")
end

local function ensure_repo_has_identity(git_root)
  local locals, _ = get_local_identities(git_root)
  if #locals > 0 then return true end

  vim.notify('Nenhuma identidade local encontrada. Por favor, crie uma identidade antes de prosseguir.', vim.log.levels.WARN)
  return false
end

-- ---------- BRIDGE (USANDO bridge auth) ----------
local function has_github_bridge(git_root)
  local cmd = 'cd ' .. vim.fn.shellescape(git_root) .. ' && git bug bridge auth'
  local output = vim.fn.system(cmd)
  -- Se a saída contiver "github", a bridge existe
  return output:match 'github' ~= nil
end

local function auto_configure_bridge(git_root)
  if has_github_bridge(git_root) then
    vim.notify('Git Bug: Autenticação GitHub já configurada.', vim.log.levels.INFO)
    return true
  end

  local token = vim.fn.system('gh auth token 2>/dev/null'):gsub('%s+', '')
  if token == '' then
    vim.notify('Git Bug: Token do gh não encontrado. Execute "gh auth login".', vim.log.levels.WARN)
    return false
  end

  local repo_url = vim.fn.system('cd ' .. vim.fn.shellescape(git_root) .. ' && git remote get-url origin 2>/dev/null'):gsub('%s+', '')
  local owner, project = repo_url:match 'github.com[:/]([^/]+)/([^/]+)%.git$'
  if not owner then
    owner, project = repo_url:match 'github.com[:/]([^/]+)/(.+)$'
  end
  if not owner or not project then
    vim.notify('Git Bug: Não foi possível extrair owner/project do remote origin.', vim.log.levels.WARN)
    return false
  end

  -- Comando com redirecionamento de stderr
  local cmd = string.format(
    'cd %s && git bug bridge new --name default --target github --owner %s --project %s --token %s --non-interactive 2>&1',
    vim.fn.shellescape(git_root),
    owner,
    project,
    token
  )
  local output = vim.fn.system(cmd)

  if vim.v.shell_error == 0 then
    vim.notify('Git Bug: Bridge GitHub configurada automaticamente!', vim.log.levels.INFO)
    return true
  else
    vim.notify('Git Bug: Falha ao configurar bridge:\n' .. output, vim.log.levels.ERROR)
    return false
  end
end

-- =============================================================================
-- MENU DE IDENTIDADES (<leader>gu)
-- =============================================================================

vim.keymap.set('n', '<leader>gu', function()
  local cwd = get_working_dir()
  local git_root = get_git_root(cwd)

  if not git_root then
    vim.notify('Você não está em um repositório Git.', vim.log.levels.ERROR)
    return
  end

  local locals, active_short = get_local_identities(git_root)
  local items = {}

  -- Cabeçalho: identidade ativa
  if active_short then
    local active_name = nil
    for _, ident in ipairs(locals) do
      if ident.short_id == active_short then
        active_name = ident.name
        break
      end
    end
    table.insert(items, {
      display = string.format('⭐ Ativa: %s (%s…)', active_name or 'desconhecida', active_short),
      action = 'header',
    })
  else
    table.insert(items, { display = '⚠️ Nenhuma identidade ativa', action = 'header' })
  end
  table.insert(items, { display = '---', action = 'separator' })

  -- Lista de identidades locais
  table.insert(items, { display = '📂 IDENTIDADES LOCAIS', action = 'header' })
  for _, ident in ipairs(locals) do
    local marker = (active_short == ident.short_id) and '✓' or ' '
    table.insert(items, {
      display = string.format('  %s %s (%s…)', marker, ident.name, ident.short_id),
      short_id = ident.short_id,
      action = 'use_local',
    })
  end

  -- Opção de criar nova identidade
  table.insert(items, { display = '[+] Criar nova identidade local', action = 'create_local' })

  vim.ui.select(items, {
    prompt = 'Gerenciar identidades Git-Bug',
    format_item = function(item) return item.display end,
  }, function(choice)
    if not choice then return end

    if choice.action == 'create_local' then
      create_local_identity(git_root)
    elseif choice.action == 'use_local' then
      vim.ui.select({ 'Sim', 'Não' }, {
        prompt = 'Tornar esta a identidade ativa?',
      }, function(confirm)
        if confirm == 'Sim' then
          if adopt_identity_in_repo(git_root, choice.short_id) then
            vim.notify('Identidade ativa alterada com sucesso!', vim.log.levels.INFO)
          else
            vim.notify('Falha ao alterar identidade.', vim.log.levels.ERROR)
          end
        end
      end)
    end
  end)
end, { desc = 'Git Bug: Gerenciar identidades' })

-- =============================================================================
-- DEMAIS ATALHOS
-- =============================================================================

-- Configurar remote do GitHub e sincronizar (mixed reset)
vim.keymap.set('n', '<leader>gr', function()
  local cwd = get_working_dir()
  local git_root = get_git_root(cwd)

  if not git_root then
    vim.ui.select({ 'Sim', 'Não' }, {
      prompt = 'Você não está em um repositório Git. Deseja inicializar um agora?',
    }, function(choice)
      if choice == 'Sim' then
        local init_cmd = 'cd ' .. vim.fn.shellescape(cwd) .. ' && git init'
        nvim_term_exec(init_cmd, cwd, false, true)
        vim.notify('Repositório Git inicializado. Execute <leader>gr novamente.', vim.log.levels.INFO)
      end
    end)
    return
  end

  if vim.fn.executable 'gh' ~= 1 then
    vim.notify('GitHub CLI (gh) não está instalado.\nInstale com: sudo pacman -S github-cli (Arch) ou https://cli.github.com', vim.log.levels.ERROR)
    return
  end

  local auth_status = vim.fn.system 'gh auth status 2>&1'
  if auth_status:match 'not logged in' or auth_status:match 'Você não está logado' then
    vim.ui.select({ 'Sim', 'Não' }, {
      prompt = 'Você não está autenticado no GitHub CLI. Deseja fazer login agora?',
    }, function(choice)
      if choice == 'Sim' then vim.cmd 'split | terminal gh auth login' end
    end)
    return
  end

  local username = vim.fn.system('gh api user --jq .login 2>/dev/null'):gsub('%s+', '')
  if username == '' then
    vim.notify('Não foi possível obter seu username do GitHub. Verifique sua autenticação com "gh auth status".', vim.log.levels.ERROR)
    return
  end

  local folder_name = vim.fn.fnamemodify(git_root, ':t')
  local repo_name = vim.fn.input('Nome do repositório no GitHub: ', folder_name)
  if repo_name == '' then
    vim.notify('Nome do repositório é obrigatório.', vim.log.levels.WARN)
    return
  end

  local existing_remote = vim.fn.system('cd ' .. vim.fn.shellescape(git_root) .. ' && git remote get-url origin 2>/dev/null'):gsub('%s+', '')
  local remote_url = 'https://github.com/' .. username .. '/' .. repo_name .. '.git'

  local cmd = string.format('cd %s && ', vim.fn.shellescape(git_root))
  if existing_remote ~= '' then
    vim.ui.select({ 'Sim, substituir', 'Não, cancelar' }, {
      prompt = string.format('Remote origin já existe (%s). Deseja substituí-lo por %s?', existing_remote, remote_url),
    }, function(choice)
      if choice == 'Sim, substituir' then
        local update_cmd = cmd .. string.format('git remote set-url origin %s; git fetch origin; git reset --mixed origin/master', remote_url)
        nvim_term_exec(update_cmd, git_root, false, true)
        vim.notify('Remote atualizado e sincronizado com origin/master.', vim.log.levels.INFO)
      end
    end)
  else
    local add_cmd = cmd .. string.format('git remote add origin %s; git fetch origin; git reset --mixed origin/master', remote_url)
    nvim_term_exec(add_cmd, git_root, false, true)
    vim.notify('Remote configurado e sincronizado com origin/master.', vim.log.levels.INFO)
  end
end, { desc = 'Git: Configurar remote (mixed reset)' })

-- Inicializar repositório (não requer identidade)
vim.keymap.set('n', '<leader>gi', function()
  local cwd = get_working_dir()
  local git_root = get_git_root(cwd)
  if not git_root then
    vim.notify('Fora de um repositório Git.', vim.log.levels.ERROR)
    return
  end
  local cmd = 'cd ' .. vim.fn.shellescape(git_root) .. ' && git init'
  nvim_term_exec(cmd, git_root, false, true)
end, { desc = 'Git: Init' })

vim.keymap.set('n', '<leader>gl', function()
  local cwd = get_working_dir()
  local git_root = get_git_root(cwd)

  if not git_root then
    vim.notify('Fora de um repositório Git.', vim.log.levels.ERROR)
    return
  end

  local locals, active_short = get_local_identities(git_root)
  if #locals == 0 then
    vim.notify(
      '👋 Parece que você ainda não tem um perfil de usuário neste repositório! Crie um em "<leader>gu" para acessar a interface.',
      vim.log.levels.INFO
    )
    return
  end

  -- Fallback: auto-adota a primeira identidade se o ambiente perdeu a referência
  if not active_short then adopt_identity_in_repo(git_root, locals[1].short_id) end

  clean_locks(git_root)

  if not kitty_float_exec('git bug termui', git_root) then
    vim.notify('Kitty remote indisponível, abrindo no terminal integrado...', vim.log.levels.WARN)
    nvim_term_exec('git bug termui', git_root, true, false)
  end
end, { desc = 'Git Bug: Interface TUI' })

vim.keymap.set('n', '<leader>gp', function()
  local cwd = get_working_dir()
  local git_root = get_git_root(cwd)

  if not git_root then
    vim.notify('Fora de um repositório Git.', vim.log.levels.ERROR)
    return
  end

  local locals, _ = get_local_identities(git_root)
  if #locals == 0 then
    vim.notify('👋 Identidade necessária. Crie uma com <leader>gu.', vim.log.levels.WARN)
    return
  end

  if not has_github_bridge(git_root) then
    vim.ui.select({ 'Sim', 'Não' }, {
      prompt = 'Bridge GitHub não configurada. Configurar agora?',
    }, function(choice)
      if choice == 'Sim' then
        if auto_configure_bridge(git_root) then vim.notify('Agora execute <leader>gp novamente.', vim.log.levels.INFO) end
      end
    end)
    return
  end

  -- Comando com redirecionamento de stderr
  local cmd = 'cd ' .. vim.fn.shellescape(git_root) .. ' && git bug bridge pull default && git bug bridge push default 2>&1'
  local output = vim.fn.system(cmd)

  if vim.v.shell_error == 0 then
    vim.notify('Sincronização concluída!\n' .. output, vim.log.levels.INFO)
  else
    vim.notify('Erro na sincronização:\n' .. output, vim.log.levels.ERROR)
  end
end, { desc = 'Git Bug: Push seguido de Pull' })

local function create_issue_floating()
  local cwd = get_working_dir()
  local git_root = get_git_root(cwd)
  if not git_root then
    vim.notify('Fora de um repositório Git.', vim.log.levels.ERROR)
    return
  end
  if not ensure_repo_has_identity(git_root) then return end

  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.6)
  local opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2 - 2,
    style = 'minimal',
    border = 'rounded',
    title = ' Nova Issue (Git Bug) ',
    title_pos = 'center',
  }
  local win = vim.api.nvim_open_win(buf, true, opts)

  local lines = {
    '# Título (obrigatório)',
    '',
    '# Descrição (opcional)',
    '',
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = 'acwrite'
  vim.bo[buf].filetype = 'markdown'

  local function submit()
    local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local title = nil
    local desc_lines = {}
    local in_desc = false

    for _, line in ipairs(content) do
      if line:match '^# Título' then
      elseif not title and not in_desc and line:match '^%s*$' then
      elseif not title and not in_desc then
        title = line:match '^%s*(.-)%s*$'
      elseif line:match '^# Descrição' then
        in_desc = true
      elseif in_desc and not line:match '^%s*$' then
        table.insert(desc_lines, line)
      end
    end

    if not title or title == '' then
      vim.notify('Título é obrigatório', vim.log.levels.WARN)
      return
    end

    local desc = table.concat(desc_lines, '\n')
    vim.api.nvim_win_close(win, true)

    local cmd = string.format('git bug bug new -t %s -m %s', vim.fn.shellescape(title), vim.fn.shellescape(desc))
    local full_cmd = string.format('cd %s && %s', vim.fn.shellescape(git_root), cmd)

    vim.notify('Criando issue...', vim.log.levels.INFO)
    vim.fn.jobstart(full_cmd, {
      on_exit = function(_, code)
        if code == 0 then
          vim.schedule(function() vim.notify('Issue criada com sucesso!', vim.log.levels.INFO) end)
        else
          vim.schedule(function() vim.notify('Erro ao criar issue. Verifique o terminal.', vim.log.levels.ERROR) end)
        end
      end,
    })
  end

  vim.keymap.set('n', '<CR>', submit, { buffer = buf })
  vim.keymap.set('n', '<C-s>', submit, { buffer = buf })
  vim.keymap.set('n', 'q', function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
  vim.keymap.set('i', '<C-s>', submit, { buffer = buf })
  vim.api.nvim_win_set_cursor(win, { 2, 0 })
  vim.cmd 'startinsert'
end
vim.keymap.set('n', '<leader>ga', create_issue_floating, { desc = 'Git Bug: Nova Issue (flutuante)' })

vim.keymap.set('n', '<leader>gz', function()
  local cwd = get_working_dir()
  local git_root = get_git_root(cwd)
  if not git_root then
    vim.notify('Fora de um repositório Git.', vim.log.levels.ERROR)
    return
  end
  auto_configure_bridge(git_root)
end, { desc = 'Git Bug: Configurar bridge (gh)' })

-- Gerenciar keyrings do git-bug (limpar todas ou selecionar específica)
vim.keymap.set('n', '<leader>gk', function()
  local keyring_dir = vim.fn.expand '~/.config/git-bug/keyring'

  if vim.fn.isdirectory(keyring_dir) ~= 1 then
    vim.notify('Diretório keyring não encontrado.', vim.log.levels.INFO)
    return
  end

  -- Lista os arquivos/pastas dentro do keyring
  local items = vim.fn.readdir(keyring_dir)

  local menu_items = {
    { display = '[✕] Apagar TODAS as keyrings', action = 'all' },
    { display = '---', action = 'separator' },
  }

  -- Adiciona cada keyring encontrada ao menu
  for _, name in ipairs(items) do
    table.insert(menu_items, {
      display = string.format('[✕] %s', name),
      name = name,
      action = 'single',
    })
  end

  vim.ui.select(menu_items, {
    prompt = 'Gerenciar keyrings do git-bug',
    format_item = function(item) return item.display end,
  }, function(choice)
    if not choice then return end

    if choice.action == 'all' then
      vim.ui.select({ 'Sim', 'Não' }, {
        prompt = 'Apagar TODAS as keyrings? Isso pode resolver bridges corrompidas.',
      }, function(confirm)
        if confirm == 'Sim' then
          local ok = os.execute('rm -rf ' .. vim.fn.shellescape(keyring_dir) .. '/* 2>/dev/null')
          if ok == 0 then
            vim.notify('Todas as keyrings foram apagadas.', vim.log.levels.INFO)
            vim.notify('Execute <leader>gz para reconfigurar a bridge.', vim.log.levels.INFO)
          else
            vim.notify('Falha ao apagar as keyrings.', vim.log.levels.ERROR)
          end
        end
      end)
    elseif choice.action == 'single' then
      vim.ui.select({ 'Sim', 'Não' }, {
        prompt = string.format('Apagar keyring "%s"?', choice.name),
      }, function(confirm)
        if confirm == 'Sim' then
          local filepath = keyring_dir .. '/' .. choice.name
          local ok = os.execute('rm -rf ' .. vim.fn.shellescape(filepath) .. ' 2>/dev/null')
          if ok == 0 then
            vim.notify('Keyring "' .. choice.name .. '" apagada.', vim.log.levels.INFO)
          else
            vim.notify('Falha ao apagar keyring.', vim.log.levels.ERROR)
          end
        end
      end)
    end
  end)
end, { desc = 'Git Bug: Gerenciar keyrings' })
