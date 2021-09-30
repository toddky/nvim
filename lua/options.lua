
local execute = vim.api.nvim_command
local cmd = vim.cmd
local opt = vim.opt

-- Colorscheme
execute('colorscheme jellybeans')

-- Tab settings
opt.expandtab      = false;
opt.autoindent     = true;
opt.tabstop        = 4;
opt.shiftwidth     = 4;

-- List
opt.list           = true

-- Search
opt.ignorecase     = true
opt.incsearch      = true
opt.hlsearch       = true

opt.relativenumber = true
opt.backspace      = {"indent", "eol", "start"}
opt.virtualedit    = "block";
opt.encoding       = "utf-8";
opt.viewoptions    = "folds,cursor,curdir,slash,unix";
opt.sessionoptions = "curdir,help,tabpages,winsize";
opt.clipboard      = "unnamedplus";

-- Splits
opt.splitbelow     = true;
opt.splitright     = true;

-- =============================================================================
-- AUTOMATIC COMMANDS
-- =============================================================================

-- Open help on right split
cmd 'autocmd! BufEnter * if &ft ==# \'help\' | wincmd L | endif'

-- Recompile when plugins.lua is updated
--cmd 'autocmd BufWritePost plugins.lua PackerCompile'


