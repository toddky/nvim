-- :help modeline
-- vim: noet ts=4 sts=0 sw=0
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/folke/dot/blob/master/config/nvim/lua/plugins.lua
-- https://github.com/mhartington/dotfiles/blob/main/config/nvim/lua/mh/plugins/init.lua
-- https://github.com/1024bees/dotfiles/tree/work2/nvim
-- https://github.com/nvim-lua/kickstart.nvim


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

-- Check if using RHEL8
local is_rhel8 = vim.fn.system('cat /etc/redhat-release | grep -q "release 8"') == 0


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
		version = '82eb26de265292808917b82f3eda2725b53d785c',
	},

	{
		-- Code outline window
		-- https://github.com/stevearc/aerial.nvim
		'stevearc/aerial.nvim',
		-- Pretty neat plugin but needs LSP to work, so not worth it yet
		--enabled = false,
		cmd = 'AerialToggle',
		opts = {},
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons"
		},
		-- 2025-03-07
		version = 'v2.5.0',
	},

	------------------------------------------------------------
	-- GitHub Copilot and ChatGPT
	------------------------------------------------------------
	-- :Copilot setup
	-- TODO: https://github.com/zbirenbaum/copilot-cmp
	{
		'github/copilot.vim',
		cmd = 'Copilot',
		-- v1.39.0 requires node 18, which is not available on this system
		--tag = 'v1.38.0'
		--tag = 'v1.36.0'
		-- 2025-03-07
		tag = is_rhel8 and 'v1.42.0' or 'v1.36.0',
	},
	{
		-- for curl, log and async functions
		"nvim-lua/plenary.nvim",
	},
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		-- https://github.com/CopilotC-Nvim/CopilotChat.nvim/wiki/Examples-and-Tips
		--enabled = false,
		cmd = 'CopilotChatOpen',
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		build = "make tiktoken", -- Only on MacOS or Linux
		opts = {
			-- See Configuration section for options
		},
			-- See Commands section for default commands if you want to lazy load on them
	},

	-- https://github.com/jackMort/ChatGPT.nvim
	-- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
	{
		"jackMort/ChatGPT.nvim",
		enabled = false,
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
		--enabled = false,
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
	{
		'folke/which-key.nvim',
		opts = {},
		-- 2025-03-07
		version = 'v3.16.0'
	},

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
	-- REVISIT: Once treesitter gets fixed
	-- https://github.com/OXY2DEV/markview.nvim

	------------------------------------------------------------
	-- TREESITTER
	------------------------------------------------------------
	-- Highlight, edit, and navigate code
	{
		'nvim-treesitter/nvim-treesitter',
		-- Currently disabled because of this error:
		-- src/tree_sitter/parser.h:184:5: error: ‘for’ loop initial declarations are only allowed in C99 mode
		enabled = false,
		--enabled = true,
		dependencies = {
			'nvim-treesitter/nvim-treesitter-textobjects',
		},
		config = function()
			pcall(require('nvim-treesitter.install').update { with_sync = true })
		end,
	},

	--    For additional information see: https://github.com/folke/lazy.nvim#-structuring-your-plugins
	{ import = 'custom.plugins' },
}, {})


-- =============================================================================
-- REQUIRE
-- =============================================================================
require('colors')
require('functions')
require('mappings')
require('options')
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
require('setup.copilot')
require('setup.lsp')
require('setup.cmp')


