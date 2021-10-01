
-- Examples:
-- https://github.com/haorenW1025/dotfiles/blob/130dbf80e73e71cc8f6b89066f536417f455b088/nvim/lua/status-line.lua
-- https://www.reddit.com/r/neovim/comments/kco3l3/help_lua_statusline_the_stubborn_way/

local execute = vim.api.nvim_command
local api     = vim.api
local cmd     = vim.cmd
local wo      = vim.wo

-- =============================================================================
-- COLORS
-- =============================================================================

function set_status_color(name, fg, bg)
	local highlight_cmd = ''
	ctermfg = fg == nil and '' or ' ctermfg='..fg
	ctermbg = bg == nil and '' or ' ctermbg='..bg

	-- `highlight` doesn't work until after VimEnter:
	--https://www.reddit.com/r/neovim/comments/me35u9/comment/h2x5n7u/?utm_source=share&utm_medium=web2x&context=3
	highlight_cmd = highlight_cmd .. 'autocmd VimEnter * '

	highlight_cmd = highlight_cmd .. 'highlight StatusLine'..name
	highlight_cmd = highlight_cmd .. ctermfg .. ctermbg
	--vim.cmd('echom "'..highlight_cmd..'"')
	execute(highlight_cmd)
end

--local default = '%#StatusLine#'
local red     = '%#StatusLineRed#'
local green   = '%#StatusLineGreen#'
local yellow  = '%#StatusLineYellow#'
local blue    = '%#StatusLineBlue#'
local magenta = '%#StatusLineMagenta#'
local cyan    = '%#StatusLineCyan#'
local white   = '%#StatusLineWhite#'

set_status_color('Red'    , 196, 236)
set_status_color('Green'  ,  46, 236)
set_status_color('Yellow' , 226, 236)
set_status_color('Blue'   ,  45, 236)
set_status_color('Magenta',  57, 236)
set_status_color('Cyan'   ,  45, 236)
set_status_color('White'  , 255, 236)


-- =============================================================================
-- STATUS LINE LEFT
-- =============================================================================
function statusline_left()
	local statusline = ''

	-- TODO: Add mode
	-- Set mode if not normal mode
	--let l:mode = mode()
	--let l:statusline .= (l:mode=='n') ? '' : l:red.'['.l:mode.'-mode]'

	-- Buffer number
	statusline = statusline..yellow..'[%n]'
	-- Modified
	statusline = statusline..red..'%m'
	-- relative/path/to/file
	statusline = statusline..white..'%f'

	return statusline
end



-- =============================================================================
-- STATUS LINE RIGHT
-- =============================================================================
function statusline_right()
	local statusline = ''

	-- CurrentLine
	statusline = statusline..yellow..'%6l'
	-- TotalLines
	statusline = statusline..white..'/%L,'
	-- ColumnNumber
	statusline = statusline..yellow..'%-3c'
	-- PercentFile
	statusline = statusline..white..'[%3p%%]'

	-- Filetype and syntax
	-- TODO: Move filetype and syntax into StatuslineFileInfo
	statusline = statusline..green..'[%{&filetype==&syntax?&filetype:&filetype.".".&syntax}]'
	--let l:statusline .= StatuslineFileInfo(a:width)

	-- TODO: Add file size

	-- Indent status
	statusline = statusline..blue..'[%{&expandtab?"s":"t"}%{&tabstop.&softtabstop.&shiftwidth}]'

	-- Scroll statusbar
	-- TODO: Implement this

	return statusline
end


-- =============================================================================
-- STATUS LINE
-- =============================================================================
function statusline()
	local statusline = ''
	statusline = statusline..statusline_left()
	statusline = statusline..'%='
	statusline = statusline..statusline_right()

	return statusline
end

--wo.statusline = '%!luaeval("statusline()")'
vim.opt.statusline = '%!luaeval("statusline()")'


