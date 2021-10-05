
local execute = vim.api.nvim_command
local cmd = vim.cmd
local opt = vim.opt

-- Colorscheme
execute('colorscheme jellybeans')


-- =============================================================================
-- OPTIONS
-- =============================================================================

-- Tab settings
opt.expandtab      = false;
opt.autoindent     = true;
opt.tabstop        = 4;
opt.shiftwidth     = 0;
opt.softtabstop    = 0;

-- List
opt.list           = true
opt.listchars      = { tab='▸ ', trail='·', precedes='←', extends='→' }

-- Search
opt.ignorecase     = true
opt.incsearch      = true
opt.hlsearch       = true

opt.number         = true
opt.relativenumber = true

opt.backspace      = {"indent", "eol", "start"}
opt.virtualedit    = "block"
opt.encoding       = "utf-8"

opt.timeoutlen      = 300

opt.wrap           = false
opt.viewoptions    = "folds,cursor,curdir,slash,unix"
opt.sessionoptions = "curdir,help,tabpages,winsize"

opt.clipboard      = "unnamedplus"

-- Highlight currentl line
opt.cursorline     = true
--opt.cursorcolumn   = true
-- TODO: Change color for insert mode
--autocmd InsertEnter * highlight CursorLine guifg=something
--autocmd InsertLeave * highlight CursorLine guifg=something

-- Splits
opt.splitbelow     = true
opt.splitright     = true


-- =============================================================================
-- AUTOMATIC COMMANDS
-- =============================================================================

-- Open help on right split
cmd([[autocmd! BufEnter * if &ft ==# 'help' | wincmd L | endif]])

-- Recompile when plugins.lua is updated
--cmd 'autocmd BufWritePost plugins.lua PackerCompile'

-- Quit man pages with q
-- https://github.com/folke/dot/blob/0e112e845b75f2f9f3ae61479824ca3de47a697f/config/nvim/lua/options.lua#L116
cmd([[autocmd FileType man nnoremap <buffer><silent> q :quit<CR>]])

-- Close windows with q
-- https://github.com/folke/dot/blob/0e112e845b75f2f9f3ae61479824ca3de47a697f/config/nvim/lua/options.lua#L115
vim.cmd([[autocmd FileType help,startuptime,qf,lspinfo nnoremap <buffer><silent> q :close<CR>]])


-- Only show cursor line in active window
-- https://github.com/folke/dot/blob/0e112e845b75f2f9f3ae61479824ca3de47a697f/config/nvim/lua/options.lua#L96
cmd([[
	autocmd InsertLeave,WinEnter * set cursorline
	autocmd InsertEnter,WinLeave * set nocursorline
]])

-- TODO: Markdown
-- https://github.com/folke/dot/blob/0e112e845b75f2f9f3ae61479824ca3de47a697f/config/nvim/lua/options.lua#L90


