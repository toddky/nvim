
local util = require('util')


-- =============================================================================
-- NORMAL MODE
-- =============================================================================

-- Command
util.nmap('<Enter>', ':')

-- Black hole registers
util.nmap('c', '"_c')
util.nmap('C', '"_C')

-- Redo
util.nmap('U', '<C-r>')

-- Indentation
util.nmap('<Tab>', '>>')
util.nmap('<S-Tab>', '<<')
--util.xmap('<Tab>', '>>gv')
--util.xmap('<S-Tab>', '<<gv')


-- =============================================================================
-- MOVEMENT
-- =============================================================================

-- Beginning/end of line
util.nmap('gh', '^')
util.nmap('gl', '$')
util.nmap('H', '^')
util.nmap('L', '$')

-- Center after search
util.nmap('N', 'Nzz')
util.nmap('n', 'nzz')

-- Mark with `M` and jump with `m`
util.nmap('M', 'm')
util.nmap('m', "'")

-- Repeat latest f, t, F or T in opposite direction
-- Opposite direction of ;
util.nmap(':', ',')


-- =============================================================================
-- TABS
-- =============================================================================
util.nmap('>', '<cmd>tabnext<Enter>')
util.nmap('<', '<cmd>tabprev<Enter>')
util.leader('tn', '<cmd>tabnew %<Enter>')
util.leader('td', '<cmd>tabclose<Enter>')


-- =============================================================================
-- WINDOWS
-- =============================================================================
util.leader('h', '<C-w>h')
util.leader('j', '<C-w>j')
util.leader('k', '<C-w>k')
util.leader('l', '<C-w>l')


-- =============================================================================
-- BUFFERS
-- =============================================================================
util.leader('fj', '<cmd>bnext<Enter>')
util.leader('fk', '<cmd>bprevious<Enter>')
util.leader('fw', '<cmd>w<Enter>')
util.leader('fx', '<cmd>x<Enter>')
util.leader('fq', '<cmd>q!<Enter>')


-- =============================================================================
-- INSERT MODE
-- =============================================================================
util.imap('jj', '<esc>')


-- =============================================================================
-- VISUAL MODE
-- =============================================================================
util.vmap('v', '<C-v>')
util.vmap('q', '<Esc>')


-- =============================================================================
-- TERMINAL MODE
-- =============================================================================
util.tmap('<Esc>', '<C-\\><C-n>')


