
-- =============================================================================
-- SETUP
-- =============================================================================
local execute = vim.api.nvim_command
local cmd = vim.cmd
local opt = vim.opt


-- =============================================================================
-- COLORSCHEME
-- =============================================================================
--execute('colorscheme jellybeans')
execute('colorscheme nord')
execute('colorscheme catppuccin_macchiato')


-- =============================================================================
-- OPTIONS
-- =============================================================================
-- See `:help vim.o`

-- TODO: Set undodir
-- opt.undofile = true

-- Enable mouse mode
opt.mouse = 'a'

-- Tab settings
opt.expandtab      = false
opt.autoindent     = true
opt.tabstop        = 4
opt.shiftwidth     = 0
opt.softtabstop    = 0
opt.breakindent    = false

-- List
opt.list      = true
opt.listchars = {
	tab      = '▸ ',
	trail    = '·',
	precedes = '←',
	--space    = '·',
	lead    = '·',
	--This breaks hterm alignment: '↴',
	eol      = '↴',
	--eol      = '⌐',
	extends  = '»',
	precedes = '«',
}


-- Search
opt.ignorecase     = true
opt.smartcase      = true
opt.incsearch      = true
--opt.hlsearch       = true
opt.hlsearch       = false

opt.number         = true
opt.relativenumber = true

opt.backspace      = {"indent", "eol", "start"}
opt.virtualedit    = "block"
opt.encoding       = "utf-8"

opt.timeoutlen     = 300

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

-- Spelling
-- TODO: Figure out how to enable it for just comments
--opt.spell = true;


-- =============================================================================
-- MATCH
-- =============================================================================

-- Highlight trailing whitespace
cmd([[match Error /\v\s+$/]])

-- TODO: Invert selection colors
-- https://www.reddit.com/r/tmux/comments/vqpxol/comment/if1murd/
--vim.api.nvim_set_hl(0, "Visual", { nil,  nil, reverse = true })


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

-- TODO: Terminal
-- https://github.com/b0o/nvim-conf/blob/9b0377bc810b766b7580811a99780b98026602ad/lua/user/autocmds.lua#L31
--vim.cmd [[
  --augroup term
    --autocmd!
    --autocmd BufEnter  term://* call user#fn#termEnter(1)
    --autocmd TermClose term://* call user#fn#closeBufWins(expand('<abuf>'))
  --augroup END
--]]

-- Disable wrap in Telescope preview
cmd([[autocmd User TelescopePreviewerLoaded setlocal nowrap]])

-- Reset softtabstop and shiftwidth when tabstop changes
cmd([[autocmd OptionSet tabstop set sts=0 sw=0]])

