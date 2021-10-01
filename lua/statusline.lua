
-- Examples:
-- https://github.com/haorenW1025/dotfiles/blob/130dbf80e73e71cc8f6b89066f536417f455b088/nvim/lua/status-line.lua
-- https://www.reddit.com/r/neovim/comments/kco3l3/help_lua_statusline_the_stubborn_way/

-- =============================================================================
-- COLORS
-- =============================================================================
local execute = vim.api.nvim_command
local api     = vim.api
local cmd     = vim.cmd
local wo      = vim.wo

local default = '%#StatusLine#'
local white   = '%#StatusLineWhite#'
local red     = '%#StatusLineRed#'
local green   = '%#StatusLineGreen#'
local yellow  = '%#StatusLineYellow#'
local blue    = '%#StatusLineBlue#'
local magenta = '%#StatusLineMagenta#'
local cyan    = '%#StatusLineCyan#'

function set_color(name, fg, bg)
	local highlight_cmd = ''
	ctermfg = fg == nil and '' or ' ctermfg='..fg
	ctermbg = bg == nil and '' or ' ctermbg='..bg

	-- `highlight` doesn't work until after VimEnter:
	--https://www.reddit.com/r/neovim/comments/me35u9/comment/h2x5n7u/?utm_source=share&utm_medium=web2x&context=3
	highlight_cmd = highlight_cmd .. 'autocmd VimEnter * '

	highlight_cmd = highlight_cmd .. 'highlight '..name
	highlight_cmd = highlight_cmd .. ctermfg .. ctermbg
	--vim.cmd('echom "'..highlight_cmd..'"')
	execute(highlight_cmd)
end

set_color('StatusLineGreen',  46, 236)


-- =============================================================================
-- STATUS LINE LEFT
-- =============================================================================
function statusline_left()
	return green..'[%n] %F'
end


-- =============================================================================
-- STATUS LINE LEFT
-- =============================================================================
function statusline_right()
	local statusline = ''

	-- CurrentLine
	statusline = statusline..'%6l'
	-- TotalLines
	statusline = statusline..'/%L,'
	-- ColumnNumber
	statusline = statusline..'%-3c'
	-- PercentFile
	statusline = statusline..'[%3p%%]'

	return statusline

end


-- =============================================================================
-- STATUS LINE LEFT
-- =============================================================================
function statusline()
	local statusline = ''
	statusline = statusline..statusline_left()
	statusline = statusline..'%='
	statusline = statusline..statusline_right()

	return statusline
end
wo.statusline = '%!luaeval("statusline()")'

