
vim.cmd 'packadd packer.nvim'


return require('packer').startup({function()

	use 'wbthomason/packer.nvim'

	-- Comments
	--let g:NERDCustomDelimiters = { 'c': { 'left': '//'} }
	--use { 'preservim/nerdcommenter', opt = true, cmd = {'<Plug>NERDCommenterToggle'}}
	use {
		'preservim/nerdcommenter',
		config = function()
			local util = require('util')
			util.nmap('#', '<Plug>NERDCommenterToggle', { noremap = false } )
			util.xmap('#', '<Plug>NERDCommenterToggle', { noremap = false } )
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
	--use 'lukas-reineke/indent-blankline.nvim'
	-- https://github.com/wellle/targets.vim
	-- https://github.com/wellle/context.vim
	-- https://github.com/ms-jpq/coq_nvim
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

