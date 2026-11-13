-- Git change signs diffed against the index, with hunk navigation, staging and reset.

local M = {}

local namespace = vim.api.nvim_create_namespace('git-signs')

-- Below the diagnostic sign priority (10), so a diagnostic wins a shared line.
local SIGN_PRIORITY = 6

-- A guess: long enough to skip most keystrokes while typing, short enough that signs feel live.
local RENDER_DELAY_MS = 100

-- A guess: far above a normal index read, short enough to notice a hung git on a network filesystem or a held lock.
local GIT_TIMEOUT_MS = 10000

-- Repo config is untrusted in a repo you only cloned, so git must not run commands it names.
--   * core.fsmonitor names a command git runs on an index read.
--   * core.hooksPath: an index write runs the post-index-change hook.
--   * safe.bareRepository=explicit: git refuses a repo checked in as plain files, so its config is never read.
local GIT_OVERRIDES = { 'core.fsmonitor=false', 'core.hooksPath=/dev/null', 'safe.bareRepository=explicit' }

-- A partial clone fetches a missing blob through the remote URL, which can name a command (ext::, core.sshCommand).
local GIT_ENVIRONMENT = { GIT_ALLOW_PROTOCOL = 'none', GIT_NO_LAZY_FETCH = '1' }

-- bufnr -> { dir, name, base, hunks, render_pending }. base is the index content, nil when the file is not tracked.
local states = {}

-- jobstart hands output over as lines, with each NUL inside a line turned into a newline.
local function job_output(data)
	local lines = vim.tbl_map(function(line) return (line:gsub('\n', '\0')) end, data)
	return table.concat(lines, '\n')
end

-- Runs git in dir without blocking; on_exit({ code, stdout, stderr }) runs on the main loop.
local function run_git(dir, arguments, stdin, on_exit)
	local command = { 'git' }
	for _, override in ipairs(GIT_OVERRIDES) do
		vim.list_extend(command, { '-c', override })
	end
	vim.list_extend(command, arguments)

	local result = { stdout = '', stderr = '' }
	local is_timed_out = false
	local job = vim.fn.jobstart(command, {
		cwd = dir,
		env = GIT_ENVIRONMENT,
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data) result.stdout = job_output(data) end,
		on_stderr = function(_, data) result.stderr = job_output(data) end,
		on_exit = function(_, code)
			result.code = code
			if is_timed_out then
				vim.notify(
					('git-signs: `git %s` in %s was stopped after %d s, check for a stale .git/index.lock or a hung mount')
						:format(table.concat(arguments, ' '), dir, GIT_TIMEOUT_MS / 1000),
					vim.log.levels.ERROR
				)
			end
			on_exit(result)
		end,
	})
	vim.defer_fn(function()
		if result.code then return end
		is_timed_out = true
		vim.fn.jobstop(job)
	end, GIT_TIMEOUT_MS)

	if stdin then vim.fn.chansend(job, stdin) end
	vim.fn.chanclose(job, 'stdin')
end

local function split_lines(text)
	local lines = vim.split(text, '\n', { plain = true })
	local ends_with_newline = lines[#lines] == ''
	if ends_with_newline then table.remove(lines) end
	return lines, ends_with_newline
end

-- The buffer as the bytes a write would produce, so it compares directly against the index content.
local function buffer_text(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 1 and lines[1] == '' then return '' end
	local newline = vim.bo[buf].fileformat == 'dos' and '\r\n' or '\n'
	local text = table.concat(lines, newline)
	if vim.bo[buf].eol or (vim.bo[buf].fixeol and not vim.bo[buf].binary) then text = text .. newline end
	return text
end

-- A deletion has no buffer lines of its own; its sign sits on the line above, or on line 1 at the top of the file.
local function first_line(hunk)
	return math.max(hunk.new_start, 1)
end

local function last_line(hunk)
	if hunk.new_count == 0 then return first_line(hunk) end
	return hunk.new_start + hunk.new_count - 1
end

local function place_sign(buf, line, text, highlight)
	vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
		sign_text = text,
		sign_hl_group = highlight,
		priority = SIGN_PRIORITY,
	})
end

local function render(buf)
	local state = states[buf]
	if not state or not vim.api.nvim_buf_is_loaded(buf) then return end

	state.hunks = {}
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	if not state.base then return end

	local indices = vim.diff(state.base, buffer_text(buf), { result_type = 'indices' })
	for _, index in ipairs(indices) do
		local hunk = { old_start = index[1], old_count = index[2], new_start = index[3], new_count = index[4] }
		table.insert(state.hunks, hunk)

		if hunk.new_count == 0 then
			place_sign(buf, first_line(hunk), hunk.new_start == 0 and '‾' or '_', 'Removed')
		else
			for offset = 0, hunk.new_count - 1 do
				local is_change = offset < hunk.old_count
				place_sign(buf, hunk.new_start + offset, is_change and '~' or '+', is_change and 'Changed' or 'Added')
			end
		end
	end
end

local function schedule_render(buf)
	local state = states[buf]
	if not state or not state.base or state.render_pending then return end
	state.render_pending = true
	vim.defer_fn(function()
		state.render_pending = false
		render(buf)
	end, RENDER_DELAY_MS)
end

-- Re-reads the file's index content, then redraws. Untracked files and files outside a repo get no signs.
local function refresh(buf)
	if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= '' then return end
	local name = vim.api.nvim_buf_get_name(buf)
	if name == '' then return end
	-- Resolve symlinks so git runs in the repo that owns the real file.
	local path = vim.uv.fs_realpath(name)
	if not path then return end

	local dir = vim.fs.dirname(path)
	local basename = vim.fs.basename(path)
	run_git(dir, { 'show', ':./' .. basename }, nil, function(result)
		if not vim.api.nvim_buf_is_loaded(buf) then return end
		local state = states[buf] or {}
		states[buf] = state
		state.dir = dir
		state.name = basename
		state.base = result.code == 0 and result.stdout or nil
		render(buf)
	end)
end

local function refresh_all()
	for _, buf in ipairs(vim.tbl_keys(states)) do
		refresh(buf)
	end
end

-- Returns the buffer state and the hunk under the cursor, or nil after warning that there is none.
local function hunk_at_cursor()
	local buf = vim.api.nvim_get_current_buf()
	render(buf)
	local state = states[buf]
	local line = vim.api.nvim_win_get_cursor(0)[1]
	for _, hunk in ipairs(state and state.hunks or {}) do
		if first_line(hunk) <= line and line <= last_line(hunk) then return state, hunk end
	end
	vim.notify('git-signs: no hunk under the cursor', vim.log.levels.WARN)
end

function M.nav_hunk(direction)
	if direction ~= 'next' and direction ~= 'prev' then
		error(('git-signs: nav_hunk direction must be "next" or "prev", got %s'):format(vim.inspect(direction)))
	end

	local buf = vim.api.nvim_get_current_buf()
	render(buf)
	local hunks = states[buf] and states[buf].hunks or {}
	if #hunks == 0 then
		vim.notify('git-signs: no hunks in this buffer', vim.log.levels.WARN)
		return
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	local target
	if direction == 'next' then
		target = hunks[1]
		for _, hunk in ipairs(hunks) do
			if first_line(hunk) > line then
				target = hunk
				break
			end
		end
	else
		target = hunks[#hunks]
		for index = #hunks, 1, -1 do
			if last_line(hunks[index]) < line then
				target = hunks[index]
				break
			end
		end
	end

	vim.cmd("normal! m'")
	vim.api.nvim_win_set_cursor(0, { first_line(target), 0 })
end

-- Puts the index content back for the hunk under the cursor. The buffer is left modified, not written.
function M.reset_hunk()
	local state, hunk = hunk_at_cursor()
	if not hunk then return end

	local buf = vim.api.nvim_get_current_buf()
	local base_lines = split_lines(state.base)
	local replacement = vim.list_slice(base_lines, hunk.old_start, hunk.old_start + hunk.old_count - 1)
	if vim.bo[buf].fileformat == 'dos' then
		replacement = vim.tbl_map(function(line) return (line:gsub('\r$', '')) end, replacement)
	end

	-- For a deletion new_start is the line the removed text goes after, which is already the 0-based insert index.
	local start = hunk.new_count == 0 and hunk.new_start or hunk.new_start - 1
	vim.api.nvim_buf_set_lines(buf, start, start + hunk.new_count, false, replacement)
	render(buf)
end

-- Stages the hunk under the cursor from the buffer content, saved or not.
function M.stage_hunk()
	local state, hunk = hunk_at_cursor()
	if not hunk then return end

	local buf = vim.api.nvim_get_current_buf()
	local old_lines, old_ends_with_newline = split_lines(state.base)
	local new_lines, new_ends_with_newline = split_lines(buffer_text(buf))

	local body = {}
	local function add_side(prefix, lines, ends_with_newline, start, count)
		for index = start, start + count - 1 do
			table.insert(body, prefix .. lines[index])
			if index == #lines and not ends_with_newline then
				table.insert(body, '\\ No newline at end of file')
			end
		end
	end
	add_side('-', old_lines, old_ends_with_newline, hunk.old_start, hunk.old_count)
	add_side('+', new_lines, new_ends_with_newline, hunk.new_start, hunk.new_count)

	-- git apply reads patch paths relative to the repo root, even when run from a subdirectory.
	run_git(state.dir, { 'rev-parse', '--show-prefix' }, nil, function(prefix_result)
		if prefix_result.code ~= 0 then
			vim.notify(
				('git-signs: could not find the repo root for %s, is it still inside a git repo?\n%s')
					:format(state.dir, prefix_result.stderr),
				vim.log.levels.ERROR
			)
			return
		end
		local repo_path = vim.trim(prefix_result.stdout) .. state.name

		-- Where the hunk lands in the index once applied alone: a pure add starts one line later, a pure delete one earlier.
		local staged_start = hunk.old_start + (hunk.old_count == 0 and 1 or 0) - (hunk.new_count == 0 and 1 or 0)
		local patch = {
			('diff --git a/%s b/%s'):format(repo_path, repo_path),
			'--- a/' .. repo_path,
			'+++ b/' .. repo_path,
			('@@ -%d,%d +%d,%d @@'):format(hunk.old_start, hunk.old_count, staged_start, hunk.new_count),
		}
		vim.list_extend(patch, body)

		local stdin = table.concat(patch, '\n') .. '\n'
		run_git(state.dir, { 'apply', '--cached', '--unidiff-zero', '-' }, stdin, function(apply_result)
			if apply_result.code ~= 0 then
				vim.notify(
					('git-signs: could not stage the hunk in %s, check `git status` for a conflict or lock:\n%s')
						:format(repo_path, apply_result.stderr),
					vim.log.levels.ERROR
				)
				return
			end
			refresh(buf)
		end)
	end)
end

if vim.fn.executable('git') ~= 1 then return M end

local group = vim.api.nvim_create_augroup('git-signs', { clear = true })

vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost', 'FileChangedShellPost' }, {
	group = group,
	callback = function(args) refresh(args.buf) end,
})

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'TextChangedP' }, {
	group = group,
	callback = function(args) schedule_render(args.buf) end,
})

-- The index can change behind the buffer: a commit or `git add` in a shell, or any fugitive command.
vim.api.nvim_create_autocmd('FocusGained', { group = group, callback = refresh_all })
vim.api.nvim_create_autocmd('User', { group = group, pattern = 'FugitiveChanged', callback = refresh_all })

vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
	group = group,
	callback = function(args) states[args.buf] = nil end,
})

for _, buf in ipairs(vim.api.nvim_list_bufs()) do
	refresh(buf)
end

return M
