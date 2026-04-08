local fn = vim.fn
local api = vim.api

local quarto_group = api.nvim_create_augroup("QuartoShadowSync", { clear = true })
local shadow_root = "/tmp/nvim_quarto_shadow"
fn.mkdir(shadow_root, "p")

-- =========================================================================
--  Gerenciamento do YAML (frontmatter) do buffer
-- =========================================================================
local function get_yaml_range(bufnr)
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if lines[1] ~= "---" then return nil end
  for i = 2, #lines do
    if lines[i] == "---" then return 1, i end
  end
  return nil
end

local function parse_yaml_config(bufnr)
  local start, finish = get_yaml_range(bufnr)
  if not start then return {} end
  local lines = api.nvim_buf_get_lines(bufnr, start, finish, false)
  local config = {}
  for _, line in ipairs(lines) do
    local key, value = line:match("^(quarto_[%w_]+):%s*(.*)$")
    if key then
      if value == "true" then config[key] = true
      elseif value == "false" then config[key] = false
      elseif value:match("^%[.*%]$") then
        -- lista simples: [a, b, c]
        local items = {}
        for item in value:gmatch("%[?([^,%[%]]+)%]?") do
          local clean = item:match("^%s*(.-)%s*$")
          if clean and clean ~= "" then table.insert(items, clean) end
        end
        config[key] = items
      else
        config[key] = value
      end
    end
  end
  return config
end

local function update_yaml_config(bufnr, updates)
  local start, finish = get_yaml_range(bufnr)
  if not start then
    -- Cria frontmatter se não existir
    api.nvim_buf_set_lines(bufnr, 0, 0, false, { "---", "---" })
    start, finish = 0, 1
  end
  local lines = api.nvim_buf_get_lines(bufnr, start, finish, false)
  local new_lines = {}
  local seen = {}
  for _, line in ipairs(lines) do
    local key = line:match("^(quarto_[%w_]+):")
    if key and updates[key] ~= nil then
      seen[key] = true
      local val = updates[key]
      if type(val) == "boolean" then
        table.insert(new_lines, key .. ": " .. tostring(val))
      elseif type(val) == "table" then
        table.insert(new_lines, key .. ": [" .. table.concat(val, ", ") .. "]")
      else
        table.insert(new_lines, key .. ": " .. tostring(val))
      end
    else
      table.insert(new_lines, line)
    end
  end
  for k, v in pairs(updates) do
    if not seen[k] then
      if type(v) == "boolean" then
        table.insert(new_lines, k .. ": " .. tostring(v))
      elseif type(v) == "table" then
        table.insert(new_lines, k .. ": [" .. table.concat(v, ", ") .. "]")
      else
        table.insert(new_lines, k .. ": " .. tostring(v))
      end
    end
  end
  api.nvim_buf_set_lines(bufnr, start, finish, false, new_lines)
end

-- =========================================================================
--  Configuração do buffer (cache + YAML)
-- =========================================================================
local buffer_config_cache = {}  -- [bufnr] = tabela de configuração

local default_config = {
  quarto_id = nil,
  quarto_comp_nativa = false,
  quarto_modo_escrita = false,
  quarto_usar_local_fisico = false,
  quarto_ignorar_ativos = false,
  quarto_gerais = {},
  quarto_extensoes = {},
}

local function get_buffer_config(bufnr)
  if buffer_config_cache[bufnr] then
    return buffer_config_cache[bufnr]
  end
  local yaml = parse_yaml_config(bufnr)
  local config = vim.tbl_deep_extend("force", {}, default_config, yaml)
  -- Converte listas para sets para facilitar manipulação
  local gerais_set = {}
  for _, name in ipairs(config.quarto_gerais or {}) do gerais_set[name] = true end
  local extensoes_set = {}
  for _, name in ipairs(config.quarto_extensoes or {}) do extensoes_set[name] = true end
  config.quarto_gerais = gerais_set
  config.quarto_extensoes = extensoes_set
  buffer_config_cache[bufnr] = config
  return config
end

local function save_buffer_config(bufnr)
  local config = buffer_config_cache[bufnr]
  if not config then return end
  local updates = {
    quarto_id = config.quarto_id,
    quarto_comp_nativa = config.quarto_comp_nativa,
    quarto_modo_escrita = config.quarto_modo_escrita,
    quarto_usar_local_fisico = config.quarto_usar_local_fisico,
    quarto_ignorar_ativos = config.quarto_ignorar_ativos,
    quarto_gerais = vim.tbl_keys(config.quarto_gerais),
    quarto_extensoes = vim.tbl_keys(config.quarto_extensoes),
  }
  update_yaml_config(bufnr, updates)
end

-- Gera ou recupera ID persistente
local function ensure_buffer_id(bufnr)
  local config = get_buffer_config(bufnr)
  if not config.quarto_id then
    local buf_name = api.nvim_buf_get_name(bufnr)
    local base = buf_name ~= "" and buf_name or tostring(os.time())
    config.quarto_id = fn.sha256(base .. os.time()):sub(1, 8)
    save_buffer_config(bufnr)
  end
  return config.quarto_id
end

-- =========================================================================
--  UI Helpers
-- =========================================================================
local function open_menu(title, lines, width_offset)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local width = width_offset or 75
  local height = math.max(8, math.min(#lines + 2, math.floor(vim.o.lines * 0.8)))
  local opts = {
    relative = "editor", width = width, height = height,
    col = (vim.o.columns - width) / 2, row = (vim.o.lines - height) / 2,
    style = "minimal", border = "rounded",
    title = " " .. title .. " ", title_pos = "center"
  }
  local win = api.nvim_open_win(buf, true, opts)
  vim.wo[win].winhl = "Normal:Normal,FloatBorder:FloatBorder"
  vim.keymap.set("n", "q", "<cmd>q<CR>", { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", "<cmd>q<CR>", { buffer = buf, silent = true, nowait = true })
  return buf, win
end

local function open_log_view(path)
  if fn.filereadable(path) == 1 then
    vim.cmd("vsplit " .. fn.fnameescape(path))
    local log_buf = api.nvim_get_current_buf()
    local log_win = api.nvim_get_current_win()
    vim.cmd("normal! G")
    vim.bo[log_buf].buflisted = false
    vim.bo[log_buf].buftype = "nofile"
    vim.bo[log_buf].bufhidden = "wipe"
    local close_log = function()
      if api.nvim_win_is_valid(log_win) then api.nvim_win_close(log_win, true) end
    end
    vim.keymap.set("n", "q", close_log, { buffer = log_buf, silent = true })
    vim.keymap.set("n", "<C-x>", close_log, { buffer = log_buf, silent = true })
  else
    vim.notify("Log não encontrado: " .. path, vim.log.levels.WARN)
  end
end

-- =========================================================================
--  Shadow Sync
-- =========================================================================
local function get_shadow_info(bufnr)
  local buf_name = api.nvim_buf_get_name(bufnr)
  if buf_name == "" then return nil end
  local name = fn.fnamemodify(buf_name, ":t")
  local id = ensure_buffer_id(bufnr)
  local work_dir = shadow_root .. "/" .. id
  fn.mkdir(work_dir, "p")
  return { dir = work_dir, path = work_dir .. "/" .. name }
end

local function update_shadow_from_buffer(bufnr)
  local info = get_shadow_info(bufnr)
  if not info then return nil end
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  fn.writefile(lines, info.path)
  return info
end

-- =========================================================================
--  Sincronização de Ativos (Gerais e Extensões)
-- =========================================================================
local function sync_assets(target_dir, config)
  if config.quarto_ignorar_ativos then return end
  -- Gerais
  if config.quarto_gerais and next(config.quarto_gerais) then
    local gdir = fn.expand("~/Documents/Quarto/Gerais")
    for name, active in pairs(config.quarto_gerais) do
      if active then
        local src = gdir .. "/" .. name
        if fn.isdirectory(src) == 1 or fn.filereadable(src) == 1 then
          fn.system({ "cp", "-r", src, target_dir .. "/" })
        end
      end
    end
  end
  -- Extensões
  if config.quarto_extensoes and next(config.quarto_extensoes) then
    local edir = fn.expand("~/Documents/Quarto/Extens")
    local ext_dest = target_dir .. "/_extensions"
    fn.mkdir(ext_dest, "p")
    for name, active in pairs(config.quarto_extensoes) do
      if active then
        local src = edir .. "/" .. name
        if fn.isdirectory(src) == 1 then
          fn.system({ "cp", "-r", src, ext_dest .. "/" })
        end
      end
    end
  end
end

-- =========================================================================
--  Extração de Blocos
-- =========================================================================
local function get_code_blocks(bufnr)
  local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local blocks, in_block, block_start, block_lang, block_lines, eval_enabled = {}, false, 0, "", {}, true
  for i, line in ipairs(lines) do
    if not in_block then
      local lang = line:match("^```{%s*([^%s,}]+)")
      if lang then
        in_block, block_start, block_lang, block_lines, eval_enabled = true, i, lang, {}, true
      end
    else
      if line:match("^```$") then
        table.insert(blocks, { start = block_start, finish = i, lang = block_lang, lines = block_lines, eval = eval_enabled })
        in_block = false
      else
        if line:match("^#|%s*eval:%s*false") then eval_enabled = false
        elseif not line:match("^#|") then table.insert(block_lines, line) end
      end
    end
  end
  return blocks
end

-- =========================================================================
--  Preview State
-- =========================================================================
local preview_state = { job = nil, port = 4444, url = nil, mode = nil, bufnr = nil, config = nil }

local function stop_preview()
  if preview_state.job then pcall(vim.fn.jobstop, preview_state.job); preview_state.job = nil end
  fn.system("pkill -f 'quarto preview'")
  preview_state.mode = nil
end

local function start_preview(shadow_info, file_path, fmt, compile, config)
  stop_preview()
  local cmd = compile
    and string.format("quarto preview %s --to %s --port %d --no-browser", fn.shellescape(file_path), fn.shellescape(fmt), preview_state.port)
    or  string.format("quarto preview %s --to %s --port %d --no-browser --no-execute --no-watch", fn.shellescape(file_path), fn.shellescape(fmt), preview_state.port)
  preview_state.mode = compile and "compile" or "fast"
  preview_state.bufnr = api.nvim_get_current_buf()
  preview_state.config = config

  vim.notify("Iniciando preview (" .. preview_state.mode .. ")...", vim.log.levels.INFO)
  preview_state.job = fn.jobstart({ "bash", "-c", cmd }, {
    cwd = shadow_info.dir,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line:match("http://localhost:" .. preview_state.port) then
            preview_state.url = line:match("(http://localhost:%d+/[^%s]*)")
          end
        end
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and code ~= 143 then
        vim.schedule(function()
          vim.notify("Preview falhou. Abrindo log...", vim.log.levels.ERROR)
          open_log_view(shadow_info.dir .. "/preview.log")
        end)
      end
      preview_state.job = nil
    end,
  })
  vim.defer_fn(function()
    fn.jobstart({ "xdg-open", preview_state.url or ("http://localhost:" .. preview_state.port) })
  end, 2000)
end

local function refresh_preview()
  if not preview_state.job then vim.notify("Nenhum preview ativo.", vim.log.levels.WARN); return end
  local bufnr = preview_state.bufnr
  if not api.nvim_buf_is_valid(bufnr) then vim.notify("Buffer original não disponível.", vim.log.levels.ERROR); return end
  local info = update_shadow_from_buffer(bufnr)
  if info then fn.system("touch " .. fn.shellescape(info.path)); vim.notify("Preview atualizado.", vim.log.levels.INFO) end
end

-- =========================================================================
--  Comando :Quarto
-- =========================================================================
local function quarto_handler(args)
  local bufnr = api.nvim_get_current_buf()
  local original_path = api.nvim_buf_get_name(bufnr)
  if original_path == "" then vim.notify("Salve o arquivo primeiro.", vim.log.levels.ERROR); return end

  local config = get_buffer_config(bufnr)
  local fargs = args.fargs
  local flag = fargs[1]

  if #fargs == 0 or flag == "-h" then
    open_menu("Quarto - Ajuda", {
      " :Quarto -p [-c] [-s] [fmt]   → Preview (rápido/compilado)",
      " :Quarto -r                  → Atualizar preview",
      " :Quarto -k                  → Parar preview",
      " :Quarto -c [-s] [fmt]       → Renderizar final",
      " :Quarto -b                  → Executar bloco",
      " :Quarto -l                  → Logs",
      " :Quarto -m                  → Configurações",
      "", " q para fechar"
    }, 75)
    return
  end

  -- Atualiza shadow (exceto para comandos que não precisam)
  local shadow_info = update_shadow_from_buffer(bufnr)
  if not shadow_info then return end

  local filename_with_ext = fn.fnamemodify(original_path, ":t")
  local filename_no_ext = fn.fnamemodify(original_path, ":t:r")

  if flag == "-r" then refresh_preview(); return end
  if flag == "-k" then stop_preview(); vim.notify("Preview parado.", vim.log.levels.INFO); return end
  if flag == "-l" then
    local preview_log = shadow_info.dir .. "/preview.log"
    local render_log = shadow_info.dir .. "/render.log"
    vim.ui.select({ "Preview", "Render" }, { prompt = "Ver log de:" }, function(choice)
      if choice == "Preview" then open_log_view(preview_log) elseif choice == "Render" then open_log_view(render_log) end
    end)
    return
  end

  if flag == "-p" then
    local compile, force_save, fmt = false, false, "html"
    for i = 2, #fargs do
      if fargs[i] == "-c" then compile = true
      elseif fargs[i] == "-s" then force_save = true
      else fmt = fargs[i] end
    end
    sync_assets(shadow_info.dir, config)
    start_preview(shadow_info, filename_with_ext, fmt, compile, config)
    if force_save then
      vim.defer_fn(function()
        -- salvamento forçado (implementação simplificada)
        vim.notify("Force save não implementado para preview.", vim.log.levels.WARN)
      end, 3000)
    end
    return
  end

  if flag == "-c" then
    local force_save, fmt = false, "pdf"
    for i = 2, #fargs do
      if fargs[i] == "-s" then force_save = true else fmt = fargs[i] end
    end
    vim.notify("Renderizando " .. fmt .. "...", vim.log.levels.INFO)

    local compile_dir
    if config.quarto_usar_local_fisico then
      compile_dir = fn.fnamemodify(original_path, ":p:h")
      -- usa o arquivo original diretamente (sem shadow)
      vim.cmd("silent! write")
    else
      compile_dir = shadow_info.dir
    end
    sync_assets(compile_dir, config)

    local render_log = compile_dir .. "/render.log"
    local log_lines = { "=== Render Log === " .. os.date(), "" }
    local function capture(_, data)
      if data then for _, l in ipairs(data) do if l ~= "" then table.insert(log_lines, l) end end end
    end

    local cmd_args = { "quarto", "render", filename_with_ext, "--to", fmt }
    fn.jobstart(cmd_args, {
      cwd = compile_dir,
      on_stdout = capture, on_stderr = capture,
      on_exit = function(_, code)
        fn.writefile(log_lines, render_log)
        if code == 0 or force_save then
          if code == 0 then vim.notify("Render concluído.", vim.log.levels.INFO)
          else vim.notify("Render com erro, mas forçado.", vim.log.levels.WARN) end
          local out_ext = (fmt == "latex" and "tex") or fmt
          local out_file = compile_dir .. "/" .. filename_no_ext .. "." .. out_ext
          if fn.filereadable(out_file) == 1 then fn.jobstart({ "xdg-open", out_file }) end
          -- Se não era local físico e comp_nativa true, copia para original
          if not config.quarto_usar_local_fisico and config.quarto_comp_nativa then
            local dest = fn.fnamemodify(original_path, ":p:h") .. "/" .. fn.fnamemodify(out_file, ":t")
            fn.system({ "cp", out_file, dest })
          end
        else
          vim.schedule(function() vim.notify("Erro na renderização. Abrindo log...", vim.log.levels.ERROR); open_log_view(render_log) end)
        end
      end
    })
    return
  end

  if flag == "-b" then
    local blocks = get_code_blocks(bufnr)
    if #blocks == 0 then vim.notify("Nenhum bloco.", vim.log.levels.WARN); return end
    local items = {}
    for i, blk in ipairs(blocks) do
      local preview = table.concat(blk.lines, " "):sub(1, 40)
      table.insert(items, string.format("%d. [%s] %s: %s...", i, blk.eval and "✓" or "✗", blk.lang, preview))
    end
    vim.ui.select(items, { prompt = "Executar bloco:" }, function(_, idx)
      if not idx then return end
      local code = table.concat(blocks[idx].lines, "\n")
      local ok, slime = pcall(require, "slime")
      if ok then slime.send(code); vim.notify("Enviado para REPL.", vim.log.levels.INFO)
      else fn.setreg("+", code); vim.notify("Copiado para clipboard.", vim.log.levels.WARN) end
    end)
    return
  end

  if flag == "-m" then
    local lines = {
      " === Configurações (salvas no YAML) ===",
      " 1. Compilação Nativa: " .. tostring(config.quarto_comp_nativa),
      " 2. Modo Escrita: " .. tostring(config.quarto_modo_escrita),
      " 3. Usar Local Físico (render): " .. tostring(config.quarto_usar_local_fisico),
      " 4. Ignorar Ativos: " .. tostring(config.quarto_ignorar_ativos),
      " 5. Ativos Gerais",
      " 6. Extensões",
      " 7. Templates",
      "", " Pressione o número"
    }
    local buf, win = open_menu("Configurações", lines, 75)
    local function update_line(idx, key)
      lines[idx] = string.format(" %d. %s: %s", idx, key:gsub("quarto_", ""):gsub("_", " "), tostring(config[key]))
      api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end
    local function toggle(key, idx)
      config[key] = not config[key]
      update_line(idx, key)
      save_buffer_config(bufnr)
    end
    vim.keymap.set("n", "1", function() toggle("quarto_comp_nativa", 1) end, { buffer = buf })
    vim.keymap.set("n", "2", function() toggle("quarto_modo_escrita", 2) end, { buffer = buf })
    vim.keymap.set("n", "3", function() toggle("quarto_usar_local_fisico", 3) end, { buffer = buf })
    vim.keymap.set("n", "4", function() toggle("quarto_ignorar_ativos", 4) end, { buffer = buf })
    vim.keymap.set("n", "5", function()
      local gdir = fn.expand("~/Documents/Quarto/Gerais"); fn.mkdir(gdir, "p")
      local items = fn.readdir(gdir)
      local g_lines = { " === Gerais (ENTER para toggle) ===" }
      for _, name in ipairs(items) do
        table.insert(g_lines, (config.quarto_gerais[name] and "[X]" or "[ ]") .. " " .. name)
      end
      local gbuf, gwin = open_menu("Gerais", g_lines, 60)
      vim.keymap.set("n", "<CR>", function()
        local idx = api.nvim_win_get_cursor(gwin)[1] - 1
        if idx > 0 and idx <= #items then
          local name = items[idx]
          config.quarto_gerais[name] = not config.quarto_gerais[name]
          g_lines[idx+1] = (config.quarto_gerais[name] and "[X]" or "[ ]") .. " " .. name
          api.nvim_buf_set_lines(gbuf, 0, -1, false, g_lines)
          save_buffer_config(bufnr)
        end
      end, { buffer = gbuf })
    end, { buffer = buf })
    vim.keymap.set("n", "6", function()
      local edir = fn.expand("~/Documents/Quarto/Extens"); fn.mkdir(edir, "p")
      local items = fn.readdir(edir)
      local e_lines = { " === Extensões (ENTER para toggle) ===" }
      for _, name in ipairs(items) do
        table.insert(e_lines, (config.quarto_extensoes[name] and "[X]" or "[ ]") .. " " .. name)
      end
      local ebuf, ewin = open_menu("Extensões", e_lines, 60)
      vim.keymap.set("n", "<CR>", function()
        local idx = api.nvim_win_get_cursor(ewin)[1] - 1
        if idx > 0 and idx <= #items then
          local name = items[idx]
          config.quarto_extensoes[name] = not config.quarto_extensoes[name]
          e_lines[idx+1] = (config.quarto_extensoes[name] and "[X]" or "[ ]") .. " " .. name
          api.nvim_buf_set_lines(ebuf, 0, -1, false, e_lines)
          save_buffer_config(bufnr)
        end
      end, { buffer = ebuf })
    end, { buffer = buf })
    vim.keymap.set("n", "7", function()
      local tdir = fn.expand("~/Documents/Quarto/temp"); fn.mkdir(tdir, "p")
      local items = fn.readdir(tdir)
      local t_lines = { " === Templates ===" }
      for _, name in ipairs(items) do table.insert(t_lines, " -> " .. name) end
      local tbuf, twin = open_menu("Templates", t_lines, 60)
      vim.keymap.set("n", "<CR>", function()
        local idx = api.nvim_win_get_cursor(twin)[1] - 1
        if idx > 0 and idx <= #items then
          local name = items[idx]
          local action = vim.fn.confirm("Usar template?", "&Usar\n&Copiar\nCancelar")
          if action == 1 then
            local content = fn.readfile(tdir .. "/" .. name)
            api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
            vim.notify("Buffer substituído.", vim.log.levels.INFO); vim.cmd("q")
          elseif action == 2 then
            fn.setreg("+", table.concat(fn.readfile(tdir .. "/" .. name), "\n"))
            vim.notify("Copiado.", vim.log.levels.INFO)
          end
        end
      end, { buffer = tbuf })
    end, { buffer = buf })
    return
  end

  vim.notify("Comando desconhecido. Use :Quarto -h", vim.log.levels.WARN)
end

api.nvim_create_user_command("Quarto", quarto_handler, { nargs = "*" })

-- =========================================================================
--  Atalhos which-key
-- =========================================================================
local function setup_which_key()
  local ok, wk = pcall(require, "which-key")
  if not ok then return end
  wk.add({
    { "<leader>qh", "<cmd>Quarto -h<CR>", desc = "Ajuda Quarto" },
    { "<leader>qp", group = "Preview" },
    { "<leader>qpf", "<cmd>Quarto -p html<CR>", desc = "Rápido HTML" },
    { "<leader>qpc", "<cmd>Quarto -p -c pdf<CR>", desc = "Compilado PDF" },
    { "<leader>qph", "<cmd>Quarto -p -c html<CR>", desc = "Compilado HTML" },
    { "<leader>qr", "<cmd>Quarto -r<CR>", desc = "Atualizar preview" },
    { "<leader>qk", "<cmd>Quarto -k<CR>", desc = "Parar preview" },
    { "<leader>qc", group = "Renderizar" },
    { "<leader>qcp", "<cmd>Quarto -c pdf<CR>", desc = "PDF" },
    { "<leader>qch", "<cmd>Quarto -c html<CR>", desc = "HTML" },
    { "<leader>qb", "<cmd>Quarto -b<CR>", desc = "Executar bloco" },
    { "<leader>qm", "<cmd>Quarto -m<CR>", desc = "Configurações" },
    { "<leader>ql", "<cmd>Quarto -l<CR>", desc = "Ver logs" },
  })
end

-- =========================================================================
--  Autocmds
-- =========================================================================
api.nvim_create_autocmd("InsertLeave", {
  group = quarto_group, pattern = { "*.qmd", "*.md" },
  callback = function(ev)
    if preview_state.mode == "fast" and preview_state.bufnr == ev.buf then refresh_preview()
    else update_shadow_from_buffer(ev.buf) end
  end,
})

api.nvim_create_autocmd("BufWritePost", {
  group = quarto_group, pattern = { "*.qmd", "*.md" },
  callback = function(ev) update_shadow_from_buffer(ev.buf) end,
})

api.nvim_create_autocmd("VimLeavePre", { group = quarto_group, callback = stop_preview })

vim.schedule(setup_which_key)
