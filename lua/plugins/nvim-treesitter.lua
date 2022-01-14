
-- Modules:
-- https://github.com/nvim-treesitter/nvim-treesitter#modules

-- Commands
-- Enable/disable treesitter
--   :TSBufEnable {module}
--   :TSBufDisable {module}
-- " Enable/disable on every buffer for specified filetype
--   :TSEnableAll {module} [{ft}]
--   :TSDisableAll {module} [{ft}]
-- Describe modules state for each filetype
--   :TSModuleInfo [{module}]


-- Examples:
-- https://github.com/mhartington/dotfiles/blob/main/config/nvim/lua/mh/treesitter/init.lua

local ts = require 'nvim-treesitter.configs'

ts.setup {
	context_commentstring = {enable = true},
	ensure_installed = {"html", "javascript", "lua"},
	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false
	},
	indent = {enable = true},

}

--TSUpdate
--set foldmethod=expr
--set foldexpr=nvim_treesitter#foldexpr()


