
local M = {}

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

function M.map(mode, lhs, rhs, opts)
	local options = {noremap = true, silent = true, unique = true}
	if opts then options = vim.tbl_extend('force', options, opts) end
	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

function M.leader(lhs, rhs, opts)
	M.map('n', '<space>' .. lhs, rhs, opts)
end

function M.nmap(lhs, rhs, opts)
	M.map('n', lhs, rhs, opts)
end

function M.imap(lhs, rhs, opts)
	M.map('i', lhs, rhs, opts)
end

function M.vmap(lhs, rhs, opts)
	M.map('v', lhs, rhs, opts)
end

function M.xmap(lhs, rhs, opts)
	M.map('x', lhs, rhs, opts)
end

function M.tmap(lhs, rhs, opts)
	M.map('t', lhs, rhs, opts)
end


-- =============================================================================
-- RETURN
-- =============================================================================
return M

