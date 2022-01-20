
-- =============================================================================
-- COMMANDS
-- =============================================================================
-- Enable/disable treesitter
--   :TSBufEnable {module}
--   :TSBufDisable {module}
-- " Enable/disable on every buffer for specified filetype
--   :TSEnableAll {module} [{ft}]
--   :TSDisableAll {module} [{ft}]
-- Describe modules state for each filetype
--   :TSModuleInfo [{module}]
-- Update treesitter
--   :TSUpdate

-- Modules:
-- https://github.com/nvim-treesitter/nvim-treesitter#modules


-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/mhartington/dotfiles/blob/main/config/nvim/lua/mh/treesitter/init.lua


-- =============================================================================
-- CONFIG
-- =============================================================================
local ts = require 'nvim-treesitter.configs'

ts.setup {
	context_commentstring = {enable = true},
	-- TODO: Verilog: https://github.com/tree-sitter/tree-sitter-verilog
	ensure_installed = {"html", "javascript", "lua", "verilog"},
	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false
	},
	indent = {enable = true},

}

--set foldmethod=expr
--set foldexpr=nvim_treesitter#foldexpr()

