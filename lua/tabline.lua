
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/alvarosevilla95/luatab.nvim/blob/master/lua/luatab/init.lua
-- https://github.com/toddyamakawa/vim/blob/master/my-plugins/plugin/tabline.vim


-- =============================================================================
-- OPTIONS
-- =============================================================================
local fn = vim.fn
local opt = vim.opt

opt.showtabline = 2


function tabline_color(name, ctermfg, ctermbg, guifg, guibg)
	-- `highlight` doesn't work until after VimEnter:
	--https://www.reddit.com/r/neovim/comments/me35u9/comment/h2x5n7u/?utm_source=share&utm_medium=web2x&context=3
	--local highlight_cmd = 'autocmd VimEnter * '
	local highlight_cmd = 'autocmd VimEnter * '
		.. 'highlight TabLine'..name
		.. (ctermfg == nil and '' or ' ctermfg='..ctermfg)
		.. (ctermbg == nil and '' or ' ctermbg='..ctermbg)
		.. (guifg == nil and '' or ' guifg='..guifg)
		.. (guibg == nil and '' or ' guibg='..guibg)
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


local guibg = 'NONE'

-- TODO: Uncommenting this makes everything stop working
--tabline_color('Red'    , 196, 236, '#E080A0', guibg)



-- =============================================================================
-- TAB LINE
-- =============================================================================

function title(bufnr)
	local bufname = fn.bufname(bufnr)
	local buftype = fn.getbufvar(bufnr, '&buftype')
	local filetype = fn.getbufvar(bufnr, '&filetype')

	modified = fn.getbufvar(bufnr, '&modified') == 1 and red..'~' or ''

	return '[' .. bufnr .. ']' .. bufname .. modified
end


function tabline()
	local tabline = ''

	for bufnr = 1, fn.tabpagenr('$'), 1 do
		tabline = tabline .. title(bufnr) .. ' '
	end


	return tabline
end

-- REVISIT: Set this when I get this working
--opt.tabline = '%!luaeval("tabline()")'


