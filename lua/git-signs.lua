-- Replaces the parts of gitsigns.nvim this config used: change signs in the sign column,
-- and resetting, staging, and jumping between the hunk under the cursor.
-- Each buffer is diffed with Neovim's xdiff against the staged file, in the form `git add` would store it:
--   * Line-ending conversion (text, eol, autocrlf): CRLFs in the buffer count as LF when git add would convert them,
--     the diff is against the raw blob, and staging applies a patch with `git apply --cached` like gitsigns.
--   * ident or working-tree-encoding attributes: the diff is against git's working-tree form of the blob,
--     and staging runs `git hash-object --path` so git converts it back.
--   * filter attributes (git-lfs, git-crypt): no signs. Their drivers are commands from the repo's config,
--     and opening a file must never run code from a repo you only cloned. For the same reason every git call
--     turns off hooks, core.fsmonitor, repos found as plain files, and network fetches (see git_overrides).
-- Known limits: for ident and working-tree-encoding files, an index change in the milliseconds between reading
-- and writing it is lost, a wide (UTF-16/32) working-tree-encoding gets no signs, and core.eol=crlf combined with
-- ident or working-tree-encoding gets no signs; core.safecrlf is not enforced; check-attr prints a literal
-- text=set or ident=set like a set attribute (and =unset like unset), so those rare values follow the attribute.
-- Regression tests: tests/git-signs.lua (run tests/run-git-signs.sh).

local bit = require('bit')
local ffi = require('ffi')

local M = {}

-- =============================================================================
-- ENVIRONMENT
-- =============================================================================
local namespace = vim.api.nvim_create_namespace('git-signs')

-- Marks where a queued reset was pressed, so earlier resets that add or remove lines don't move it to another hunk.
local action_namespace = vim.api.nvim_create_namespace('git-signs-actions')

local signs = {
	add          = { text = '+', highlight = 'GitSignsAdd' },
	change       = { text = '~', highlight = 'GitSignsChange' },
	delete       = { text = '_', highlight = 'GitSignsDelete' },
	topdelete    = { text = '‾', highlight = 'GitSignsDelete' },
	changedelete = { text = '~', highlight = 'GitSignsChange' },
}

-- Typing triggers a diff per keystroke; wait for a pause instead.
local debounce_ms = 100

-- Diffing very large files on every pause in typing would lag.
local max_lines = 40000

-- A hung git (network filesystem, held lock) must not pile up processes forever.
local git_timeout_ms = 10000

-- Opening or saving dozens of files at once must not start dozens of processes; queue past this.
local max_running_git = 16

-- Repo config is untrusted, and a clone can carry a whole repo as ordinary files that git then finds in a subfolder.
--   * core.fsmonitor names a command git runs on any index read.
--   * core.hooksPath: every index write runs the post-index-change hook.
--   * safe.bareRepository=explicit: git refuses a repo found as plain files, so none of its config is read.
local git_overrides = { 'core.fsmonitor=false', 'core.hooksPath=/dev/null', 'safe.bareRepository=explicit' }
-- check-attr prints filter=set, filter=unset, and filter=unspecified the same as no filter, but git still runs a
-- driver by those names, so empty commands turn them off.
for _, name in ipairs({ 'set', 'unset', 'unspecified' }) do
	for _, command in ipairs({ 'clean', 'smudge', 'process' }) do
		table.insert(git_overrides, 'filter.' .. name .. '.' .. command .. '=')
	end
end

-- A partial clone fetches a missing object through the remote's URL, which can be `ext::<command>` or ssh with
-- core.sshCommand. GIT_ALLOW_PROTOCOL beats every protocol.* setting in repo config; GIT_NO_LAZY_FETCH stops the fetch.
-- LC_ALL=C keeps git's messages in English, since some are matched below.
local git_environment = { GIT_ALLOW_PROTOCOL = 'none', GIT_NO_LAZY_FETCH = '1', LC_ALL = 'C' }

-- Staging one hunk through a conversion that doesn't give back the staged file would change other lines too.
local not_round_trip_message = "git's ident or working-tree-encoding conversion doesn't give back the staged file "
	.. '(like an $Id$ expanded before ident was set), so staging one hunk would change other lines; use git add -p'

-- Only regular files diff like text; a symlink's or submodule's index entry is not the file's contents.
local text_modes = { ['100644'] = true, ['100755'] = true }

-- Only UTF-8 needs this: wide encodings (UTF-16/32) are skipped because their newlines aren't single bytes.
local utf8_byte_order_mark = '\239\187\191'

-- Control characters git's binary guess counts as printable: backspace, tab, form feed, and escape.
local printable_controls = { [8] = true, [9] = true, [12] = true, [27] = true }

-- Attributes that decide how `git add` converts a file; see read_index.
local conversion_attributes = { 'text', 'crlf', 'eol', 'filter', 'ident', 'working-tree-encoding' }

-- Per buffer: { file, root, relative_file, watched_files, watched_stamp, status, mode, index_text, conversion, hunks,
--               diffed_tick, generation, in_flight, timer, busy, pending_actions }
-- status is 'loading', 'tracked', 'untracked', 'external' (has a filter driver), or 'too_large'.
-- conversion is 'none', 'text' (CRLF becomes LF), 'auto' (same, unless the content looks binary), or 'filter'.
local buffers = {}

local num_running_git = 0
local waiting_git = {}


-- =============================================================================
-- HELPERS
-- =============================================================================
-- Colorschemes style Added/Changed/Removed; a colorscheme that sets GitSigns* directly still wins.
local function link_highlights()
	vim.api.nvim_set_hl(0, 'GitSignsAdd',    { link = 'Added',   default = true })
	vim.api.nvim_set_hl(0, 'GitSignsChange', { link = 'Changed', default = true })
	vim.api.nvim_set_hl(0, 'GitSignsDelete', { link = 'Removed', default = true })
end

-- jobstart hands output over as lines split on '\n', with each NUL byte turned into '\n'; rebuild the bytes.
local function job_output(data)
	local lines = {}
	for index, line in ipairs(data or { '' }) do
		lines[index] = (line:gsub('\n', '\0'))
	end
	return table.concat(lines, '\n')
end

-- Run git without blocking; on_exit({ code, stdout, stderr }) runs on the main loop. Never throws, even if git
-- vanished from PATH. Not vim.system: on Neovim 0.10 it sometimes reports success with empty output under load,
-- and an empty staged file makes reset delete the whole buffer.
local function run_git(command, stdin, on_exit)
	if num_running_git >= max_running_git then
		table.insert(waiting_git, { command, stdin, on_exit })
		return
	end
	num_running_git = num_running_git + 1
	local result = { code = 127, stdout = '', stderr = '' }
	local timer = assert(vim.uv.new_timer())
	local is_finished = false
	local function finish()
		if is_finished then
			return
		end
		is_finished = true
		timer:stop()
		timer:close()
		num_running_git = num_running_git - 1
		local next_job = table.remove(waiting_git, 1)
		if next_job then
			-- Not unpack: stdin is often nil, and a table with a hole has no reliable length.
			run_git(next_job[1], next_job[2], next_job[3])
		end
		on_exit(result)
	end
	-- Buffered output arrives before on_exit runs.
	local ok, job = pcall(vim.fn.jobstart, command, {
		env = git_environment,
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data) result.stdout = job_output(data) end,
		on_stderr = function(_, data) result.stderr = job_output(data) end,
		on_exit = function(_, code)
			result.code = code
			if result.timed_out then
				result.stderr = 'git timed out after ' .. git_timeout_ms / 1000 .. ' s ' .. result.stderr
			end
			finish()
		end,
	})
	if not ok or job <= 0 then
		result.stderr = 'could not start git: ' .. tostring(job)
		vim.schedule(finish)
		return
	end
	-- A hung git (network filesystem, held lock) is stopped; its on_exit then reports the failure.
	timer:start(git_timeout_ms, 0, vim.schedule_wrap(function()
		if not is_finished then
			result.timed_out = true
			vim.fn.jobstop(job)
		end
	end))
	if stdin then
		pcall(vim.fn.chansend, job, stdin)
	end
	pcall(vim.fn.chanclose, job, 'stdin')
end

-- Run several git commands at once; each job is { command, stdin }; on_done gets their results in the same order.
local function run_all(jobs, on_done)
	local results = {}
	local num_left = #jobs
	for index, job in ipairs(jobs) do
		run_git(job[1], job[2], function(result)
			results[index] = result
			num_left = num_left - 1
			if num_left == 0 then
				on_done(results)
			end
		end)
	end
end

-- --literal-pathspecs keeps names like 'foo[1].txt' from matching other files as globs.
local function git_command(root, arguments)
	local command = { 'git', '--literal-pathspecs', '-C', root }
	for _, override in ipairs(git_overrides) do
		vim.list_extend(command, { '-c', override })
	end
	vim.list_extend(command, arguments)
	return command
end

-- Identifies one version of each file; git replaces the index on every write, so its inode changes too.
local function files_stamp(paths)
	local stamps = {}
	for _, path in ipairs(paths or {}) do
		local stat = vim.uv.fs_stat(path)
		table.insert(stamps, stat and table.concat({ stat.ino, stat.size, stat.mtime.sec, stat.mtime.nsec }, ':') or '-')
	end
	return table.concat(stamps, ' ')
end

-- Files whose changes can change a buffer's diff: the index, plus the attribute and config files
-- that decide line-ending conversion. git_paths are the index, info/attributes, and config from --git-path.
local function watched_files(root, relative_file, git_paths)
	local files = vim.deepcopy(git_paths)
	local home = vim.env.HOME or ''
	-- git ignores an empty XDG_CONFIG_HOME.
	local config_home = vim.env.XDG_CONFIG_HOME
	if not config_home or config_home == '' then
		config_home = home .. '/.config'
	end
	vim.list_extend(files, { config_home .. '/git/attributes', config_home .. '/git/config', home .. '/.gitconfig' })
	local directory = root
	table.insert(files, directory .. '/.gitattributes')
	for part in vim.gsplit(vim.fs.dirname(relative_file), '/', { plain = true }) do
		if part ~= '.' and part ~= '' then
			directory = directory .. '/' .. part
			table.insert(files, directory .. '/.gitattributes')
		end
	end
	return files
end

-- Splits raw bytes on '\n'; '\r' stays on the line so CRLF survives.
local function split_text(text)
	local lines = vim.split(text, '\n', { plain = true })
	local has_final_newline = lines[#lines] == ''
	if has_final_newline then
		table.remove(lines)
	end
	return lines, has_final_newline
end

local function join_text(lines, has_final_newline)
	if #lines == 0 then
		return ''
	end
	return table.concat(lines, '\n') .. (has_final_newline and '\n' or '')
end

local function file_encoding(buffer)
	local encoding = vim.bo[buffer].fileencoding
	if encoding == '' then
		return vim.o.encoding
	end
	return encoding
end

-- vim.iconv on one line, with a newline after it: some encodings (CP1258, TCVN, Big5-HKSCS) hold back a line's
-- last character in case a combining mark follows, and stateful ones (UTF-7, ISO-2022-JP) close a run only at
-- a newline; vim.iconv never flushes either, and a newline does.
-- vim.iconv puts '?' in place of a character it can't convert instead of failing, so is_strict returns nil when
-- the output has more '?' than the line and converting back doesn't give the line again. ISO-2022-JP and JOHAB
-- use the byte '?' inside some characters (与 is ESC $ B M ?), which the conversion back accepts; the count
-- alone is kept for the rest, since a round trip wrongly fails some valid CP1258 text.
-- Neovim converts to latin1 and latin9 itself, not through iconv: it writes 0xBF (¿) for a character they can't
-- hold and drops combining marks, so those always need the round trip.
local function convert_line(line, from, to, is_strict)
	local converted = vim.iconv(line .. '\n', from, to)
	if not converted or converted:sub(-1) ~= '\n' then
		return nil
	end
	converted = converted:sub(1, -2)
	if not is_strict then
		return converted
	end
	local is_builtin_latin = vim.iconv('\196\128', 'utf-8', to) == '\191'
	local has_new_question_marks = select(2, converted:gsub('%?', '')) > select(2, line:gsub('%?', ''))
	if (is_builtin_latin or has_new_question_marks) and vim.iconv(converted .. '\n', to, from) ~= line .. '\n' then
		return nil
	end
	return converted
end


-- Whether text in this encoding can be handled a line at a time: a newline is the single byte '\n', and
-- converting lines one by one (with convert_line) gives the same bytes as converting the whole text. Wide
-- encodings (UTF-16/32, UCS-2/4, and their many aliases) fail the first, and vim.iconv out of them crashes
-- Neovim 0.10 on a partial character. An encoding iconv doesn't know fails both. The second has caught nothing
-- convert_line doesn't already handle; it stays as a backstop. The probe is lossy in most legacy encodings,
-- so it is converted leniently.
local function is_line_encoding(encoding)
	-- vim.iconv returns nil from UTF-8 to UTF-8.
	if vim.tbl_contains({ 'utf-8', 'utf8' }, encoding:lower()) then
		return true
	end
	-- Non-ASCII last, so a stateful encoding is left mid-run at the end of the line.
	local probe = 'a\195\169\230\151\165'
	local line = convert_line(probe, 'utf-8', encoding)
	return vim.iconv('\n', 'utf-8', encoding) == '\n' and line ~= nil
		and vim.iconv(probe .. '\n' .. probe .. '\n', 'utf-8', encoding) == line .. '\n' .. line .. '\n'
end

-- Byte-wise line diffs need line-at-a-time encodings, so skip wide or stateful ones and classic-Mac CR-only files.
local function is_diffable(buffer)
	local is_mac = vim.bo[buffer].fileformat == 'mac' and not vim.bo[buffer].binary
	return is_line_encoding(file_encoding(buffer)) and not is_mac
end

-- The exact bytes :write would put on disk for the buffer.
-- With is_strict, returns nil and the line number when a line has a character the encoding can't hold.
local function buffer_text(buffer, is_strict)
	local options = vim.bo[buffer]
	local encoding = file_encoding(buffer)
	-- :write ignores 'bomb' when 'binary' is set.
	local byte_order_mark = (options.bomb and not options.binary and encoding == 'utf-8') and utf8_byte_order_mark or ''
	local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
	-- A buffer emptied with ggdG writes an empty file (just the BOM, if set) even though it still shows one empty line.
	if #lines == 1 and lines[1] == '' then
		local num_bytes = vim.api.nvim_buf_call(buffer, function() return vim.fn.wordcount().bytes end)
		if num_bytes == 0 then
			return byte_order_mark
		end
	end

	if encoding ~= 'utf-8' then
		for index, line in ipairs(lines) do
			local converted = convert_line(line, 'utf-8', encoding, is_strict)
			if not converted and is_strict then
				return nil, index
			end
			lines[index] = converted or line
		end
	end
	-- 'binary' writes plain LF and only adds a final newline when 'endofline' is set.
	local separator = (options.fileformat == 'dos' and not options.binary) and '\r\n' or '\n'
	local text = table.concat(lines, separator)
	-- The user chose to count 'fixendofline': it adds the final newline on write even while 'endofline' is off.
	if options.endofline or (options.fixendofline and not options.binary) then
		text = text .. separator
	end
	return byte_order_mark .. text
end

-- Git's guess at binary content for text=auto and autocrlf, ported byte for byte from gather_convert_stats and
-- convert_is_binary in convert.c: a NUL, a lone CR, or more than one control character per 128 printable bytes.
-- Returns is_binary, num_crlf. One pass over the bytes through ffi; pattern counting took 70 ms on a 2 MB file.
local function convert_stats(text)
	local bytes = ffi.cast('const uint8_t *', text)
	local size = #text
	local num_crlf, num_lone_cr, num_nul, num_printable, num_nonprintable = 0, 0, 0, 0, 0
	local index = 0
	while index < size do
		local byte = bytes[index]
		if byte == 13 then
			if index + 1 < size and bytes[index + 1] == 10 then
				num_crlf = num_crlf + 1
				index = index + 1
			else
				num_lone_cr = num_lone_cr + 1
			end
		elseif byte == 127 or (byte < 32 and byte ~= 10 and not printable_controls[byte]) then
			-- NUL counts as both NUL and non-printable.
			if byte == 0 then
				num_nul = num_nul + 1
			end
			num_nonprintable = num_nonprintable + 1
		elseif byte ~= 10 then
			num_printable = num_printable + 1
		end
		index = index + 1
	end
	-- A final ^Z (DOS end of file) is not held against the file.
	if size > 0 and bytes[size - 1] == 26 then
		num_nonprintable = num_nonprintable - 1
	end
	local is_binary = num_nul > 0 or num_lone_cr > 0 or bit.rshift(num_printable, 7) < num_nonprintable
	return is_binary, num_crlf
end

-- The buffer's bytes as `git add` would store them: CRLF becomes LF when git converts line endings.
local function staged_form(conversion, text)
	-- Without a CR there is nothing to convert, and most files skip the binary guess.
	if not text:find('\r', 1, true) then
		return text
	end
	if conversion == 'text' or (conversion == 'auto' and not convert_stats(text)) then
		return (text:gsub('\r\n', '\n'))
	end
	return text
end

-- Turn staged bytes back into buffer lines: drop CRs that 'fileformat' supplies, a leading BOM, and re-encode.
-- Returns nil and the line number when a line isn't valid in the buffer's encoding.
-- A CR only comes from 'fileformat' when it ends a line that has a newline, and only when git keeps CRs;
-- under text or auto conversion a CR left in the staged text is part of the line.
local function decode_lines(buffer, raw_lines, first_line_number, conversion, last_line_has_newline)
	local encoding = file_encoding(buffer)
	local is_dos = vim.bo[buffer].fileformat == 'dos' and not vim.bo[buffer].binary
	local keeps_cr = conversion == 'none' or conversion == 'filter'
	local decoded = {}
	for offset, line in ipairs(raw_lines) do
		local has_newline = offset < #raw_lines or last_line_has_newline
		if is_dos and keeps_cr and has_newline then
			line = line:gsub('\r$', '')
		end
		-- Under 'binary', 'bomb' can't hold the BOM, so it stays as bytes in line 1.
		local can_use_bomb = encoding == 'utf-8' and not vim.bo[buffer].binary
		if first_line_number + offset - 1 == 1 and can_use_bomb and vim.startswith(line, utf8_byte_order_mark) then
			line = line:sub(#utf8_byte_order_mark + 1)
		end
		if encoding ~= 'utf-8' then
			line = convert_line(line, encoding, 'utf-8', true)
			if not line then
				return nil, first_line_number + offset - 1
			end
		end
		table.insert(decoded, line)
	end
	return decoded
end

-- result_type 'indices' always returns { index_start, index_count, buffer_start, buffer_count } lists.
local function diff_hunks(index_text, text)
	local indices = vim.diff(index_text, text, { result_type = 'indices' }) --[[@as integer[][] ]]
	local hunks = {}
	for _, index in ipairs(indices) do
		table.insert(hunks, {
			index_start = index[1],
			index_count = index[2],
			buffer_start = index[3],
			buffer_count = index[4],
		})
	end
	return hunks
end

-- Lines a hunk covers in the buffer; a pure deletion sits on the line above it, or line 1 at the top.
local function hunk_range(hunk)
	if hunk.buffer_count == 0 then
		local line = math.max(hunk.buffer_start, 1)
		return line, line
	end
	return hunk.buffer_start, hunk.buffer_start + hunk.buffer_count - 1
end

local function hunk_at(hunks, line)
	for _, hunk in ipairs(hunks) do
		local first, last = hunk_range(hunk)
		if line >= first and line <= last then
			return hunk
		end
	end
	return nil
end

-- True when the hunk covers the last line (or the missing final newline) on its index side.
local function reaches_index_end(hunk, num_index_lines)
	if hunk.index_count == 0 then
		return hunk.index_start >= num_index_lines
	end
	return hunk.index_start + hunk.index_count - 1 >= num_index_lines
end

-- C-quote a patch path; git unquotes any quoted name, so quoting always avoids guessing which names need it.
local function quote_path(path)
	local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\t'] = '\\t', ['\n'] = '\\n' }
	local quoted = path:gsub('[%c"\\\128-\255]', function(character)
		return escapes[character] or string.format('\\%03o', character:byte())
	end)
	return '"' .. quoted .. '"'
end

-- A patch for one hunk with up to 3 lines of context, for `git apply --cached`.
-- Context pins the hunk to its place: zero-context patches can apply a line off when neighbouring lines repeat.
-- Other hunks stay unstaged, so both sides share the same context lines and start at the same line.
local function hunk_patch(relative_file, index_text, text, hunk)
	local num_context = 3
	local index_lines, index_has_final_newline = split_text(index_text)
	local buffer_lines, buffer_has_final_newline = split_text(text)
	local no_newline = '\\ No newline at end of file'
	local old_name = quote_path('a/' .. relative_file)
	local new_name = quote_path('b/' .. relative_file)

	local num_lines_before = hunk.index_count == 0 and hunk.index_start or hunk.index_start - 1
	local first_context = math.max(num_lines_before - num_context + 1, 1)
	local after_hunk = num_lines_before + hunk.index_count + 1
	local last_context = math.min(after_hunk + num_context - 1, #index_lines)
	local num_before = num_lines_before - first_context + 1
	local num_after = math.max(last_context - after_hunk + 1, 0)
	local num_old = num_before + hunk.index_count + num_after
	local num_new = num_before + hunk.buffer_count + num_after
	local old_start = num_old == 0 and 0 or first_context
	local new_start = num_new == 0 and 0 or first_context

	local patch = {}
	table.insert(patch, 'diff --git ' .. old_name .. ' ' .. new_name)
	table.insert(patch, '--- ' .. old_name)
	table.insert(patch, '+++ ' .. new_name)
	table.insert(patch, string.format('@@ -%d,%d +%d,%d @@', old_start, num_old, new_start, num_new))
	for line = first_context, num_lines_before do
		table.insert(patch, ' ' .. index_lines[line])
	end
	for line = hunk.index_start, hunk.index_start + hunk.index_count - 1 do
		table.insert(patch, '-' .. index_lines[line])
	end
	-- Only the file's last line can lack a newline; with trailing context that line is context, shared by both sides.
	if hunk.index_count > 0 and num_after == 0 and reaches_index_end(hunk, #index_lines) and not index_has_final_newline then
		table.insert(patch, no_newline)
	end
	local buffer_end = hunk.buffer_start + hunk.buffer_count - 1
	for line = hunk.buffer_start, buffer_end do
		table.insert(patch, '+' .. buffer_lines[line])
	end
	if hunk.buffer_count > 0 and buffer_end >= #buffer_lines and not buffer_has_final_newline then
		table.insert(patch, no_newline)
	end
	for line = after_hunk, last_context do
		table.insert(patch, ' ' .. index_lines[line])
	end
	if num_after > 0 and last_context == #index_lines and not index_has_final_newline then
		table.insert(patch, no_newline)
	end
	return table.concat(patch, '\n') .. '\n'
end


-- =============================================================================
-- DIFF
-- =============================================================================
local function place_signs(buffer, hunks)
	vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
	local num_lines = vim.api.nvim_buf_line_count(buffer)
	for _, hunk in ipairs(hunks) do
		local placements = {}
		if hunk.index_count == 0 then
			for line = hunk.buffer_start, hunk.buffer_start + hunk.buffer_count - 1 do
				placements[line] = 'add'
			end
		elseif hunk.buffer_count == 0 then
			local kind = hunk.buffer_start == 0 and 'topdelete' or 'delete'
			placements[math.max(hunk.buffer_start, 1)] = kind
		else
			local last_line = hunk.buffer_start + hunk.buffer_count - 1
			for line = hunk.buffer_start, last_line do
				placements[line] = 'change'
			end
			-- More lines removed than added: mark the last changed line, like gitsigns did.
			if hunk.index_count > hunk.buffer_count then
				placements[last_line] = 'changedelete'
			end
		end
		for line, kind in pairs(placements) do
			-- A trailing-newline change can point one past the last line; keep the sign on a real line.
			local row = math.max(math.min(line, num_lines), 1) - 1
			local sign = signs[kind]
			vim.api.nvim_buf_set_extmark(buffer, namespace, row, 0, {
				sign_text = sign.text,
				sign_hl_group = sign.highlight,
				priority = 6,
			})
		end
	end
end

local function notify_update(buffer)
	vim.api.nvim_exec_autocmds('User', { pattern = 'GitSignsUpdate', modeline = false, data = { buffer = buffer } })
end

-- Mark a buffer as having nothing to diff but keep its state, so BufEnter doesn't rerun git until something changes.
local function mark_not_diffed(buffer, state, status)
	state.status = status
	state.hunks = {}
	if vim.api.nvim_buf_is_loaded(buffer) then
		vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
	end
	notify_update(buffer)
end

-- Diff the buffer against the cached index text; cheap enough to run after every pause in typing.
local function update(buffer)
	local state = buffers[buffer]
	-- Timers and git callbacks can land after :bdelete unloaded the buffer, which then reports zero lines.
	if not state or state.status ~= 'tracked' or not vim.api.nvim_buf_is_loaded(buffer) then
		return
	end
	if vim.api.nvim_buf_line_count(buffer) > max_lines then
		mark_not_diffed(buffer, state, 'too_large')
		return
	end
	-- 'fileformat' or 'fileencoding' can change after the file was loaded; OptionSet attaches again when they change back.
	if not is_diffable(buffer) then
		M.detach(buffer)
		return
	end
	state.diffed_tick = vim.api.nvim_buf_get_changedtick(buffer)
	state.hunks = diff_hunks(state.index_text, staged_form(state.conversion, buffer_text(buffer)))
	place_signs(buffer, state.hunks)
	notify_update(buffer)
end

local refresh

local function schedule_update(buffer)
	local state = buffers[buffer]
	if not state then
		return
	end
	-- Deleting lines or undoing a big paste can bring a file back under the limit.
	if state.status == 'too_large' then
		refresh(buffer, 'enter')
		return
	end
	if state.status ~= 'tracked' then
		return
	end
	state.diffed_tick = nil
	if not state.timer then
		state.timer = vim.uv.new_timer()
	end
	state.timer:stop()
	state.timer:start(debounce_ms, 0, vim.schedule_wrap(function()
		update(buffer)
	end))
end

-- The encoding git converts the working tree to, or nil; git skips UTF-8 (same_encoding in utf8.c).
local function working_tree_encoding(attributes)
	local encoding = attributes['working-tree-encoding'] or 'unspecified'
	if vim.tbl_contains({ 'unspecified', 'unset', 'set', 'utf-8', 'utf8' }, encoding:lower()) then
		return nil
	end
	return encoding
end

local function names_filter(attributes)
	return not vim.tbl_contains({ 'unspecified', 'unset', 'set' }, attributes.filter or 'unspecified')
end

-- How `git add` converts this file, following convert_attrs() in git's convert.c:
--   * filter naming anything: 'external' -- a driver is a command from the repo's config, so it is never run.
--     git ignores a name with no driver configured, but a list of drivers could lose a line, so no signs either way.
--   * working-tree-encoding that can't be handled a line at a time (UTF-16 and the like): 'external'.
--   * ident (set), or working-tree-encoding other than UTF-8: 'filter' -- git converts in-process;
--     `cat-file --filters` and `hash-object --path` apply it.
--   * text, or its old name crlf: set or input converts, unset doesn't, auto converts text-looking content;
--     any other value is ignored, as git does.
--   * eol=lf or eol=crlf (exactly) implies text; otherwise core.autocrlf true or input (any case) behaves like text=auto.
-- autocrlf is `git config --type=bool-or-str` output: 'true', 'false', or a string like 'input'.
local function conversion_for(attributes, autocrlf)
	if names_filter(attributes) then
		return 'external'
	end
	local encoding = working_tree_encoding(attributes)
	if encoding and not is_line_encoding(encoding) then
		return 'external'
	end
	if attributes.ident == 'set' or encoding then
		return 'filter'
	end
	local actions = { set = 'text', input = 'text', auto = 'auto', unset = 'none' }
	local action = actions[attributes.text] or actions[attributes.crlf]
	if action then
		return action
	end
	if attributes.eol == 'lf' or attributes.eol == 'crlf' then
		return 'text'
	end
	autocrlf = vim.trim(autocrlf or ''):lower()
	if autocrlf == 'true' or autocrlf == 'input' then
		return 'auto'
	end
	return 'none'
end

-- Wrap a git callback in the read path so a Lua error in it reaches on_error(nil, message) instead of
-- stopping the chain, which would leave the action queue busy for good.
local function guarded(on_error, step)
	return function(...)
		local ok, error_message = xpcall(step, debug.traceback, ...)
		if not ok then
			on_error(nil, 'internal error: ' .. tostring(error_message))
		end
	end
end

-- The raw blob through `cat-file --batch`, whose header gives its size, so output cut short (seen under heavy load,
-- with git still exiting 0) is caught instead of read as a shorter file and reset into the buffer.
-- on_read(text, nil, true), or on_read(nil, error_message).
local function read_blob(target, object, on_read)
	run_git(git_command(target.root, { 'cat-file', '--batch' }), object .. '\n', guarded(on_read, function(result)
		if result.code ~= 0 then
			on_read(nil, 'could not read the staged file: ' .. vim.trim(result.stderr))
			return
		end
		local header, body = result.stdout:match('^([^\n]*)\n(.*)$')
		local name, size = (header or ''):match('^(%x+) blob (%d+)$')
		size = name == object and tonumber(size) or nil
		if not size or #body ~= size + 1 then
			local expected = size and (size + 1 .. ' bytes') or 'a blob header'
			on_read(nil, string.format("could not read the staged file: git's output was cut short (expected %s, got %d)", expected, #result.stdout))
			return
		end
		on_read(body:sub(1, size), nil, true)
	end))
end

-- ident_to_worktree in convert.c: each $Id$, and each $Id:...$ with no line break and no space before its last
-- character (not another tool's ident), becomes '$Id: <object> $'.
local function expand_ident(raw_text, object)
	local parts = {}
	local position = 1
	while true do
		local dollar = raw_text:find('$', position, true)
		if not dollar then
			break
		end
		local rest = dollar + 1
		local span_end
		if raw_text:sub(rest, rest + 2) == 'Id:' then
			local closing = raw_text:find('$', rest + 3, true)
			if not closing then
				break
			end
			local inner = raw_text:sub(rest + 3, closing - 1)
			-- git looks for a space from the byte after 'Id: ' up to the closing '$', and allows one just before it.
			-- Only inside the span: searching the rest of the file made a long line of $Id:x spans quadratic.
			local space = inner:find(' ', 2, true)
			local is_foreign = space and space < #inner
			if not inner:find('\n', 1, true) and not is_foreign then
				span_end = closing
			end
		elseif raw_text:sub(rest, rest + 2) == 'Id$' then
			span_end = rest + 2
		end
		if span_end then
			table.insert(parts, raw_text:sub(position, dollar - 1))
			table.insert(parts, '$Id: ' .. object .. ' $')
			position = span_end + 1
		else
			table.insert(parts, raw_text:sub(position, dollar))
			position = rest
		end
	end
	table.insert(parts, raw_text:sub(position))
	return table.concat(parts)
end

-- Whether git turns lone LFs into CRLF on checkout: crlf_action from convert_attrs() and will_convert_lf_to_crlf()
-- in convert.c. core.eol is not read; a crlf setting there only makes the check below refuse.
local function converts_to_crlf(attributes, autocrlf, text)
	autocrlf = vim.trim(autocrlf or ''):lower()
	local actions = { set = 'text', unset = 'binary', input = 'text_input', auto = 'auto' }
	local action = actions[attributes.text] or actions[attributes.crlf] or 'undefined'
	if action == 'auto' and attributes.eol == 'lf' then
		action = 'auto_input'
	elseif action == 'auto' and attributes.eol == 'crlf' then
		action = 'auto_crlf'
	elseif action ~= 'binary' and attributes.eol == 'lf' then
		action = 'text_input'
	elseif action ~= 'binary' and attributes.eol == 'crlf' then
		action = 'text_crlf'
	end
	if action == 'undefined' then
		action = ({ ['true'] = 'auto_crlf', input = 'auto_input' })[autocrlf] or 'binary'
	elseif action == 'text' then
		action = autocrlf == 'true' and 'text_crlf' or 'text_input'
	elseif action == 'auto' then
		action = autocrlf == 'true' and 'auto_crlf' or 'auto_input'
	end
	if action ~= 'text_crlf' and action ~= 'auto_crlf' then
		return false
	end
	if not text:gsub('\r\n', ''):find('\n', 1, true) then
		return false
	end
	if action == 'auto_crlf' then
		return not text:find('\r', 1, true) and not convert_stats(text)
	end
	return true
end

-- git's working-tree form of the raw blob, worked out here as encode(crlf(ident(raw))) the way
-- convert_to_working_tree does, or nil if the encoding fails (git then passes the bytes through with a warning).
-- Comparing git's output with it byte for byte catches bytes lost anywhere.
local function working_form(raw_text, object, attributes, autocrlf)
	local text = attributes.ident == 'set' and expand_ident(raw_text, object) or raw_text
	if converts_to_crlf(attributes, autocrlf, text) then
		text = text:gsub('\r?\n', '\r\n')
	end
	local encoding = working_tree_encoding(attributes)
	if encoding then
		return vim.iconv(text, 'utf-8', encoding)
	end
	return text
end

-- Whether git's working-tree form ends cut off: with no final newline, git never flushes the encoder, so it
-- drops whatever the encoding holds back at the end (UTF-7 and ISO-2022-JP close a run only at a newline;
-- BIG5-HKSCS and EUC-JISX0213 hold some characters in case a combining mark follows). The buffer, converted with
-- a newline after each line, could then never match, and reset would delete the character. Tests the actual
-- last line, since which characters are held back depends on the encoding.
local function ends_unflushed(raw_text, object, attributes)
	local encoding = working_tree_encoding(attributes)
	if not encoding or vim.endswith(raw_text, '\n') then
		return false
	end
	local text = attributes.ident == 'set' and expand_ident(raw_text, object) or raw_text
	local last_line = text:match('[^\n]*$')
	return vim.iconv(last_line, 'utf-8', encoding) ~= convert_line(last_line, 'utf-8', encoding)
end

-- git's working-tree form of the blob (ident, working-tree-encoding). `cat-file --batch` reports the raw size,
-- not the filtered one, so a request for a random object name follows it: git always answers that with
-- '<name> missing', and output cut short (seen under heavy load, with git still exiting 0) loses that line.
-- working_form then checks it against the size-checked raw blob, which catches loss in the middle too.
-- round_trips means `hash-object --path` cleans the text back to the staged blob. Staging needs this, or lines
-- outside the hunk would change too. It is false for a $Id$ expanded before ident was set, or for CRLFs that
-- text=auto would keep (hash-object doesn't look at the index), and the text is still right for signs and reset.
-- on_read(text, nil, round_trips, is_cut_off) (see ends_unflushed), or on_read(nil, error_message).
local function read_filtered_blob(target, object, attributes, autocrlf, on_read)
	-- Batch input puts the path after the first space and skips leading blanks, so these names can't be sent.
	if target.relative_file:find('[\n\r]') or target.relative_file:find('^[ \t]') then
		on_read(nil, 'could not read the staged file: git cat-file --batch cannot take a path that starts with a blank or has a line break')
		return
	end
	-- Random, so a line in the file itself can't pass for the end.
	local end_marker = vim.uv.random(#object / 2):gsub('.', function(byte) return string.format('%02x', byte:byte()) end)
	local show_command = git_command(target.root, { 'cat-file', '--batch', '--filters' })
	local requests = object .. ' ' .. target.relative_file .. '\n' .. end_marker .. '\n'
	run_git(show_command, requests, guarded(on_read, function(show_result)
		if show_result.code ~= 0 then
			on_read(nil, 'could not read the staged file: ' .. vim.trim(show_result.stderr))
			return
		end
		local header_end = show_result.stdout:find('\n', 1, true)
		local header = header_end and show_result.stdout:sub(1, header_end - 1) or ''
		if header == object .. ' missing' then
			on_read(nil, 'could not read the staged file: git says ' .. header)
			return
		end
		local trailer = '\n' .. end_marker .. ' missing\n'
		if header:match('^(%x+) blob %d+$') ~= object or not vim.endswith(show_result.stdout, trailer)
			or #show_result.stdout < header_end + #trailer then
			on_read(nil, "could not read the staged file: git's output was cut short")
			return
		end
		local text = show_result.stdout:sub(header_end + 1, #show_result.stdout - #trailer)
		read_blob(target, object, guarded(on_read, function(raw_text, read_error)
			if not raw_text then
				on_read(nil, read_error)
				return
			end
			if text ~= working_form(raw_text, object, attributes, autocrlf) then
				local encode_error = show_result.stderr:match('[^\n]*failed to encode[^\n]*')
				on_read(nil, 'could not read the staged file: ' .. (encode_error or "git's output was cut short (it doesn't match the staged file)"))
				return
			end
			local check_command = git_command(target.root, { 'hash-object', '--path=' .. target.relative_file, '--stdin' })
			run_git(check_command, text, guarded(on_read, function(check_result)
				if check_result.code ~= 0 then
					on_read(nil, 'git hash-object failed: ' .. vim.trim(check_result.stderr))
					return
				end
				on_read(text, nil, check_result.stdout == object .. '\n', ends_unflushed(raw_text, object, attributes))
			end))
		end))
	end))
end

-- Read the staged file and how git converts it: on_done({ text, mode, conversion, round_trips, is_hidden }).
-- With 'filter' the text is git's working-tree form of the blob, otherwise the raw blob; see read_filtered_blob
-- for round_trips. is_hidden means skip-worktree or assume-unchanged, which staging must not clear.
-- on_done(nil) means not in the index as a regular file (untracked, a symlink or submodule, or conflicted);
-- on_done(nil, error_message) means git failed or its output came back incomplete;
-- on_done({ conversion = 'external' }) means a filter driver would have to run, so nothing was read.
local function read_index(target, on_done, should_continue)
	should_continue = should_continue or function() return true end
	local attribute_command = { 'check-attr', '-z' }
	vim.list_extend(attribute_command, conversion_attributes)
	vim.list_extend(attribute_command, { '--', target.relative_file })
	local jobs = {
		{ git_command(target.root, { 'ls-files', '-v', '-z', '--stage', '--error-unmatch', '--', target.relative_file }) },
		{ git_command(target.root, attribute_command) },
		-- --default= prints 'false' when unset, so empty output always means it was lost.
		{ git_command(target.root, { 'config', '--type=bool-or-str', '--default=', '--get', 'core.autocrlf' }) },
	}
	run_all(jobs, guarded(on_done, function(results)
		if not should_continue() then
			return
		end
		local list_result, attribute_result, config_result = unpack(results)
		-- git ends every line or -z field it prints, so output that doesn't end that way was cut short.
		-- check-attr -z prints a path, attribute, value triple per attribute.
		local fields = vim.split(attribute_result.stdout, '\0', { plain = true })
		-- --error-unmatch makes an untracked file exit 1, so empty output with exit 0 means it was lost.
		local is_untracked = list_result.code == 1 and list_result.stdout == '' and list_result.stderr:find('did not match', 1, true)
		local is_complete = (is_untracked or list_result.code == 0 and vim.endswith(list_result.stdout, '\0'))
			and attribute_result.code == 0 and #fields == 3 * #conversion_attributes + 1
			and config_result.code == 0 and vim.endswith(config_result.stdout, '\n')
		if not is_complete then
			local errors = vim.tbl_map(function(result) return vim.trim(result.stderr) end, results)
			on_done(nil, 'git failed or its output was cut short: ' .. vim.trim(table.concat(errors, ' ')))
			return
		end
		-- -v tags each stage-0 entry H, or S for skip-worktree, or lowercase for assume-unchanged. The path must be
		-- the file itself: after `notes/` is replaced by a file `notes`, the pathspec still matches `notes/x.md`.
		local entries = vim.split(list_result.stdout, '\0', { plain = true, trimempty = true })
		local tag, mode, object, path = (entries[1] or ''):match('^(%a) (%d+) (%x+) 0\t(.*)$')
		if #entries ~= 1 or path ~= target.relative_file or not text_modes[mode] or (#object ~= 40 and #object ~= 64) then
			on_done(nil)
			return
		end
		local is_hidden = tag ~= 'H'
		local attributes = {}
		for index = 1, #fields - 3, 3 do
			attributes[fields[index + 1]] = fields[index + 2]
		end
		local conversion = conversion_for(attributes, config_result.stdout)
		if conversion == 'external' then
			on_done({ conversion = conversion })
			return
		end

		local function read(on_read)
			if conversion == 'filter' then
				read_filtered_blob(target, object, attributes, config_result.stdout, on_read)
			else
				read_blob(target, object, on_read)
			end
		end
		read(guarded(on_done, function(text, read_error, round_trips, is_cut_off)
			if not should_continue() then
				return
			end
			if not text then
				on_done(nil, read_error)
				return
			end
			if is_cut_off then
				on_done({ conversion = 'external' })
				return
			end
			-- text=auto and autocrlf leave line endings alone once the staged file has CRLF and looks like text
			-- (has_crlf_in_index in convert.c).
			if conversion == 'auto' and text:find('\r', 1, true) then
				local is_binary, num_crlf = convert_stats(text)
				if num_crlf > 0 and not is_binary then
					conversion = 'none'
				end
			end
			on_done({ text = text, mode = mode, object = object, conversion = conversion, round_trips = round_trips, is_hidden = is_hidden })
		end))
	end))
end

-- Read git for a buffer. how is one of:
--   'enter': skip git when the file and every watched file are unchanged (BufEnter, reloads).
--   'event': the same, but also look for a repo again for a file outside one (writes, shell commands, focus).
--   'force': always read (after staging).
function refresh(buffer, how)
	if not vim.api.nvim_buf_is_loaded(buffer) or vim.bo[buffer].buftype ~= '' then
		return
	end
	local name = vim.api.nvim_buf_get_name(buffer)
	-- Resolve symlinks first so the repo is found from the real file, not from where the link lives.
	local file = name ~= '' and vim.uv.fs_realpath(name) or nil
	if not file or not is_diffable(buffer) then
		M.detach(buffer)
		return
	end

	local state = buffers[buffer]
	local is_too_large = vim.api.nvim_buf_line_count(buffer) > max_lines
	if state and state.file == file and how ~= 'force' then
		if state.in_flight or (state.status == 'too_large' and is_too_large) then
			return
		end
		-- Outside a repo nothing is watched; only events that can create one (git init) look again.
		local is_unchanged = files_stamp(state.watched_files) == state.watched_stamp
		if not state.watched_files then
			is_unchanged = how == 'enter'
		end
		if state.status ~= 'too_large' and is_unchanged then
			-- A reload from disk (autoread, :checktime) in a window that isn't current fires no TextChanged.
			-- BufReadPost fires before the reload finishes, so check once it has.
			vim.schedule(function()
				local is_stale = buffers[buffer] == state and state.status == 'tracked'
					and vim.api.nvim_buf_is_loaded(buffer) and state.diffed_tick ~= vim.api.nvim_buf_get_changedtick(buffer)
				if is_stale then
					update(buffer)
				end
			end)
			return
		end
	end
	if not state then
		state = { status = 'loading', hunks = {}, generation = 0, pending_actions = {} }
		buffers[buffer] = state
	end
	if state.file ~= file then
		state.root = nil
		state.watched_files = nil
		-- Don't keep showing the old name's signs while the new name is read.
		mark_not_diffed(buffer, state, 'loading')
	end
	-- Record the file before any git runs, so the BufEnter right after BufReadPost is skipped.
	state.file = file
	if is_too_large then
		mark_not_diffed(buffer, state, 'too_large')
		return
	end
	state.generation = state.generation + 1
	local generation = state.generation
	state.in_flight = generation
	local function is_current()
		return buffers[buffer] == state and state.generation == generation and vim.api.nvim_buf_is_loaded(buffer)
	end

	local function load_index()
		-- Stamped before reading, so an index written during the read is read again next time.
		state.watched_stamp = files_stamp(state.watched_files)
		read_index(state, function(index, error_message)
			state.in_flight = nil
			-- A failed read is tried again on the next BufEnter or event instead of waiting for a watched file to change.
			if error_message then
				state.watched_stamp = nil
				-- A bug in this module, not git: say so instead of quietly showing no signs.
				if vim.startswith(error_message, 'internal error:') then
					vim.notify('git-signs: ' .. error_message, vim.log.levels.ERROR)
				end
			end
			if index and index.conversion == 'external' then
				mark_not_diffed(buffer, state, 'external')
				return
			end
			-- Untracked, conflicted, or binary files leave the buffer unmarked like gitsigns did.
			if not index or index.text:find('\0', 1, true) then
				mark_not_diffed(buffer, state, 'untracked')
				return
			end
			state.index_text = index.text
			state.mode = index.mode
			state.conversion = index.conversion
			state.status = 'tracked'
			update(buffer)
		end, is_current)
	end

	if state.root then
		load_index()
		return
	end
	-- --git-path honors worktrees and GIT_INDEX_FILE; it prints paths relative to the -C directory.
	local directory = vim.fs.dirname(file)
	local command = git_command(directory, { 'rev-parse', '--show-toplevel' })
	vim.list_extend(command, { '--git-path', 'index', '--git-path', 'info/attributes', '--git-path', 'config' })
	local function on_error(_, error_message)
		state.in_flight = nil
		vim.notify('git-signs: ' .. error_message, vim.log.levels.ERROR)
	end
	run_git(command, nil, guarded(on_error, function(result)
		if not is_current() then
			return
		end
		local output = vim.split(vim.trim(result.stdout), '\n', { plain = true })
		local root = result.code == 0 and output[1] and vim.uv.fs_realpath(output[1]) or nil
		local root_prefix = root and (vim.endswith(root, '/') and root or root .. '/')
		-- A last path cut short would watch the wrong file.
		local is_complete = vim.endswith(result.stdout, '\n')
		if not root or #output ~= 4 or not is_complete or not vim.startswith(file, root_prefix) then
			state.in_flight = nil
			mark_not_diffed(buffer, state, 'untracked')
			return
		end
		state.root = root
		state.relative_file = file:sub(#root_prefix + 1)
		local git_paths = {}
		for index = 2, 4 do
			table.insert(git_paths, vim.startswith(output[index], '/') and output[index] or directory .. '/' .. output[index])
		end
		state.watched_files = watched_files(root, state.relative_file, git_paths)
		load_index()
	end))
end

-- Look up the state for an action, explaining why there is nothing to act on.
local function action_state(buffer)
	local state = buffers[buffer]
	local messages = {
		too_large = 'git-signs: file is over ' .. max_lines .. ' lines, so hunks are not tracked',
		loading = 'git-signs: still reading git; try again in a moment',
		external = "git-signs: file has a filter driver (like git-lfs); git-signs doesn't run the repo's filter commands",
	}
	if state and messages[state.status] then
		vim.notify(messages[state.status], vim.log.levels.WARN)
		return nil
	end
	if not state or state.status ~= 'tracked' or not state.root then
		vim.notify('git-signs: this buffer is not tracked by git', vim.log.levels.WARN)
		return nil
	end
	return state
end

-- Wrap one step of a queued action: report errors and release the queue so later actions still run.
local function protected(done, step)
	return function(...)
		local ok, error_message = xpcall(step, debug.traceback, ...)
		if not ok then
			vim.notify('git-signs: ' .. tostring(error_message), vim.log.levels.ERROR)
			done()
		end
	end
end

-- Run actions one at a time per buffer, so a second ,gh waits for the first to reach the index.
-- done() is safe to call more than once, and any error in a step releases the queue instead of jamming it.
local function enqueue(state, action)
	table.insert(state.pending_actions, action)
	if state.busy then
		return
	end
	local function run_next()
		local next_action = table.remove(state.pending_actions, 1)
		if not next_action then
			state.busy = false
			return
		end
		state.busy = true
		local is_done = false
		local function done()
			if is_done then
				return
			end
			is_done = true
			run_next()
		end
		protected(done, next_action)(done)
	end
	run_next()
end

-- The file an action was started on; a rename before it runs would otherwise redirect it to another file.
local function action_target(state)
	return { file = state.file, root = state.root, relative_file = state.relative_file }
end

local function target_still_matches(state, target)
	if state.file == target.file then
		return true
	end
	vim.notify('git-signs: buffer was renamed before git finished; nothing changed', vim.log.levels.WARN)
	return false
end


-- =============================================================================
-- ACTIONS
-- =============================================================================
function M.detach(buffer)
	local state = buffers[buffer]
	if state and state.timer then
		state.timer:stop()
		state.timer:close()
	end
	buffers[buffer] = nil
	if vim.api.nvim_buf_is_valid(buffer) then
		vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
	end
end

-- True while git is being read or an action is queued for the buffer; tests wait on this.
function M.pending(buffer)
	local state = buffers[buffer or vim.api.nvim_get_current_buf()]
	return state ~= nil and (state.busy or state.in_flight ~= nil)
end

-- Current hunks for a buffer, for tests and statuslines; nil when the buffer isn't tracked.
function M.hunks(buffer)
	local state = buffers[buffer or vim.api.nvim_get_current_buf()]
	if not state or state.status ~= 'tracked' then
		return nil
	end
	return vim.deepcopy(state.hunks)
end

-- Write text to a new temp file and check its size, so input lost on the way to git (as with a pipe) is caught.
-- Returns the path, or nil after reporting the failure.
local function write_temp_file(text)
	local temp_file = vim.fn.tempname()
	local file = io.open(temp_file, 'wb')
	local is_written = file and file:write(text) ~= nil
	is_written = file and file:close() and is_written and vim.fn.getfsize(temp_file) == #text
	if not is_written then
		os.remove(temp_file)
		vim.notify('git-signs: could not write ' .. temp_file, vim.log.levels.ERROR)
		return nil
	end
	return temp_file
end

-- Stage with a patch: git apply checks the patch and its context against the index while holding its lock,
-- so an index changed near the hunk since it was read is refused, not overwritten.
-- (Lines added or removed far from the hunk can still shift where it applies, as with any patch.)
-- The patch goes through a temp file: one cut just before '\ No newline at end of file' still applies.
local function stage_with_patch(target, index, text, hunk, done, on_staged)
	local temp_file = write_temp_file(hunk_patch(target.relative_file, index.text, text, hunk))
	if not temp_file then
		done()
		return
	end
	local apply_command = git_command(target.root, { 'apply', '--cached', '--whitespace=nowarn', '--no-ignore-whitespace', '--', temp_file })
	run_git(apply_command, nil, protected(done, function(result)
		os.remove(temp_file)
		if result.code ~= 0 then
			vim.notify('git-signs: git apply failed (did the index change?): ' .. vim.trim(result.stderr), vim.log.levels.ERROR)
		end
		on_staged()
	end))
end

-- Whether the new raw blob keeps every line outside the hunk byte for byte from the old one. ident, CRLF, and
-- encodings with a one-byte newline keep lines whole, so line numbers match those of the working-tree form.
local function keeps_other_lines(old_raw, new_raw, num_index_lines, num_staged_lines, hunk, reaches_end)
	local old_lines, old_has_final_newline = split_text(old_raw)
	local new_lines, new_has_final_newline = split_text(new_raw)
	if #old_lines ~= num_index_lines or #new_lines ~= num_staged_lines then
		return false
	end
	if not reaches_end and old_has_final_newline ~= new_has_final_newline then
		return false
	end
	local num_before = hunk.index_start - (hunk.index_count == 0 and 0 or 1)
	local num_after = num_index_lines - (hunk.index_count == 0 and hunk.index_start or hunk.index_start + hunk.index_count - 1)
	for line = 1, num_before do
		if old_lines[line] ~= new_lines[line] then
			return false
		end
	end
	for offset = 0, num_after - 1 do
		if old_lines[#old_lines - offset] ~= new_lines[#new_lines - offset] then
			return false
		end
	end
	return true
end

-- Stage through git's in-process filters (ident, working-tree-encoding): splice the buffer's lines into the
-- working-tree form of the staged file and let `git hash-object --path` run the clean filter, as `git add` would.
-- Only for index.round_trips, so lines outside the hunk clean back to exactly what is staged; the new blob is still
-- checked before update-index, since the hunk can flip git's whole-file guess (text=auto, autocrlf) and change
-- every line's ending.
local function stage_with_filters(target, index, text, hunk, done, on_staged)
	-- The final newline follows the buffer if the hunk reaches it.
	local index_lines, index_has_final_newline = split_text(index.text)
	local buffer_lines, buffer_has_final_newline = split_text(text)
	local staged_lines = vim.list_slice(index_lines, 1, hunk.index_start - (hunk.index_count == 0 and 0 or 1))
	vim.list_extend(staged_lines, vim.list_slice(buffer_lines, hunk.buffer_start, hunk.buffer_start + hunk.buffer_count - 1))
	local after_hunk = hunk.index_count == 0 and hunk.index_start + 1 or hunk.index_start + hunk.index_count
	vim.list_extend(staged_lines, vim.list_slice(index_lines, after_hunk, #index_lines))
	local has_final_newline = index_has_final_newline
	if reaches_index_end(hunk, #index_lines) then
		has_final_newline = buffer_has_final_newline
	end

	local temp_file = write_temp_file(join_text(staged_lines, has_final_newline))
	if not temp_file then
		done()
		return
	end
	local hash_command = git_command(target.root, { 'hash-object', '-w', '--path=' .. target.relative_file, '--', temp_file })
	run_git(hash_command, nil, protected(done, function(hash_result)
		os.remove(temp_file)
		-- A full object name and its newline, so a name cut short is not staged.
		local object = hash_result.stdout:match('^(%x+)\n$')
		if hash_result.code ~= 0 or not object or #object ~= #index.object then
			vim.notify('git-signs: git hash-object failed: ' .. vim.trim(hash_result.stderr), vim.log.levels.ERROR)
			done()
			return
		end
		read_blob(target, index.object, protected(done, function(old_raw, old_error)
			read_blob(target, object, protected(done, function(new_raw, new_error)
				if not old_raw or not new_raw then
					vim.notify('git-signs: ' .. (old_error or new_error), vim.log.levels.ERROR)
					done()
					return
				end
				if not keeps_other_lines(old_raw, new_raw, #index_lines, #staged_lines, hunk, reaches_index_end(hunk, #index_lines)) then
					vim.notify('git-signs: staging this hunk would change other lines too (it changes how git sees the whole file); use git add -p', vim.log.levels.ERROR)
					done()
					return
				end
				local cacheinfo = index.mode .. ',' .. object .. ',' .. target.relative_file
				run_git(git_command(target.root, { 'update-index', '--cacheinfo', cacheinfo }), nil, protected(done, function(update_result)
					if update_result.code ~= 0 then
						vim.notify('git-signs: git update-index failed: ' .. vim.trim(update_result.stderr), vim.log.levels.ERROR)
					end
					on_staged()
				end))
			end))
		end))
	end))
end

-- Stage the hunk under the cursor without blocking, against a freshly read index.
function M.stage_hunk()
	-- `git commit` points its editor at a temporary index (index.lock or next-index-*.lock); staging there would
	-- slip into the commit or be lost.
	local index_file = vim.env.GIT_INDEX_FILE or ''
	if vim.endswith(index_file, '.lock') then
		vim.notify('git-signs: not staging while git commit is running (GIT_INDEX_FILE=' .. index_file .. ')', vim.log.levels.WARN)
		return
	end
	local buffer = vim.api.nvim_get_current_buf()
	local state = action_state(buffer)
	if not state then
		return
	end
	local target = action_target(state)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local buffer_bytes, bad_line = buffer_text(buffer, true)
	if not buffer_bytes then
		vim.notify(string.format("git-signs: line %d has a character '%s' can't hold; not staging", bad_line, file_encoding(buffer)), vim.log.levels.ERROR)
		return
	end

	enqueue(state, function(done)
		if not target_still_matches(state, target) then
			done()
			return
		end
		read_index(target, protected(done, function(index, error_message)
			if not index or index.conversion == 'external' then
				vim.notify('git-signs: ' .. (error_message or 'could not read the staged file'), vim.log.levels.ERROR)
				done()
				return
			end
			if index.text:find('\0', 1, true) then
				vim.notify('git-signs: the staged file is binary; not staging', vim.log.levels.ERROR)
				done()
				return
			end
			-- git add refuses skip-worktree files and ignores assume-unchanged ones; writing the entry would clear
			-- the flag and un-hide local edits the user hid on purpose.
			if index.is_hidden then
				vim.notify('git-signs: file is marked skip-worktree or assume-unchanged; not staging', vim.log.levels.WARN)
				done()
				return
			end
			if not index.round_trips then
				vim.notify('git-signs: ' .. not_round_trip_message, vim.log.levels.ERROR)
				done()
				return
			end
			local text = staged_form(index.conversion, buffer_bytes)
			local hunk = hunk_at(diff_hunks(index.text, text), cursor_line)
			if not hunk then
				vim.notify('git-signs: no hunk under the cursor', vim.log.levels.WARN)
				done()
				return
			end
			local stage = index.conversion == 'filter' and stage_with_filters or stage_with_patch
			stage(target, index, text, hunk, done, function()
				-- The buffer may have been wiped while git ran; refresh skips unloaded buffers.
				refresh(buffer, 'force')
				done()
			end)
		end))
	end)
end

-- Put the staged lines back in place of the hunk under the cursor, against a freshly read index.
function M.reset_hunk()
	local buffer = vim.api.nvim_get_current_buf()
	if not vim.bo[buffer].modifiable then
		vim.notify("git-signs: buffer is not 'modifiable'", vim.log.levels.WARN)
		return
	end
	local state = action_state(buffer)
	if not state then
		return
	end
	local target = action_target(state)
	local cursor_row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local mark = vim.api.nvim_buf_set_extmark(buffer, action_namespace, cursor_row, 0, {})

	enqueue(state, function(done)
		local function finish()
			pcall(vim.api.nvim_buf_del_extmark, buffer, action_namespace, mark)
			done()
		end
		-- :bwipeout or :bdelete while this waited in the queue; there is nothing left to reset.
		if buffers[buffer] ~= state or not vim.api.nvim_buf_is_loaded(buffer) then
			finish()
			return
		end
		if not target_still_matches(state, target) then
			finish()
			return
		end
		-- Recorded when this action starts, after any earlier queued reset, so only edits made during the git read abort it.
		local changedtick = vim.api.nvim_buf_get_changedtick(buffer)
		read_index(target, protected(finish, function(index, error_message)
			if buffers[buffer] ~= state or not vim.api.nvim_buf_is_loaded(buffer) then
				finish()
				return
			end
			if vim.api.nvim_buf_get_changedtick(buffer) ~= changedtick then
				vim.notify('git-signs: buffer changed while reading git; reset again', vim.log.levels.WARN)
				finish()
				return
			end
			if not index or index.conversion == 'external' then
				vim.notify('git-signs: ' .. (error_message or 'could not read the staged file'), vim.log.levels.ERROR)
				finish()
				return
			end
			-- Like refresh: a binary staged file is never diffed, and vim.iconv can crash on a NUL in some encodings.
			if index.text:find('\0', 1, true) then
				vim.notify('git-signs: the staged file is binary; not resetting', vim.log.levels.ERROR)
				finish()
				return
			end
			-- Another plugin may have cleared every namespace, taking the mark with it.
			local position = vim.api.nvim_buf_get_extmark_by_id(buffer, action_namespace, mark, {})
			if not position[1] then
				vim.notify('git-signs: lost track of the hunk; reset again', vim.log.levels.WARN)
				finish()
				return
			end
			local index_text = index.text
			local text = staged_form(index.conversion, buffer_text(buffer))
			local hunks = diff_hunks(index_text, text)
			local hunk = hunk_at(hunks, position[1] + 1)
			if not hunk then
				vim.notify('git-signs: no hunk under the cursor', vim.log.levels.WARN)
				finish()
				return
			end

			local index_lines, index_has_final_newline = split_text(index_text)
			local buffer_lines, buffer_has_final_newline = split_text(text)
			local last_restored = hunk.index_start + hunk.index_count - 1
			local last_has_newline = last_restored < #index_lines or index_has_final_newline
			local restored, bad_line = decode_lines(buffer, vim.list_slice(index_lines, hunk.index_start, last_restored), hunk.index_start, index.conversion, last_has_newline)
			if not restored then
				vim.notify(string.format("git-signs: staged line %d isn't valid '%s'; not resetting", bad_line, file_encoding(buffer)), vim.log.levels.ERROR)
				finish()
				return
			end
			if #buffer_lines == 0 then
				vim.api.nvim_buf_set_lines(buffer, 0, -1, false, restored)
			elseif hunk.buffer_count == 0 then
				vim.api.nvim_buf_set_lines(buffer, hunk.buffer_start, hunk.buffer_start, false, restored)
			else
				local first = hunk.buffer_start - 1
				vim.api.nvim_buf_set_lines(buffer, first, first + hunk.buffer_count, false, restored)
			end

			-- Only after the lines changed: a failed set_lines must not leave 'endofline' flipped for the next :w.
			local buffer_end = hunk.buffer_start + math.max(hunk.buffer_count, 1) - 1
			local reaches_end = buffer_end >= #buffer_lines or reaches_index_end(hunk, #index_lines)
			-- Undo restores lines but not options, so say so whenever reset changes one; the user can then undo
			-- with u plus :set, and the next :w never changes the final newline or BOM without a word.
			local changed_options = {}
			-- An empty staged file writes 0 bytes whatever 'endofline' says, so leave it.
			-- Warn only when an option really changes: a BOM-only buffer has no final newline as text while
			-- 'endofline' is already on.
			local options = vim.bo[buffer]
			local is_eol_off = options.endofline ~= index_has_final_newline or options.fixendofline ~= index_has_final_newline
			if reaches_end and #index_lines > 0 and index_has_final_newline ~= buffer_has_final_newline and is_eol_off then
				options.endofline = index_has_final_newline
				options.fixendofline = index_has_final_newline
				table.insert(changed_options, index_has_final_newline and "'endofline' 'fixendofline'" or "'noendofline' 'nofixendofline'")
			end
			local has_byte_order_mark = vim.startswith(index_text, utf8_byte_order_mark)
			local reaches_start = hunk.index_start <= 1 and hunk.buffer_start <= 1
			local can_use_bomb = file_encoding(buffer) == 'utf-8' and not vim.bo[buffer].binary
			if reaches_start and can_use_bomb and vim.bo[buffer].bomb ~= has_byte_order_mark then
				vim.bo[buffer].bomb = has_byte_order_mark
				table.insert(changed_options, has_byte_order_mark and "'bomb'" or "'nobomb'")
			end
			if #changed_options > 0 then
				vim.notify('git-signs: reset also set ' .. table.concat(changed_options, ' ') .. ' to match the staged file; u does not undo option changes', vim.log.levels.WARN)
			end
			state.index_text = index_text
			state.mode = index.mode
			state.conversion = index.conversion
			update(buffer)
			-- Some staged bytes can't come back through the buffer, like LF lines in a 'fileformat=dos' buffer:
			-- check that what :write would now store holds the staged lines where the hunk was.
			local new_lines, new_has_final_newline = split_text(staged_form(index.conversion, buffer_text(buffer)))
			local first_restored = hunk.buffer_count == 0 and hunk.buffer_start + 1 or hunk.buffer_start
			local now_there = vim.list_slice(new_lines, first_restored, first_restored + hunk.index_count - 1)
			local is_restored = vim.deep_equal(now_there, vim.list_slice(index_lines, hunk.index_start, last_restored))
			if reaches_end and new_has_final_newline ~= index_has_final_newline then
				is_restored = false
			end
			if not is_restored then
				vim.notify("git-signs: the hunk's staged lines can't be restored exactly in this buffer (line endings or encoding); undo with u, or use :edit ++ff=unix or git restore", vim.log.levels.WARN)
			end
			finish()
		end))
	end)
end

-- Move to the next or previous hunk like gitsigns: count, jumplist entry, first non-blank, folds, 'wrapscan'.
function M.nav_hunk(direction)
	local buffer = vim.api.nvim_get_current_buf()
	local state = action_state(buffer)
	if not state then
		return
	end
	-- The debounced update may not have run yet; rediff only if the buffer changed since the last diff.
	if state.diffed_tick ~= vim.api.nvim_buf_get_changedtick(buffer) then
		update(buffer)
	end
	if not buffers[buffer] then
		return
	end
	local num_hunks = #state.hunks
	if num_hunks == 0 then
		vim.notify('git-signs: no hunks', vim.log.levels.INFO)
		return
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	local target = nil
	for _ = 1, vim.v.count1 do
		local found = nil
		if direction == 'prev' then
			for index = num_hunks, 1, -1 do
				if hunk_range(state.hunks[index]) < line then
					found = index
					break
				end
			end
			if not found and vim.o.wrapscan then
				found = num_hunks
			end
		else
			for index = 1, num_hunks do
				if hunk_range(state.hunks[index]) > line then
					found = index
					break
				end
			end
			if not found and vim.o.wrapscan then
				found = 1
			end
		end
		if not found then
			break
		end
		target = found
		line = hunk_range(state.hunks[target])
	end
	if not target then
		vim.notify('git-signs: no more hunks', vim.log.levels.INFO)
		return
	end

	vim.cmd("normal! m'")
	vim.api.nvim_win_set_cursor(0, { math.min(line, vim.api.nvim_buf_line_count(buffer)), 0 })
	vim.cmd('normal! ^')
	if vim.wo.foldenable then
		vim.cmd('normal! zv')
	end
	vim.api.nvim_echo({ { string.format('Hunk %d of %d', target, num_hunks) } }, false, {})
end


-- =============================================================================
-- SETUP
-- =============================================================================
link_highlights()

-- Same command name and actions as gitsigns, so existing mappings keep working.
local actions = {
	reset_hunk = function() M.reset_hunk() end,
	stage_hunk = function() M.stage_hunk() end,
	nav_hunk = function(direction) M.nav_hunk(direction or 'next') end,
}
vim.api.nvim_create_user_command('Gitsigns', function(command)
	if vim.fn.executable('git') == 0 then
		vim.notify('git-signs: git is not installed', vim.log.levels.WARN)
		return
	end
	local action = actions[command.fargs[1]]
	if not action then
		vim.notify('git-signs: unknown action: ' .. (command.fargs[1] or ''), vim.log.levels.ERROR)
		return
	end
	action(command.fargs[2])
end, {
	nargs = '+',
	complete = function() return vim.tbl_keys(actions) end,
})

-- Without git there is nothing to diff against, so skip the autocmds instead of erroring on every file.
if vim.fn.executable('git') == 0 then
	return M
end

local group = vim.api.nvim_create_augroup('git-signs', { clear = true })

vim.api.nvim_create_autocmd('ColorScheme', {
	group = group,
	callback = link_highlights,
})
-- Each refresh rereads git only if the file was renamed or a watched file changed, so these are cheap.
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufEnter' }, {
	group = group,
	callback = function(event) refresh(event.buf, 'enter') end,
})
-- A write can create the file or a repo around it, and :file renames the buffer without touching disk.
vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufFilePost' }, {
	group = group,
	callback = function(event) refresh(event.buf, 'event') end,
})

-- These options change what :write produces; 'fileformat' and 'fileencoding' can also make a file diffable again.
vim.api.nvim_create_autocmd('OptionSet', {
	group = group,
	pattern = { 'fileformat', 'fileencoding', 'endofline', 'fixendofline', 'bomb', 'binary' },
	callback = function()
		local buffer = vim.api.nvim_get_current_buf()
		local state = buffers[buffer]
		if state and state.status == 'tracked' then
			schedule_update(buffer)
			return
		end
		refresh(buffer, 'enter')
	end,
})

-- The index can change outside this buffer (shell commands, fugitive, another tmux pane); check every visible buffer.
local function refresh_visible_buffers()
	local visible_buffers = {}
	for _, window in ipairs(vim.api.nvim_list_wins()) do
		visible_buffers[vim.api.nvim_win_get_buf(window)] = true
	end
	for buffer in pairs(visible_buffers) do
		refresh(buffer, 'event')
	end
end
vim.api.nvim_create_autocmd({ 'FocusGained', 'ShellCmdPost' }, {
	group = group,
	callback = refresh_visible_buffers,
})
vim.api.nvim_create_autocmd('User', {
	group = group,
	pattern = 'FugitiveChanged',
	callback = refresh_visible_buffers,
})

vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
	group = group,
	callback = function(event) schedule_update(event.buf) end,
})
vim.api.nvim_create_autocmd({ 'BufUnload', 'BufWipeout' }, {
	group = group,
	callback = function(event) M.detach(event.buf) end,
})

return M
