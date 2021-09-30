
return require('packer').startup(function()

	use 'wbthomason/packer.nvim'

	--let g:NERDCustomDelimiters = { 'c': { 'left': '//'} }

	-- use "terrortylor/nvim-comment"
	-- require('nvim_comment').setup()
	-- nmap('#', '<cmd>CommentToggle<Enter>')
	-- xmap('#', '<cmd>CommentToggle<Enter>')

	use 'preservim/nerdcommenter'
	nmap('#', '<Plug>NERDCommenterToggle', { noremap = false } )
	xmap('#', '<Plug>NERDCommenterToggle', { noremap = false } )

end)



