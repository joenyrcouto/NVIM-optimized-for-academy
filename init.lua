-- 1. Marca que viemos do Obsidian
vim.g.launched_from_obsidian = true
vim.g.have_nerd_font = false

-- 2. Define caminhos base
local home = os.getenv("HOME")
local original_config = home .. "/.config/nvim"

-- 3. REDIRECIONAMENTO DE DADOS (Impede o Lazy de clonar tudo de novo)
-- Forçamos o Neovim a usar as pastas da instalação principal
vim.env.XDG_DATA_HOME  = home .. "/.local/share"
vim.env.XDG_STATE_HOME = home .. "/.local/state"
vim.env.XDG_CACHE_HOME = home .. "/.cache"

-- 4. CORREÇÃO DO 'REQUIRE' (Resolve o erro do quarto_tmp e custom.plugins)
-- Isso diz ao Neovim: "Procure módulos Lua na pasta do nvim original também"
local original_lua_path = original_config .. "/lua/?.lua;" .. original_config .. "/lua/?/init.lua"
package.path = original_lua_path .. ";" .. package.path

-- 5. Adiciona a pasta original ao runtimepath (para achar pastas after/, plugin/, etc.)
vim.opt.rtp:prepend(original_config)

-- 6. Carrega o seu init.lua principal
local main_init = original_config .. "/init.lua"
dofile(main_init)
