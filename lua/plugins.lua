
vim.cmd 'packadd packer.nvim'

return require('packer').startup({function()

	use 'wbthomason/packer.nvim'

	-- Comments
	--let g:NERDCustomDelimiters = { 'c': { 'left': '//'} }
	--use { 'preservim/nerdcommenter', opt = true, cmd = {'<Plug>NERDCommenterToggle'}}
	use {
		'preservim/nerdcommenter',
		config = function()
			nmap('#', '<Plug>NERDCommenterToggle', { noremap = false } )
			xmap('#', '<Plug>NERDCommenterToggle', { noremap = false } )
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

end,

-- Packer config
config = {
	display = {
		open_fn = require('packer.util').float,
	}
}})

