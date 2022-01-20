
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/b0o/nvim-conf/blob/main/lua/user/mappings.lua


-- =============================================================================
-- REQUIRE
-- =============================================================================
local util = require('util')


-- =============================================================================
-- NORMAL MODE
-- =============================================================================

-- Command
util.nvmap('<Enter>', ':')

-- Indentation
util.nmap('<Tab>', '>>')
util.nmap('<S-Tab>', '<<')

-- Black hole registers
util.nmap('c', '"_c')
util.nmap('C', '"_C')

-- Redo
util.nmap('U', '<C-r>')

-- Disable Ex mode
util.nmap('Q', '<Nop>')

-- Disable Ctrl-c warning
util.nmap('<C-c>', '<Nop>')


-- =============================================================================
-- MOVEMENT
-- =============================================================================

-- TODO: Map j to gj with v:count

-- Beginning/end of line
util.nvmap('gh', '^')
util.nvmap('gl', '$')
util.nvmap('H', '^')
util.nvmap('L', '$')

-- Center after search
util.nvmap('N', 'Nzz')
util.nvmap('n', 'nzz')

-- Mark with `M` and jump with `m`
util.nvmap('M', 'm')
util.nvmap('m', "'")

-- TODO: Center after movement
--util.nvmap('{', '{zz')
--util.nvmap('}', '}zz')
--util.nvmap('<C-o>', '<C-o>zz')
--util.nvmap('<C-i>', '<C-i>zz')

-- Repeat latest f, t, F or T in opposite direction
-- Opposite direction of ;
util.nvmap(':', ',')


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

util.leader('w', '<C-w>', { noremap = false })
util.nmap('<C-w>e', '<C-w>=')


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
-- Visual block mode
util.vmap('v', '<C-v>')

-- Quit
util.vmap('q', '<Esc>')

-- Search for visually selected text
-- https://vim.fandom.com/wiki/Search_for_visually_selected_text
util.vmap('*', 'y/<C-R>"<Enter>')

-- TODO: Figure out how this works
-- Use dot over visual selection
--util.xmap('.', '<cmd>norm.<Enter>')

-- TODO: Figure out how this works
-- Use macro over visual selection
--util.xmap('@', [[<cmd>'<,'>:normal @@<Enter>]])

-- Indentation
--util.vmap('<Tab>', '>gv')
-- UltiSnips remaps this, so I have to use this autocmd
vim.api.nvim_command([[autocmd VimEnter * vnoremap <Tab> >gv]])
util.vmap('<S-Tab>', '<gv')


-- =============================================================================
-- PLUGINS
-- =============================================================================
util.nmap(',ce',  '<cmd>ContextEnableWindow<Enter>')
util.nmap(',cq',  '<cmd>ContextDisable<Enter>')
util.nmap(',f/',  '<cmd>FzfLua blines<Enter>')
util.nmap(',fb',  '<cmd>FzfLua buffers<Enter>')
util.nmap(',ff',  '<cmd>FzfLua files<Enter>')
util.nmap(',fgb', '<cmd>FzfLua git_bcommits<Enter>')
util.nmap(',fgf', '<cmd>FzfLua git_files<Enter>')
util.nmap(',fgl', '<cmd>FzfLua git_commits<Enter>')
util.nmap(',fh',  '<cmd>FzfLua help_tags<Enter>')
util.nmap(',fl',  '<cmd>FzfLua lines<Enter>')
util.nmap(',ft',  '<cmd>FzfLua tabs<Enter>')
util.nmap(',gh',  '<cmd>Gitsigns stage_hunk<Enter>')
util.nmap(',tc',  '<cmd>Telescope colorscheme<Enter>')
util.nmap(',tf',  '<cmd>Telescope find_files<Enter>')
util.nmap(',tgf', '<cmd>Telescope git_files<Enter>')
util.nmap(',tk',  '<cmd>Telescope keymaps<Enter>')
util.nmap(',tsh', '<cmd>TSHighlightCapturesUnderCursor<Enter>')
util.nmap(',tsp', '<cmd>TSPlaygroundToggle<Enter>')
util.nmap(',pc',  '<cmd>PackerCompile<Enter>')
util.nmap(',ps',  '<cmd>PackerSync<Enter>')
util.nmap(',pu',  '<cmd>PackerUpdate<Enter>')


-- =============================================================================
-- OPTIONS
-- =============================================================================
util.leader('sfd', '<cmd>set foldmethod=diff<Enter>')
util.leader('sfi', '<cmd>set foldmethod=indent<Enter>')
util.leader('sfm', '<cmd>set foldmethod=manual<Enter>')
util.leader('st2', '<cmd>set tabstop=2<Enter>')
util.leader('st4', '<cmd>set tabstop=4<Enter>')
util.leader('ste', '<cmd>set expandtab<Enter>')
util.leader('stn', '<cmd>set noexpandtab<Enter>')


-- =============================================================================
-- TERMINAL MODE
-- =============================================================================
util.tmap('<Esc>', '<C-\\><C-n>')


