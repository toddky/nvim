
-- Example
-- https://github.com/shaunsingh/vimrc-dotfiles/blob/main/.config/nvim/init.lua
local my_modules = {
	"options",
	"mappings",
}
for i = 1, #my_modules, 1 do
	pcall(require, my_modules[i])
end

vim.cmd 'colorscheme jellybeans'

