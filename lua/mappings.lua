
local function map(mode, lhs, rhs, opts)
	local options = {noremap = true, silent = true, unique = true}
	if opts then options = vim.tbl_extend('force', options, opts) end
	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

local function leader(lhs, rhs, opts)
	map('n', '<space>' .. lhs, rhs, opts)
end

local function nmap(lhs, rhs, opts)
	map('n', lhs, rhs, opts)
end


-- =============================================================================
-- NORMAL
-- =============================================================================

-- Black hole registers
nmap('c', '"_c')
nmap('C', '"_C')


-- =============================================================================
-- MOVEMENT
-- =============================================================================

-- Beginning/end of line
nmap('gh', '^')
nmap('gl', '$')
nmap('H', '^')
nmap('L', '$')

-- Center after search
nmap('N', 'Nzz')
nmap('n', 'nzz')

-- Mark with `M` and jump with `m`
nmap('M', 'm')
nmap('m', "'")

nmap('<enter>', ':')

-- =============================================================================
-- FILE
-- =============================================================================
leader('fq', ': q!<enter>')
leader('fw', ': w<enter>')
leader('fx', ': x<enter>')


map('i', 'jj', '<esc>')

