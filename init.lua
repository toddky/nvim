
--local execute = vim.api.nvim_command
--local fn = vim.fn
--local cmd = vim.cmd

-- Example
-- https://github.com/shaunsingh/vimrc-dotfiles/blob/main/.config/nvim/init.lua
local my_modules = {
	'options',
	'mappings',
	'statusline',
}
for i = 1, #my_modules, 1 do
	pcall(require, my_modules[i])
	--TODO: Figure out how to make this work
	--local ok, _ = pcall(require, my_modules[i])
	--if not ok then
		--print('failed to load '..my_modules[i])
	--end
end

-- Load plugins
require('plugins')

