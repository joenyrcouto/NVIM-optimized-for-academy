

-- keymap to source this file again
vim.keymap.set('n', '<leader>ks', function()
  local mod = 'utils.keys'
  if package.loaded[mod] then
    package.loaded[mod] = nil
  end
  require(mod)
end, { desc = 'Reload key mappings' })


local win = 0

local x = vim.api.nvim_win_get_position(win)

vim.print(x)



