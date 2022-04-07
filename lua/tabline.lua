
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/alvarosevilla95/luatab.nvim/blob/master/lua/luatab/init.lua
-- https://github.com/toddyamakawa/vim/blob/master/my-plugins/plugin/tabline.vim
-- https://github.com/akinsho/bufferline.nvim


-- =============================================================================
-- OPTIONS
-- =============================================================================
local execute = vim.api.nvim_command
local fn = vim.fn
local opt = vim.opt

-- Show if there are at least two tabs
opt.showtabline = 1


function tabline_color(name, ctermfg, ctermbg, guifg, guibg)
	-- `highlight` doesn't work until after VimEnter:
	--https://www.reddit.com/r/neovim/comments/me35u9/comment/h2x5n7u/?utm_source=share&utm_medium=web2x&context=3
	--local highlight_cmd = 'autocmd VimEnter * '
	local highlight_cmd = 'autocmd VimEnter * '
		.. 'highlight TabLine'..name
		.. (ctermfg == nil and '' or ' ctermfg='..ctermfg)
		.. (ctermbg == nil and ' ctermbg=none' or ' ctermbg='..ctermbg)
		.. (guifg == nil and '' or ' guifg='..guifg)
		.. (guibg == nil and ' guibg=none' or ' guibg='..guibg)
	--vim.cmd('echom "'..highlight_cmd..'"')
	execute(highlight_cmd)
end

local red     = '%#TabLineRed#'
local green   = '%#TabLineGreen#'
local yellow  = '%#TabLineYellow#'
local blue    = '%#TabLineBlue#'
local magenta = '%#TabLineMagenta#'
local cyan    = '%#TabLineCyan#'
local white   = '%#TabLineWhite#'
local other   = '%#Comment#'

local colors = require('colors')
local cterm = colors.cterm
local gui = colors.gui

tabline_color('Red'    , cterm.red    , nil, gui.red    , nil)
tabline_color('Green'  , cterm.green  , nil, gui.green  , nil)
tabline_color('Yellow' , cterm.yellow , nil, gui.yellow , nil)
tabline_color('Blue'   , cterm.blue   , nil, gui.blue   , nil)
tabline_color('Magenta', cterm.magenta, nil, gui.magenta, nil)
tabline_color('Cyan'   , cterm.cyan   , nil, gui.cyan   , nil)
tabline_color('White'  , cterm.white  , nil, gui.white  , nil)


-- =============================================================================
-- TAB LINE
-- =============================================================================

function tabname(tabnr)

	local buflist  = fn.tabpagebuflist(tabnr)
	local winnr    = fn.tabpagewinnr(tabnr)
	local bufnr    = buflist[1]
	local bufname  = fn.bufname(bufnr)
	local buftype  = fn.getbufvar(bufnr, '&buftype')
	local filetype = fn.getbufvar(bufnr, '&filetype')

	-- TODO: Check for any modified buffer in tab
	local modified = fn.getbufvar(bufnr, '&modified') == 1 and red..'~' or ''

	local current = tabnr == fn.tabpagenr()

	local tabname = ''
		.. (current and blue or other)..'['..tabnr..']'
		.. (current and white or other)..bufname
		.. modified
		.. (#buflist > 1 and other..'('..#buflist..')' or '')

	return tabname
end


function tabline()
	local tabline = ''

	tabnrs = fn.tabpagenr('$')
	--tabline = tabline .. yellow..'['..tabnrs..']  '
	tabline = tabline .. '%#LineNr#[NVIM] '

	for tabnr = 1, tabnrs, 1 do
		tabline = tabline .. tabname(tabnr) .. ' '
	end


	return tabline
end

opt.tabline = '%!luaeval("tabline()")'

