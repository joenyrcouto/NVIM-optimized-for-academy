---@module 'utils.term'
local M = {
  ---Map of buffers to a terminals
  ---@type table<integer, Terminal>
  buf_term_map = {},
}

---A terminal has a buffer number, a type and a channel id
---@class Terminal
---@field bufnr integer
---@field type string?
---@field channel_id integer

---Get the channel id of a terminal buffer
---@param bufnr integer
---@return integer|nil
local function get_channel_id(bufnr)
  return vim.api.nvim_get_option_value('channel', { buf = bufnr })
end

---Get the type of the terminal buffer
---like ipython, R, bash, etc.
---based on the buffer name
---@param buf integer
---@return string|nil
local function get_term_type(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  local term_type = name:match 'term://.*/%d+:(.*)'
  if not term_type then
    return nil
  end
  -- drop flags like --no-confirm-exit
  term_type = term_type:match '([^%s]+)'
  -- drop the path to the executable
  term_type = term_type:match '([^/]+)$'
  return term_type
end

---Find nvim terminal buffers
local function list_terminals()
  local terms = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_option_value('buftype', { buf = buf }) == 'terminal' then
      local chan_id = get_channel_id(buf)
      if not chan_id then
        goto continue
      end
      ---@type Terminal
      local term = {
        bufnr = buf,
        type = get_term_type(buf),
        channel_id = chan_id,
      }
      table.insert(terms, term)
    end
    ::continue::
  end
  return terms
end

---For ipython sending
local cpaste_start = '%cpaste -q\n'
local cpaste_end = '--\n'
local cpaste_pause = 10

---Send lines to a terminal
---@param lines string[]
---@param term Terminal
---@return nil
local send_lines = function(lines, term)
  local chan_id = term.channel_id
  local text = table.concat(lines, '\n') .. '\n'
  if term.type == 'ipython' then
    vim.fn.chansend(chan_id, cpaste_start)
    vim.uv.sleep(cpaste_pause)
  end
  vim.fn.chansend(chan_id, text)
  if term.type == 'ipython' then
    vim.fn.chansend(chan_id, cpaste_end)
  end
end

local s = [[
print("hello world!")
def hello():
  print("hello")
hello()
]]

local ls = { s }

---Connect current buffer to a terminal
local connect = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local terms = list_terminals()
  vim.ui.select(terms, {
    prompt = 'Select terminal',
    format_item = function(item)
      return item.type .. ' ' .. item.bufnr
    end,
  }, function(choice)
    if choice == nil then
      return
    end
    M.buf_term_map[bufnr] = choice
  end)
end

M.send = function(lines)
  local bufnr = vim.api.nvim_get_current_buf()
  local term = M.buf_term_map[bufnr]
  if not term then
    connect()
    return
  end
  send_lines(lines, term)
  -- scroll to the bottom
  local term_win = vim.fn.bufwinid(term.bufnr)
  local n = vim.api.nvim_buf_line_count(term.bufnr)
  vim.api.nvim_win_set_cursor(term_win, { n, 0 })
end

M.send_visual = function()
  -- get the selected text
  vim.cmd.normal { '"zy', bang = true }
  local selection = vim.fn.getreg 'z'
  M.send({ selection })
end

vim.keymap.set('v', '<CR>', function()
  M.send_visual()
end, { noremap = true, silent = true })

-- connect
vim.keymap.set('n', '<leader>ct', function()
  connect()
end, { noremap = true, silent = true })

