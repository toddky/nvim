
local opt = vim.opt

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

