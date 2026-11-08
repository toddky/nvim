
-- =============================================================================
-- OPTIONS
-- =============================================================================
local execute = vim.api.nvim_command
local fn = vim.fn
local opt = vim.opt

-- Show if there are at least two tabs
opt.showtabline = 1


local function tabline_color(name, ctermfg, ctermbg, guifg, guibg)
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

-- TabLineFill and TabLine come from the colorscheme; the rest are defined below.
local fill      = '%#TabLineFill#'
local normal    = '%#TabLine#'
local red       = '%#TabLineRed#'
local sel_red   = '%#TabLineSelRed#'
local sel_blue  = '%#TabLineSelBlue#'
local sel_white = '%#TabLineSelWhite#'
local sel_dim   = '%#TabLineSelDim#'

local colors = require('colors')
local cterm = colors.cterm
local gui = colors.gui

-- Picked by eye to stand out from the #242424 bar; ela_perfect's TabLineSel #393939 was too close to it.
local cterm_sel_bg = 240
local gui_sel_bg = '#585858'

tabline_color('Red'     , cterm.red  , cterm.bg    , gui.red  , gui.bg)
tabline_color('SelRed'  , cterm.red  , cterm_sel_bg, gui.red  , gui_sel_bg)
tabline_color('SelBlue' , cterm.blue , cterm_sel_bg, gui.blue , gui_sel_bg)
tabline_color('SelWhite', cterm.white, cterm_sel_bg, gui.white, gui_sel_bg)
-- Dimmer than the white name but light enough to read on the #585858 block; picked by eye.
tabline_color('SelDim'  , 251        , cterm_sel_bg, '#C6C6C6', gui_sel_bg)


-- =============================================================================
-- TABLINE
-- =============================================================================
local function tabname(tabnr)

	local buflist  = fn.tabpagebuflist(tabnr)
	local winnr    = fn.tabpagewinnr(tabnr)
	local bufnr    = buflist[winnr]
	local bufname  = fn.bufname(bufnr)

	local current = tabnr == fn.tabpagenr()

	-- TODO: Check for any modified buffer in tab
	local modified = fn.getbufvar(bufnr, '&modified') == 1 and (current and sel_red or red)..'~' or ''
	local count = #buflist > 1 and (current and sel_dim or normal)..'('..#buflist..')' or ''

	if current then
		return sel_blue..' ['..tabnr..']'..sel_white..bufname..modified..count..sel_white..' '
	end
	return normal..' ['..tabnr..']'..bufname..modified..count..normal..' '
end


function tabline()
	local rendered = normal..' [NVIM] '

	for tabnr = 1, fn.tabpagenr('$') do
		rendered = rendered .. fill .. tabname(tabnr)
	end

	return rendered .. fill
end

opt.tabline = '%!luaeval("tabline()")'

