
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/folke/dot/blob/master/config/nvim/lua/util/init.lua

local M = {}


-- =============================================================================
-- MAP
-- =============================================================================

local map = function(mode, lhs, rhs, opts)
	local options = {noremap = true, silent = true, unique = true}
	if opts then options = vim.tbl_extend('force', options, opts) end
	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

function M.leader(lhs, rhs, opts)
	M.nmap('<space>' .. lhs, rhs, opts)
end

function M.nmap(lhs, rhs, opts)
	map('n', lhs, rhs, opts)
end

function M.imap(lhs, rhs, opts)
	map('i', lhs, rhs, opts)
end

function M.vmap(lhs, rhs, opts)
	map('v', lhs, rhs, opts)
end

function M.xmap(lhs, rhs, opts)
	map('x', lhs, rhs, opts)
end

function M.tmap(lhs, rhs, opts)
	map('t', lhs, rhs, opts)
end


-- Normal and Visual
function M.nvmap(lhs, rhs, opts)
	map('n', lhs, rhs, opts)
	map('v', lhs, rhs, opts)
end

-- Text Objects
function M.xomap(lhs, rhs, opts)
	map('x', lhs, rhs, opts)
	map('o', lhs, rhs, opts)
end


-- =============================================================================
-- RETURN
-- =============================================================================
return M

