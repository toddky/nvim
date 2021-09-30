
local execute = vim.api.nvim_command
local fn = vim.fn
local cmd = vim.cmd

-- Example
-- https://github.com/shaunsingh/vimrc-dotfiles/blob/main/.config/nvim/init.lua
local my_modules = {
	'options',
	'mappings',
}
for i = 1, #my_modules, 1 do
	pcall(require, my_modules[i])
end

-- =============================================================================
-- PLUGIN MANAGER
-- =============================================================================
-- Automatically install packer.nvim if it doesn't exists
local install_path = fn.stdpath('data')..'/site/pack/packer/opt/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
	fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

cmd 'packadd packer.nvim'
require('plugins')

