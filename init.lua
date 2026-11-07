-- :help modeline
-- vim: noet ts=4 sts=0 sw=0
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/folke/dot/blob/master/config/nvim/lua/plugins.lua
-- https://github.com/mhartington/dotfiles/blob/main/config/nvim/lua/mh/plugins/init.lua
-- https://github.com/1024bees/dotfiles/tree/work2/nvim
-- https://github.com/nvim-lua/kickstart.nvim
-- https://github.com/csdvrx/CuteVim/blob/main/.vimrc


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
local fp = io.open("/etc/redhat-release", "r")
local content = fp and fp:read("*all")
if fp then fp:close() end
local is_rhel8 = content ~= nil and (string.find(content, "release 8") ~= nil)

-- Source the file instead of :colorscheme: the runtimepath search for colors/* is slow on this filesystem,
-- and lazy's ColorSchemePre hook adds another glob over every plugin.
--vim.cmd.source(vim.fn.stdpath('config') .. '/colors/jellybeans.vim')
--vim.cmd.source(vim.fn.stdpath('config') .. '/colors/catppuccin_macchiato.vim')
vim.cmd.source(vim.fn.stdpath('config') .. '/colors/ela_perfect.vim')


-- =============================================================================
-- LAZY
-- =============================================================================
require('lazy').setup({

	------------------------------------------------------------
	-- VENDORED
	------------------------------------------------------------
	-- A local spec puts external/ ahead of $VIMRUNTIME, whose own autoload/context.vim would shadow context.vim's.
	{
		dir = vim.fn.stdpath('config') .. '/external',
		name = 'external',
		event = 'VeryLazy',
		-- context.vim activates on VimEnter, which has already fired by VeryLazy.
		config = function() vim.cmd('ContextActivate') end,
	},

	------------------------------------------------------------
	-- GitHub Copilot
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
		"CopilotC-Nvim/CopilotChat.nvim",
		-- https://github.com/CopilotC-Nvim/CopilotChat.nvim/wiki/Examples-and-Tips
		--enabled = false,
		enabled = is_rhel8,
		event = 'VeryLazy',
		--model = 'gpt-4o-2024-11-20', -- Default model to use, see ':CopilotChatModels' for available models (can be specified manually in prompt via $).
		model = 'copilot:gpt-4o',
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		build = "make tiktoken", -- Only on MacOS or Linux
		opts = {
			-- See Configuration section for options
		},
		config = function(_, opts)
			require('CopilotChat').setup(opts)
			require('setup.copilot')
		end,
	},

	------------------------------------------------------------
	-- Git
	------------------------------------------------------------
	'tpope/vim-fugitive',
	{
		'lewis6991/gitsigns.nvim',
		event = 'VeryLazy',
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
	{
		'sindrets/diffview.nvim',
		cmd = { 'DiffviewOpen', 'DiffviewFileHistory' },
		opts = {
			enhanced_diff_hl = true,
		},
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
		-- nvim-lspconfig requires Nvim version 0.10, but you are running: 0.9.5
		-- tag = 'v2.0.0',
		tag = 'v1.8.0',
		-- NOTE: This is where your plugins related to LSP can be installed.
		dependencies = {
			-- Automatically install LSPs to stdpath for neovim
			{ 'williamboman/mason.nvim', tag = 'v1.11.0' },
			{ 'williamboman/mason-lspconfig.nvim', tag = 'v1.32.0' },

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
		event = 'InsertEnter',
		dependencies = {
			'hrsh7th/cmp-nvim-lsp',
			'L3MON4D3/LuaSnip',
			'saadparwaiz1/cmp_luasnip',
		},
		config = function() require('setup.cmp') end,
	},

	------------------------------------------------------------
	-- FUZZY FINDER
	------------------------------------------------------------
	{
		'nvim-telescope/telescope.nvim',
		--enabled = false,
		version = 'v0.1.9',
		cmd = 'Telescope',
		dependencies = {'nvim-lua/plenary.nvim', 'kyazdani42/nvim-web-devicons'},
		config = function() require('setup.telescope') end,
	},
	-- Fuzzy Finder Algorithm which requires local dependencies to be built.
	{
		'nvim-telescope/telescope-fzf-native.nvim',
		-- NOTE: If you are having trouble with this installation,
		--       refer to the README for telescope-fzf-native for more instructions.
		build = 'make',
		lazy = true,
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
		event = 'VeryLazy',
		opts = {},
		-- 2025-03-07
		version = 'v3.16.0'
	},

	------------------------------------------------------------
	-- SYNTAX
	------------------------------------------------------------
	-- REVISIT: Once treesitter gets fixed
	-- https://github.com/OXY2DEV/markview.nvim

	------------------------------------------------------------
	-- TREESITTER
	------------------------------------------------------------
	-- Highlight, edit, and navigate code
	{
		'nvim-treesitter/nvim-treesitter',
		-- Pin to v0.10.0: main branch requires nvim 0.11+ (ABI 15)
		tag = 'v0.10.0',
		enabled = true,
		event = 'VeryLazy',
		dependencies = {
			'nvim-treesitter/nvim-treesitter-textobjects',
		},
		build = ':TSUpdate',
		config = function() require('setup.treesitter') end,
	},

	--    For additional information see: https://github.com/folke/lazy.nvim#-structuring-your-plugins
	{ import = 'custom.plugins' },
}, {
	performance = { rtp = { disabled_plugins = { 'matchit' } } },
})

-- Load matchit on VeryLazy instead of at startup.
vim.api.nvim_create_autocmd('User', {
	pattern = 'VeryLazy',
	once = true,
	callback = function() vim.cmd.packadd('matchit') end,
})


-- =============================================================================
-- REQUIRE
-- =============================================================================
require('colors')
require('statusline')
require('functions')
require('mappings')
require('options')
require('text-objects')
require('auto-quit')


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
require('setup.lsp')


