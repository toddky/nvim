
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/folke/dot/blob/master/config/nvim/lua/plugins.lua


-- =============================================================================
-- SETUP
-- =============================================================================
-- Automatically install packer.nvim if it doesn't exists
local fn = vim.fn
local install_path = fn.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
	fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end


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

	-- Comments
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

	-- Git Integration
	-- gitsigns replaces gitgutter
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
				--char = "|",
				char = '│',
				filetype_exclude = {'help'},
				buftype_exclude = {'terminal'},
				show_end_of_line = true,
				-- TODO: Figure out indent_blankline treesitter context
				show_current_context = true,
				space_char_blankline = " ",
				-- TODO: Figure out indent_blankline highlight list
				--char_highlight_list = {
					--"IndentBlanklineIndent1",
					--"IndentBlanklineIndent2",
					--"IndentBlanklineIndent3",
					--"IndentBlanklineIndent4",
					--"IndentBlanklineIndent5",
					--"IndentBlanklineIndent6",
				--},
			}
		end
	}

	-- TODO: Re-enable when I figure out the flickering issue
	use {
		'wellle/context.vim',
		cmd = {'ContextEnable', 'ContextEnableWindow'},
		setup = function()
			vim.g.context_add_mappings = 0
		end
	}

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


