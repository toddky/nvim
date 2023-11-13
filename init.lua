-- REVISIT: Fix my whitespace
-- :help modeline
-- vim: noet ts=4 sts=0 sw=0
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/folke/dot/blob/master/config/nvim/lua/plugins.lua
-- https://github.com/mhartington/dotfiles/blob/main/config/nvim/lua/mh/plugins/init.lua
-- https://github.com/1024bees/dotfiles/tree/work2/nvim


-- =============================================================================
-- PLUGIN NOTES
-- =============================================================================

-- :help packer.use
-- use {
--   'myusername/example',        -- The plugin location string
--   disable = boolean,           -- Mark a plugin as inactive
--   run = string, function, or table  -- Post-update/install hook. See |packer-plugin-hooks|
--   requires = string or list    -- Specifies plugin dependencies. See |packer-plugin-dependencies|
--   setup = string or function,  -- Specifies code to run before this plugin is loaded.
--   config = string or function, -- Specifies code to run after this plugin is loaded.
--   branch = string,             -- Specifies a git branch to use
-- }

-- packer.nvim  -> lazy.nvim
-- setup        -> init
-- requires     -> dependencies
-- as           -> name
-- opt          -> lazy
-- run          -> build
-- lock         -> pin
-- disable=true -> enabled = false
-- tag='*'      -> version="*"
-- after        -> not needed for most use-cases. Use dependencies otherwise.
-- wants        -> not needed for most use-cases. Use dependencies otherwise.
--
-- Merged with parent spec:
-- * opts
-- * dependencies
-- * cmd
-- * event
-- * ft


-- =============================================================================
-- SETUP
-- =============================================================================
-- Install lazy.nvim package manager
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system {
		'git',
		'clone',
		'--filter=blob:none',
		'https://github.com/folke/lazy.nvim.git',
		'--branch=stable', -- latest stable release
		lazypath,
	}
end
vim.opt.rtp:prepend(lazypath)

-- :help mapleader
-- Set <space> as the leader key
-- NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '


-- =============================================================================
-- LAZY
-- =============================================================================
require('lazy').setup({

	------------------------------------------------------------
	-- Colorschemes
	------------------------------------------------------------
	'shaunsingh/nord.nvim',
	'EdenEast/nightfox.nvim',
	{
		-- Theme inspired by Atom
		'navarasu/onedark.nvim',
		priority = 1000,
		config = function()
			vim.cmd.colorscheme 'onedark'
		end,
	},

	------------------------------------------------------------
	-- STATUSLINE
	------------------------------------------------------------
	-- :help lualine.txt
	{
		'nvim-lualine/lualine.nvim',
		opts = {
			options = {
				icons_enabled = false,
				-- Different themes
				--theme = 'onedark',
				theme = 'palenight',
				--theme = 'nightfly',
				--theme = '',
				component_separators = '│',
				section_separators = '',
			},
			--- TODO: Check if copilot is enabled
			-- https://github.com/ofseed/lualine-copilot/blob/9b441d06031cef3cf0ca82a6363189aeeea297ca/lua/lualine/components/copilot.lua#L21
			--local function enabled()
			  --if vim.g.loaded_copilot == 1 and vim.fn["copilot#Enabled"]() == 1 then
				--return true
			  --else
				--return false
			  --end
			--end
		},
	},

	------------------------------------------------------------
	-- CONTEXT
	------------------------------------------------------------
	{
		'wellle/context.vim',
		--enabled = false,
		--cmd = {'ContextEnable', 'ContextEnableWindow'},
		init = function()
			vim.g.context_enabled = 1
			vim.g.context_add_mappings = 0
		end,
	},

	------------------------------------------------------------
	-- GitHub Copilot and ChatGPT
	------------------------------------------------------------
	-- :Copilot setup
	-- TODO: https://github.com/zbirenbaum/copilot-cmp
	{
		'github/copilot.vim',
		cmd = 'Copilot'
	},
	-- https://github.com/jackMort/ChatGPT.nvim
	-- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
	{
		"jackMort/ChatGPT.nvim",
		cmd = 'ChatGPT',
		opts = {
			api_key_cmd = "openaikey",
		},
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
		},
	},

	------------------------------------------------------------
	-- Git
	------------------------------------------------------------
	'tpope/vim-fugitive',
	{
		'lewis6991/gitsigns.nvim',
		opts = {
			-- :help gitsigns.txt
			signs = {
				add = { text = '+' },
				change = { text = '~' },
				delete = { text = '_' },
				topdelete = { text = '‾' },
				changedelete = { text = '~' },
			},
		},
	},
	-- REVISIT: Do I need this?
	-- rhubarb.vim: GitHub plugin
	--'tpope/vim-rhubarb',

	------------------------------------------------------------
	-- NERD Commenter
	------------------------------------------------------------
	{
		'preservim/nerdcommenter',
		init = function()
			vim.g.NERDCustomDelimiters = {
				['c'] = { ['left'] = '//' },
				['python'] = { ['left'] = '#' }
			}
		end,
		config = function()
			local util = require('util')
			util.nmap('#', '<Plug>NERDCommenterToggle', { noremap = false, unique = false } )
			util.xmap('#', '<Plug>NERDCommenterToggle', { noremap = false, unique = false } )
		end
	},

	------------------------------------------------------------
	-- FILE EXPLORER
	------------------------------------------------------------
	{
		'nvim-tree/nvim-tree.lua',
		cmd = 'NvimTreeToggle',
		dependencies = { 'kyazdani42/nvim-web-devicons' },
			--vim.g.loaded_netrw = 1
			--vim.g.loaded_netrwPlugin = 1
		opts = {
			--require("nvim-tree").setup({
				--view = {
					--width = 30,
				--},
			--})
		},
	},

	------------------------------------------------------------
	-- LSP
	------------------------------------------------------------
	-- The configuration is done below. Search for lspconfig to find it below.
	{
		'neovim/nvim-lspconfig',
		-- NOTE: This is where your plugins related to LSP can be installed.
		dependencies = {
			-- Automatically install LSPs to stdpath for neovim
			'williamboman/mason.nvim',
			'williamboman/mason-lspconfig.nvim',

			-- Useful status updates for LSP
			-- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
			{ 'j-hui/fidget.nvim', tag = 'legacy', opts = {} },

			-- https://github.com/folke/neodev.nvim
			-- Automatically configures lua-language-server for your Neovim config, Neovim runtime and plugin directories
			-- Annotations for completion, hover and signatures of Vim functions, Neovim api functions, vim.opt, vim.loop
			-- Properly configures require path and vimruntime
			'folke/neodev.nvim',
		},
	},

	------------------------------------------------------------
	-- CMP
	------------------------------------------------------------
	{
		'hrsh7th/nvim-cmp',
		dependencies = {
			'hrsh7th/cmp-nvim-lsp',
			'L3MON4D3/LuaSnip',
			'saadparwaiz1/cmp_luasnip',
		},
	},

	------------------------------------------------------------
	-- FUZZY FINDER
	------------------------------------------------------------
	{
		'nvim-telescope/telescope.nvim',
		version = '*',
		dependencies = {'nvim-lua/plenary.nvim', 'kyazdani42/nvim-web-devicons'}
	},
	-- Fuzzy Finder Algorithm which requires local dependencies to be built.
	{
		'nvim-telescope/telescope-fzf-native.nvim',
		-- NOTE: If you are having trouble with this installation,
		--       refer to the README for telescope-fzf-native for more instructions.
		build = 'make',
		-- Only load if `make` is available. Make sure you have the system requirements installed.
		cond = function()
			return vim.fn.executable 'make' == 1
		end,
	},

	------------------------------------------------------------
	-- WHICH-KEY
	------------------------------------------------------------
	-- Useful plugin to show you pending keybinds.
	-- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
	{ 'folke/which-key.nvim', opts = {} },

	------------------------------------------------------------
	-- SYNTAX
	------------------------------------------------------------
	-- Add indentation guides blank lines
	-- :help indent_blankline.txt
	{
		'lukas-reineke/indent-blankline.nvim',
		main = "ibl",
		-- NOTE: `opts = {}` is the same as calling `require('ibl').setup({})`
		opts = {
			indent = {
				highlight = {
					"Comment",
				},
				char = "│",
				smart_indent_cap = true,
			},
			whitespace = {
				highlight = {
					"Whitespace",
				},
				 remove_blankline_trail = false,
			},
			scope = {
				enabled = false,
				exclude = { language = { "help" } },
			},
		},
	},
	'vim-scripts/AnsiEsc.vim',

	------------------------------------------------------------
	-- TREESITTER
	------------------------------------------------------------
	-- Highlight, edit, and navigate code
	{
		'nvim-treesitter/nvim-treesitter',
		enabled = true,
		dependencies = {
			'nvim-treesitter/nvim-treesitter-textobjects',
		},
		config = function()
			pcall(require('nvim-treesitter.install').update { with_sync = true })
		end,
	},

	-- NOTE: Next Step on Your Neovim Journey: Add/Configure additional "plugins" for kickstart
	--       These are some example plugins that I've included in the kickstart repository.
	--       Uncomment any of the lines below to enable them.
	-- require 'kickstart.plugins.autoformat',
	-- require 'kickstart.plugins.debug',

	-- NOTE: The import below automatically adds your own plugins, configuration, etc from `lua/custom/plugins/*.lua`
	--    You can use this folder to prevent any conflicts with this init.lua if you're interested in keeping
	--    up-to-date with whatever is in the kickstart repo.
	--
	--    For additional information see: https://github.com/folke/lazy.nvim#-structuring-your-plugins
	--
	--    An additional note is that if you only copied in the `init.lua`, you can just comment this line
	--    to get rid of the warning telling you that there are not plugins in `lua/custom/plugins/`.
	{ import = 'custom.plugins' },
}, {})


-- =============================================================================
-- REQUIRE
-- =============================================================================
require('colors')
require('options')
require('mappings')
require('text-objects')


-- =============================================================================
-- SETTINGS
-- =============================================================================
-- Keep signcolumn on by default
vim.wo.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeout = true
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = '*',
})

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)


-- =============================================================================
-- PLUGIN SETUP
-- =============================================================================
require('setup.treesitter')
require('setup.telescope')
require('setup.lsp')
require('setup.cmp')

