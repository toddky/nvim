
-- TODO: Try lazy.nvim as plugin manager: https://github.com/folke/lazy.nvim

-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/folke/dot/blob/master/config/nvim/lua/plugins.lua
-- https://github.com/mhartington/dotfiles/blob/main/config/nvim/lua/mh/plugins/init.lua


-- =============================================================================
-- NOTES
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


-- =============================================================================
-- SETUP
-- =============================================================================
-- TODO: Figure out how to set up lazy.nvim
-- local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- if not vim.loop.fs_stat(lazypath) then
-- 	vim.fn.system({
-- 		"git",
-- 		"clone",
-- 		"--filter=blob:none",
-- 		"https://github.com/folke/lazy.nvim.git",
-- 		"--branch=stable",
-- 		lazypath,
-- 	})
-- end
-- vim.opt.rtp:prepend(lazypath)


-- =============================================================================
-- SETUP
-- =============================================================================
-- Automatically install packer.nvim if it doesn't exists
local fn = vim.fn
local install_path = fn.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
	fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

-- Check if pynvim is installed
local has_python3 = vim.fn.exists('g:python3_host_prog')
local has_pynvim = false
if has_python3 then
	local output = vim.fn.system('python3 -c "import pynvim" 2>&1')
	has_pynvim = (vim.v.shell_error == 0)
end

disable_treesitter = false
disable_ultisnips = not has_pynvim
disable_cmp = not has_pynvim

--disable_treesitter = true
--disable_ultisnips = true
--disable_cmp = true


-- =============================================================================
-- PACKER
-- =============================================================================
-- :PackerCompile
-- :PackerSync
vim.cmd 'packadd packer.nvim'

local packer = require 'packer'
local use = packer.use


packer.startup({function()

	use 'wbthomason/packer.nvim'

	-- Treesitter
	use {
		'nvim-treesitter/nvim-treesitter',
		disable = disable_treesitter,
		config = function()
			require('plugins/nvim-treesitter')
		end
	}
	use {
		'nvim-treesitter/playground',
		disable = disable_treesitter,
	}

	-- GitHub Copilot
	-- :Copilot setup
	-- TODO: https://github.com/zbirenbaum/copilot-cmp
	use {
		'github/copilot.vim',
		cmd = 'Copilot'
	}

	-- UltiShips
	use {
		'SirVer/ultisnips',
		disable = disable_ultisnips,
		setup = function()
			vim.g.UltiSnipsSnippetDirectories = { 'ultisnips' }
			vim.g.UltiSnipsEditSplit           = 'tabdo'
			vim.g.UltiSnipsExpandTrigger       = "<Tab>"
			vim.g.UltiSnipsListSnippets        = "<F2>"
			vim.g.UltiSnipsJumpForwardTrigger  = "<Tab>"
			vim.g.UltiSnipsJumpBackwardTrigger = "<S-Tab>"
		end
		-- 'honza/vim-snippets'
	}
	-- TODO: https://github.com/quangnguyen30192/cmp-nvim-ultisnips

	-- nvim-cmp
	use {
		'hrsh7th/nvim-cmp',
		disable = disable_cmp,
		requires = {
			'neovim/nvim-lspconfig',
			'hrsh7th/cmp-nvim-lsp',
			'hrsh7th/cmp-buffer',
			'hrsh7th/cmp-path',
			'hrsh7th/cmp-cmdline',
			{
				'quangnguyen30192/cmp-nvim-ultisnips',
				disable = disable_cmp,
				config = function()
					require('cmp_nvim_ultisnips').setup()
				end
			}
		},
		setup = function()
		end,
		config = function()
			require('plugins/nvim-cmp')
		end,
	}

	-- coq
	use {
		'ms-jpq/coq_nvim',
		branch = 'coq',
		requires = {
			{
				'ms-jpq/coq.artifacts',
				branch = 'artifacts',
			},
			{
				'ms-jpq/coq.thirdparty',
				branch = '3p',
			}
		}
	}


	-- Telescope
	use {
		'nvim-telescope/telescope.nvim',
		--disable = true,
		requires = { {'nvim-lua/plenary.nvim', 'kyazdani42/nvim-web-devicons'} },
		setup = function()
			require('nvim-web-devicons').get_icons()
		end
	}

	-- NERD Commenter
	--use { 'preservim/nerdcommenter', opt = true, cmd = {'<Plug>NERDCommenterToggle'}}
	use {
		'preservim/nerdcommenter',
		setup = function()
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
	}

	-- FZF
	use {
		'ibhagwan/fzf-lua',
		requires = {
			'vijaymarupudi/nvim-fzf',
			'kyazdani42/nvim-web-devicons'
		}
		-- :help fzf-lua-customization
	}

	-- Git Integration
	-- gitsigns replaces gitgutter
	-- TODO: Learn how to stage hunks
	-- :help gitsigns
	use {
		'lewis6991/gitsigns.nvim',
		requires = {
			'nvim-lua/plenary.nvim'
		},
		config = function()
			require('gitsigns').setup()
		end
	}

	use {
		"folke/which-key.nvim",
		--disable = true,
		config = function()
			require("which-key").setup {
			}
		end
	}

	-- Indentation
	-- :help indent_blankline
	use {
		'lukas-reineke/indent-blankline.nvim',
		config = function()
			require("indent_blankline").setup {
				char = '│',
				space_char_blankline = " ",
				filetype_exclude = {'help'},
				buftype_exclude = {'terminal'},
				show_end_of_line = true,
				show_trailing_blankline_indent = false,
				-- TODO: Figure out indent_blankline treesitter context
				--show_current_context = true,
				-- TODO: Figure out indent_blankline highlight list
				char_highlight_list = {
					"IndentBlanklineIndent1",
					"IndentBlanklineIndent2",
					"IndentBlanklineIndent3",
					"IndentBlanklineIndent4",
					"IndentBlanklineIndent5",
					"IndentBlanklineIndent6",
				}
			}
		end
	}

	use {
		'nvim-treesitter/nvim-treesitter-context',
		disable = disable_treesitter,
	}

	use {
		'wellle/context.vim',
		-- Replaced with nvim-treesitter-context
		--disable = true,
		-- TODO: Always enable when I figure out the flickering issue
		--cmd = {'ContextEnable', 'ContextEnableWindow'},
		setup = function()
			vim.g.context_enabled = 1
			vim.g.context_add_mappings = 0
		end
	}

	use {
		'nvim-tree/nvim-tree.lua',
		disable = true,
		requires = {
			'nvim-tree/nvim-web-devicons',
		},
		--cmd = {'NvimTreeToggle'},
		setup = function()
			vim.g.loaded_netrw = 1
			vim.g.loaded_netrwPlugin = 1
		end,
		config = function()
			require("nvim-tree").setup({
				view = {
					width = 30,
					mappings = {
						list = {
							{ key = "s", action = "split" },
							{ key = "u", action = "dir_up" },
							{ key = "v", action = "vsplit" },
							{ key = "?", action = "toggle_help" },
						},
					},
				},
			})
		end,
	}

	-- TODO: Shellcheck
	-- https://github.com/jose-elias-alvarez/null-ls.nvim

	-- Colorschemes
	-- :colorscheme nord
	use 'shaunsingh/nord.nvim'
	use 'EdenEast/nightfox.nvim'
	--use {
		--'EdenEast/nightfox.nvim',
		--config = function()
			--require('nightfox').load('nightfox')
			--require('nightfox').load('nordfox')
			--require('nightfox').load('dayfox')
		--end
	--}

	-- TODO: Figure out how to install this.
	-- When I try to use this, I get this errror:
		-- Please update dependencies using :CHADdeps
	-- When I run :CHADdeps, I get this error:
		-- Error detected while processing function CHADon_exit:
		-- line    1:
		-- CHADTree EXITED - 1
	--use {
		--'ms-jpq/chadtree',
		--config = function()
			--require('chadtree').setup()
		--end
	--}

	-- TODO: Try these
	-- https://github.com/wellle/targets.vim
	-- https://github.com/ms-jpq/coq_nvim
	-- https://github.com/folke/dot/blob/master/config/nvim/lua/config/snippets.lua
	-- https://github.com/weilbith/nvim-code-action-menu
	-- Plugin for "submodes":
	--https://github.com/Iron-E/nvim-libmodal
end,

-- Packer config
config = {
	display = {
		open_fn = require('packer.util').float,
		-- TODO: Why doesn't this work?
		--open_fn = require('packer.util').float({ border = 'single' }),
	}
}})
