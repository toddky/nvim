-- Trimmed from https://github.com/lukas-reineke/indent-blankline.nvim lua/ibl/ at ece00d5 (v3.6.1), with this config's settings built in.
-- Removed: scope, hooks, :IBL commands, inlay hint handling, and the setup()/config API.

local api = vim.api
local uv = vim.uv or vim.loop

local namespace = api.nvim_create_namespace('indent_blankline')
local highlight_group = '@ibl.char'
local indent_char = '│'
-- Upstream defaults: redraw at most every 200 ms, draw 30 lines past each window edge, extmark priority 1.
local debounce_ms = 200
local viewport_padding = 30
local guide_priority = 1
local exclude_filetypes = { 'lspinfo', 'packer', 'checkhealth', 'help', 'man', 'gitcommit', 'TelescopePrompt', 'TelescopeResults', '' }
local exclude_buftypes = { 'terminal', 'nofile', 'quickfix', 'prompt' }
local preproc_patterns = { '^#%s*if', '^#%s*elif', '^#%s*else', '^#%s*endif', '^#%s*define', '^#%s*undef', '^#%s*warning', '^#%s*error' }
local has_end_regex = vim.regex('^\\s*\\(}\\|]\\|)\\|end\\)')
local has_repeat_linebreak = vim.fn.has('nvim-0.10') == 1

local TAB_START, TAB_START_SINGLE, TAB_FILL, TAB_END, SPACE, INDENT = 1, 2, 3, 4, 5, 6

local function contains(list, value)
	for _, item in pairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function is_indent(kind)
	return kind == INDENT or kind == TAB_START or kind == TAB_START_SINGLE
end

local function is_space_indent(kind)
	return kind == INDENT or kind == SPACE
end

local function get_whitespace(line)
	if not line then
		return ''
	end
	return line:match('^%s+') or ''
end

local function get_win(bufnr)
	local win_list = vim.fn.win_findbuf(bufnr)
	local current_tab = api.nvim_get_current_tabpage()
	for _, win in ipairs(win_list) do
		if api.nvim_win_get_tabpage(win) == current_tab then
			return win
		end
	end
	return win_list[1]
end

local function split_option(value, separator)
	return vim.split(value, separator, { plain = true })
end

local function get_listchars(bufnr)
	local list = vim.opt.list:get()
	local listchars = list and vim.opt.listchars:get() or nil

	if bufnr ~= api.nvim_get_current_buf() then
		local win = get_win(bufnr)
		if win then
			list = api.nvim_get_option_value('list', { win = win })
			if list then
				listchars = {}
				for _, key_value in ipairs(split_option(api.nvim_get_option_value('listchars', { win = win }), ',')) do
					local key, value = unpack(split_option(key_value, ':'))
					listchars[vim.trim(key)] = value
				end
			end
		end
	end

	if not list then
		return { tabstop_overwrite = false, space_char = ' ', tab_char_fill = ' ' }
	end

	local space_char = listchars.space or ' '
	local tab_chars = listchars.tab and vim.fn.split(listchars.tab, '\\zs') or { '^', 'I' }
	return {
		tabstop_overwrite = listchars.tab == nil,
		space_char = space_char,
		trail_char = listchars.trail,
		lead_char = listchars.lead,
		multispace_chars = listchars.multispace and vim.fn.split(listchars.multispace, '\\zs'),
		leadmultispace_chars = listchars.leadmultispace and vim.fn.split(listchars.leadmultispace, '\\zs'),
		tab_char_start = tab_chars[1] or space_char,
		tab_char_fill = tab_chars[2] or space_char,
		tab_char_end = tab_chars[3],
	}
end

local function get_offset(bufnr)
	local win, win_view, win_end
	if bufnr == api.nvim_get_current_buf() then
		win = 0
		win_view = vim.fn.winsaveview()
		win_end = vim.fn.line('w$')
	else
		win = get_win(bufnr)
		if not win then
			return 0, 0, 0, 0
		end
		win_view = api.nvim_win_call(win, vim.fn.winsaveview)
	end

	local win_height = api.nvim_win_get_height(win)
	win_end = win_end or win_height + win_view.topline
	if win_view.lnum > win_end then
		win_view.topline = win_view.lnum
		win_end = win_view.lnum + win_height
	end
	return win_view.leftcol, win_view.topline, win_end, win_height
end

local function has_repeat_indent(bufnr)
	if not has_repeat_linebreak then
		return false
	end
	local win = get_win(bufnr)
	if not api.nvim_get_option_value('breakindent', { win = win }) then
		return false
	end
	for _, key_value in ipairs(split_option(api.nvim_get_option_value('breakindentopt', { win = win }), ',')) do
		local key, value = unpack(split_option(key_value, ':'))
		key = vim.trim(key)
		if key == 'column' or key == 'sbr' or (key == 'shift' and (tonumber(value) or 0) < 0) then
			return false
		end
	end
	return true
end

-- Classifies each column of a line's leading whitespace as tab, space, or indent level.
-- indent_state carries the indent stack between lines so continuation lines don't add guides (smart_indent_cap).
local function get_indent(whitespace, opts, indent_state)
	indent_state = indent_state or { cap = false, stack = {} }
	local shiftwidth = opts.shiftwidth
	local tabstop = opts.tabstop
	local spaces, tabs, extra = 0, 0, 0
	local indent_cap = indent_state.stack[#indent_state.stack] or 0
	if indent_state.cap then
		indent_cap = indent_state.stack[1] or 0
		indent_state.cap = false
	end
	local varts = {}
	for _, value in ipairs(vim.split(opts.vartabstop, ',', { plain = true, trimempty = true })) do
		table.insert(varts, tonumber(value))
	end
	if shiftwidth == 0 then
		shiftwidth = tabstop
	end

	local whitespace_tbl = {}
	for char in whitespace:gmatch('.') do
		if char == '\t' then
			local tab_width = tabstop - ((spaces + extra - tabstop) % tabstop)
			while #varts > 0 do
				tabstop = table.remove(varts, 1)
				if tabstop > spaces + extra then
					tab_width = tabstop - spaces + extra
					break
				end
			end
			tabs = tabs + tab_width
			table.insert(whitespace_tbl, tab_width == 1 and TAB_START_SINGLE or TAB_START)
			for column = 2, tab_width do
				table.insert(whitespace_tbl, column == tab_width and TAB_END or TAB_FILL)
			end
		else
			local mod = (spaces + tabs + extra) % shiftwidth
			if contains(indent_state.stack, spaces + tabs) then
				table.insert(whitespace_tbl, INDENT)
				extra = extra + mod
			elseif mod ~= 0 then
				table.insert(whitespace_tbl, SPACE)
			elseif #whitespace_tbl < indent_cap then
				table.insert(whitespace_tbl, INDENT)
			else
				indent_state.cap = true
				table.insert(whitespace_tbl, SPACE)
			end
			spaces = spaces + 1
		end
	end

	local stack = {}
	for _, level in ipairs(indent_state.stack) do
		if level < spaces + tabs then
			table.insert(stack, level)
		end
	end
	table.insert(stack, spaces + tabs)
	indent_state.stack = stack
	return whitespace_tbl, indent_state
end

local function get_char_map(listchars, whitespace_only, blankline)
	return {
		[TAB_START] = listchars.tab_char_start or indent_char,
		[TAB_START_SINGLE] = listchars.tab_char_end or listchars.tab_char_start or indent_char,
		[TAB_FILL] = (blankline and ' ') or listchars.tab_char_fill,
		[TAB_END] = (blankline and ' ') or listchars.tab_char_end or listchars.tab_char_fill,
		[SPACE] = (blankline and ' ')
			or (whitespace_only and (listchars.trail_char or listchars.multispace_chars or listchars.space_char))
			or listchars.leadmultispace_chars
			or listchars.lead_char
			or listchars.multispace_chars
			or listchars.space_char,
		[INDENT] = indent_char,
	}
end

local function get_char(chars, index)
	if type(chars) == 'string' then
		return chars
	end
	return chars[((index - 1) % #chars) + 1]
end

local function setup_highlight()
	local whitespace_hl = api.nvim_get_hl(0, { name = 'Whitespace' })
	whitespace_hl.nocombine = true
	api.nvim_set_hl(0, highlight_group, whitespace_hl)
end

local function clear(bufnr, row)
	local line_start, line_end = 0, -1
	if row then
		line_start, line_end = row - 1, row
	end
	pcall(api.nvim_buf_clear_namespace, bufnr, namespace, line_start, line_end)
end

local function is_buffer_active(bufnr, filetypes)
	if contains(exclude_buftypes, api.nvim_get_option_value('buftype', { buf = bufnr })) then
		return false
	end
	for _, filetype in ipairs(filetypes) do
		if contains(exclude_filetypes, filetype) then
			return false
		end
	end
	return true
end

local function refresh(bufnr)
	if not api.nvim_buf_is_loaded(bufnr) then
		clear(bufnr)
		return
	end
	local filetype = api.nvim_get_option_value('filetype', { buf = bufnr })
	local filetypes = filetype == '' and { '' } or vim.split(filetype, '.', { plain = true, trimempty = true })
	if not is_buffer_active(bufnr, filetypes) then
		clear(bufnr)
		return
	end

	local left_offset, top_offset, win_end, win_height = get_offset(bufnr)
	if top_offset > win_end then
		return
	end

	local is_current_buffer = api.nvim_get_current_buf() == bufnr
	local offset = math.max(top_offset - 1 - viewport_padding, 0)
	local range = math.min(win_end + viewport_padding, api.nvim_buf_line_count(bufnr))
	local lines = api.nvim_buf_get_lines(bufnr, offset, range, false)

	local indent_opts = {
		tabstop = api.nvim_get_option_value('tabstop', { buf = bufnr }),
		vartabstop = api.nvim_get_option_value('vartabstop', { buf = bufnr }),
		shiftwidth = api.nvim_get_option_value('shiftwidth', { buf = bufnr }),
	}
	local listchars = get_listchars(bufnr)
	if listchars.tabstop_overwrite then
		indent_opts.tabstop = 2
		indent_opts.vartabstop = ''
	end

	-- Preprocessor lines start at column 0, so drawing them as indent 0 would cut every guide around an #ifdef.
	local line_skipped = {}
	if contains(filetypes, 'c') or contains(filetypes, 'cpp') then
		for i, line in ipairs(lines) do
			for _, pattern in ipairs(preproc_patterns) do
				if line:match(pattern) then
					line_skipped[i] = true
					break
				end
			end
		end
	end

	local repeat_indent = has_repeat_indent(bufnr)
	local indent_state
	local next_whitespace_tbl = {}
	local empty_line_counter = 0
	local last_whitespace_tbl = {}

	for i, line in ipairs(lines) do
		local row = i + offset
		if line_skipped[i] then
			clear(bufnr, row)
			goto continue
		end

		local whitespace = get_whitespace(line)
		local foldclosed = is_current_buffer and vim.fn.foldclosed(row) or -1
		if foldclosed == row then
			local foldtext_whitespace = get_whitespace(vim.fn.foldtextresult(row))
			if vim.fn.strdisplaywidth(foldtext_whitespace, 0) < vim.fn.strdisplaywidth(whitespace, 0) then
				clear(bufnr, row)
				goto continue
			end
		end
		if foldclosed > -1 and foldclosed + win_height < row then
			clear(bufnr, row)
			goto continue
		end

		-- Blank lines take their guides from the next non-blank line, plus one level if that line closes a block.
		local whitespace_tbl
		local blankline = line:len() == 0
		if not blankline then
			whitespace_tbl, indent_state = get_indent(whitespace, indent_opts, indent_state)
		elseif empty_line_counter > 0 then
			empty_line_counter = empty_line_counter - 1
			whitespace_tbl = next_whitespace_tbl
		else
			if i == #lines then
				whitespace_tbl = {}
			else
				local j = i + 1
				while j < #lines and (lines[j]:len() == 0 or line_skipped[j]) do
					if not line_skipped[j] then
						empty_line_counter = empty_line_counter + 1
					end
					j = j + 1
				end

				whitespace_tbl, indent_state = get_indent(get_whitespace(lines[j]), indent_opts, indent_state)
				if has_end_regex:match_str(lines[j]) ~= nil then
					local trail = last_whitespace_tbl[indent_state.stack[#indent_state.stack] + 1]
					local trail_whitespace = last_whitespace_tbl[indent_state.stack[#indent_state.stack]]
					if trail then
						table.insert(whitespace_tbl, trail)
					elseif trail_whitespace then
						table.insert(whitespace_tbl, is_space_indent(trail_whitespace) and INDENT or TAB_START)
					end
				end
			end
			next_whitespace_tbl = whitespace_tbl
		end

		for _ = 1, math.min(left_offset, #whitespace_tbl) do
			table.remove(whitespace_tbl, 1)
		end
		last_whitespace_tbl = whitespace_tbl

		local char_map = get_char_map(listchars, not blankline and line == whitespace, blankline)
		local virt_text = {}
		local indent_index = 1
		for _, kind in ipairs(whitespace_tbl) do
			table.insert(virt_text, { get_char(char_map[kind], indent_index), highlight_group })
			if is_indent(kind) then
				indent_index = indent_index + 1
			end
		end

		clear(bufnr, row)
		if #virt_text > 0 then
			api.nvim_buf_set_extmark(bufnr, namespace, row - 1, 0, {
				virt_text = virt_text,
				virt_text_pos = 'overlay',
				virt_text_repeat_linebreak = repeat_indent or nil,
				hl_mode = 'combine',
				priority = guide_priority,
				strict = false,
			})
		end

		::continue::
	end
end

local function refresh_all()
	for _, win in ipairs(api.nvim_list_wins()) do
		api.nvim_win_call(win, function()
			refresh(api.nvim_win_get_buf(win))
		end)
	end
end

local timers = {}
local queued = {}

-- Draws now, then batches further requests in the next debounce_ms into one redraw; 50 ms is upstream's cutoff.
local function debounce_buffer(bufnr)
	if not timers[bufnr] then
		timers[bufnr] = uv.new_timer()
	end
	if uv.timer_get_due_in(timers[bufnr]) > 50 then
		queued[bufnr] = true
		return
	end
	queued[bufnr] = nil
	timers[bufnr]:start(debounce_ms, 0, function()
		if queued[bufnr] then
			queued[bufnr] = nil
			vim.schedule_wrap(refresh)(bufnr)
		end
	end)
	refresh(bufnr)
end

local function debounced_refresh(bufnr)
	-- Scrollbound windows move together, so every buffer on the tab page needs a redraw.
	if api.nvim_get_current_buf() == bufnr and api.nvim_get_option_value('scrollbind', { scope = 'local' }) then
		for _, bound_bufnr in ipairs(vim.fn.tabpagebuflist()) do
			debounce_buffer(bound_bufnr)
		end
		return
	end
	debounce_buffer(bufnr)
end

local group = api.nvim_create_augroup('IndentBlankline', {})
local buffer_leftcol = {}

api.nvim_create_autocmd('VimEnter', { group = group, callback = refresh_all })
api.nvim_create_autocmd({
	'CursorMoved',
	'CursorMovedI',
	'BufWinEnter',
	'CompleteChanged',
	'FileChangedShellPost',
	'FileType',
	'TextChanged',
	'TextChangedI',
}, {
	group = group,
	callback = function(event)
		debounced_refresh(event.buf)
	end,
})
api.nvim_create_autocmd('OptionSet', {
	group = group,
	pattern = 'list,listchars,shiftwidth,tabstop,vartabstop,breakindent,breakindentopt',
	callback = function(event)
		debounced_refresh(event.buf)
	end,
})
api.nvim_create_autocmd('WinScrolled', {
	group = group,
	callback = function(event)
		local leftcol = vim.fn.winsaveview().leftcol
		-- Horizontal scrolling shifts every guide, so it redraws without waiting for the debounce.
		if buffer_leftcol[event.buf] ~= leftcol then
			buffer_leftcol[event.buf] = leftcol
			refresh(event.buf)
			return
		end
		debounced_refresh(event.buf)
	end,
})
api.nvim_create_autocmd('ColorScheme', {
	group = group,
	callback = function()
		setup_highlight()
		refresh_all()
	end,
})

setup_highlight()
refresh_all()
