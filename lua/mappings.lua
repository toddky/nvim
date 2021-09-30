
-- =============================================================================
-- FUNCTIONS
-- =============================================================================

function map(mode, lhs, rhs, opts)
	local options = {noremap = true, silent = true, unique = true}
	if opts then options = vim.tbl_extend('force', options, opts) end
	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

function leader(lhs, rhs, opts)
	map('n', '<space>' .. lhs, rhs, opts)
end

function nmap(lhs, rhs, opts)
	map('n', lhs, rhs, opts)
end

function imap(lhs, rhs, opts)
	map('i', lhs, rhs, opts)
end

function vmap(lhs, rhs, opts)
	map('v', lhs, rhs, opts)
end

function xmap(lhs, rhs, opts)
	map('x', lhs, rhs, opts)
end

function tmap(lhs, rhs, opts)
	map('t', lhs, rhs, opts)
end


-- =============================================================================
-- NORMAL MODE
-- =============================================================================

-- Command
nmap('<Enter>', ':')

-- Black hole registers
nmap('c', '"_c')
nmap('C', '"_C')

-- Redo
nmap('U', '<C-r>')


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

-- Repeat latest f, t, F or T in opposite direction
-- Opposite direction of ;
nmap(':', ',')


-- =============================================================================
-- TABS
-- =============================================================================
nmap('>', '<cmd>tabnext<Enter>')
nmap('<', '<cmd>tabprev<Enter>')
leader('tn', '<cmd>tabnew %<Enter>')
leader('td', '<cmd>tabclose<Enter>')


-- =============================================================================
-- WINDOWS
-- =============================================================================
leader('h', '<C-w>h')
leader('j', '<C-w>j')
leader('k', '<C-w>k')
leader('l', '<C-w>l')


-- =============================================================================
-- BUFFERS
-- =============================================================================
leader('fq', '<cmd>q!<Enter>')
leader('fw', '<cmd>w<Enter>')
leader('fx', '<cmd>x<Enter>')


-- =============================================================================
-- INSERT MODE
-- =============================================================================
imap('jj', '<esc>')


-- =============================================================================
-- VISUAL MODE
-- =============================================================================
vmap('v', '<C-v>')
vmap('q', '<Esc>')


-- =============================================================================
-- TERMINAL MODE
-- =============================================================================
tmap('<Esc>', '<C-\\><C-n>')



