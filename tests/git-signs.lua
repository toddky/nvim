-- Regression tests for lua/git-signs.lua; run tests/run-git-signs.sh.
-- Each case builds a scratch repo with exact bytes, opens it with the real config, and checks hunks, staging, and reset.

local git_signs = require('git-signs')

-- =============================================================================
-- HELPERS
-- =============================================================================
local num_failures = 0
local num_passes = 0

local function check(name, condition, detail)
	if condition then
		num_passes = num_passes + 1
		io.stdout:write('PASS ' .. name .. '\n')
		return
	end
	num_failures = num_failures + 1
	io.stdout:write('FAIL ' .. name .. (detail and (': ' .. detail) or '') .. '\n')
end

local function shell(command)
	local result = vim.system({ 'bash', '-c', command }):wait()
	return result.stdout or '', result.code
end

local function write_bytes(file, bytes)
	local handle = assert(io.open(file, 'wb'))
	handle:write(bytes)
	handle:close()
end

local function read_bytes(file)
	local handle = assert(io.open(file, 'rb'))
	local bytes = handle:read('*a')
	handle:close()
	return bytes
end

local function commit(repo_dir, message)
	shell('git -C ' .. repo_dir .. ' -c user.email=t@t -c user.name=t commit -qam ' .. message)
end

-- A repo whose file holds committed_bytes in HEAD and the index, and working_bytes on disk.
local function make_repo(committed_bytes, working_bytes, file_name, git_config)
	file_name = file_name or 'file.txt'
	local repo_dir = vim.fn.tempname()
	vim.fn.mkdir(repo_dir, 'p')
	shell('git -C ' .. repo_dir .. ' init -q')
	for _, setting in ipairs(git_config or {}) do
		shell('git -C ' .. repo_dir .. ' config ' .. setting)
	end
	write_bytes(repo_dir .. '/' .. file_name, committed_bytes)
	shell('git -C ' .. repo_dir .. " add -- '" .. file_name .. "' && git -C " .. repo_dir .. ' -c user.email=t@t -c user.name=t commit -qm init')
	write_bytes(repo_dir .. '/' .. file_name, working_bytes or committed_bytes)
	return repo_dir
end

local function index_bytes(repo_dir, file_name)
	return (shell('git -C ' .. repo_dir .. " show ':0:" .. (file_name or 'file.txt') .. "'"))
end

local function wait_idle()
	vim.wait(5000, function() return not git_signs.pending() end, 10)
end

-- Open a file and wait until git-signs has read its index, so hunks reflect the file.
local function open(file)
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ' .. vim.fn.fnameescape(file))
	wait_idle()
end

local function hunk_summary()
	local summary = {}
	for _, hunk in ipairs(git_signs.hunks() or {}) do
		table.insert(summary, string.format('-%d,%d+%d,%d', hunk.index_start, hunk.index_count, hunk.buffer_start, hunk.buffer_count))
	end
	return table.concat(summary, ' ')
end

local function sign_summary()
	local marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()['git-signs'], 0, -1, { details = true })
	local summary = {}
	for _, mark in ipairs(marks) do
		table.insert(summary, { mark[2] + 1, vim.trim(mark[4].sign_text) })
	end
	table.sort(summary, function(a, b) return a[1] < b[1] end)
	return table.concat(vim.tbl_map(function(entry) return entry[1] .. entry[2] end, summary), ' ')
end

local function at(line, action)
	vim.api.nvim_win_set_cursor(0, { line, 0 })
	vim.cmd('Gitsigns ' .. action)
	wait_idle()
end

-- Stage or reset until no hunks remain, picking the first or last hunk each time.
local function apply_all(action, order)
	local num_applied = 0
	while #(git_signs.hunks() or {}) > 0 and num_applied < 20 do
		local hunks = git_signs.hunks() or {}
		local hunk = order == 'last' and hunks[#hunks] or hunks[1]
		at(math.max(hunk.buffer_start, 1), action)
		num_applied = num_applied + 1
	end
	return num_applied
end

local function written_bytes(repo_dir, file_name)
	vim.cmd('silent write')
	return read_bytes(repo_dir .. '/' .. (file_name or 'file.txt'))
end

local function error_messages()
	local messages = vim.fn.execute('messages')
	local errors = {}
	for line in messages:gmatch('[^\n]+') do
		if line:match('[Ee]rror') or line:match('E%d+:') then
			table.insert(errors, line)
		end
	end
	return table.concat(errors, ' | ')
end

-- Put a git wrapper first on PATH while body runs; script runs before the real git, which is in $real_git.
local function with_git_wrapper(script, body)
	local wrapper_bin = vim.fn.tempname()
	vim.fn.mkdir(wrapper_bin, 'p')
	local real_git = vim.fn.exepath('git')
	write_bytes(wrapper_bin .. '/git', '#!/usr/bin/env bash\nreal_git=' .. real_git .. '\n' .. script .. '\nexec "$real_git" "$@"\n')
	vim.fn.setfperm(wrapper_bin .. '/git', 'rwxr-xr-x')
	local original_path = vim.env.PATH
	vim.env.PATH = wrapper_bin .. ':' .. original_path
	body()
	vim.env.PATH = original_path
end

-- A git that sleeps before every call, to show slow git never blocks the editor.
local function with_slow_git(seconds, body)
	with_git_wrapper('sleep ' .. seconds, body)
end

-- Add a .gitattributes file to a repo and commit it.
local function set_attributes(repo_dir, attributes)
	write_bytes(repo_dir .. '/.gitattributes', attributes)
	-- Not commit -a: under the new attributes git would renormalize the other files as it re-adds them.
	shell('git -C ' .. repo_dir .. ' add .gitattributes && git -C ' .. repo_dir .. ' -c user.email=t@t -c user.name=t commit -qm attributes')
end

local function buffer_lines()
	return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '|')
end

local every_kind_committed = table.concat(vim.tbl_map(function(number) return 'line ' .. number end, vim.fn.range(1, 30)), '\n') .. '\n'
local function every_kind_working()
	local lines = vim.split(every_kind_committed, '\n', { plain = true })
	table.remove(lines)
	table.remove(lines, 1)                                   -- topdelete
	lines[4] = 'changed five'                                -- change
	table.insert(lines, 10, 'added b')                       -- add
	table.insert(lines, 10, 'added a')
	table.remove(lines, 16); table.remove(lines, 16)         -- delete
	table.remove(lines, 19); table.remove(lines, 19)         -- changedelete
	lines[19] = 'joined twenty'
	table.insert(lines, 'added at end')
	return table.concat(lines, '\n') .. '\n'
end


-- =============================================================================
-- EVERY HUNK KIND
-- =============================================================================
do
	local repo_dir = make_repo(every_kind_committed, every_kind_working())
	open(repo_dir .. '/file.txt')
	-- Expected hunks and signs are what gitsigns v2.1.0 reports for the same file.
	check('every kind: hunks match gitsigns', hunk_summary() == '-1,1+0,0 -5,1+4,1 -10,0+10,2 -15,2+15,0 -20,3+19,1 -30,0+28,1', hunk_summary())
	check('every kind: signs', sign_summary() == '1‾ 4~ 10+ 11+ 15_ 19~ 28+', sign_summary())

	local visited = {}
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	for _ = 1, 6 do
		vim.cmd('Gitsigns nav_hunk next')
		table.insert(visited, vim.fn.line('.'))
	end
	check('nav: next visits every hunk and wraps', table.concat(visited, ' ') == '4 10 15 19 28 1', table.concat(visited, ' '))
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.cmd('normal 2]g')
	check('nav: a count skips hunks', vim.fn.line('.') == 10, 'line ' .. vim.fn.line('.'))

	for _, order in ipairs({ 'first', 'last' }) do
		repo_dir = make_repo(every_kind_committed, every_kind_working())
		open(repo_dir .. '/file.txt')
		local num_staged = apply_all('stage_hunk', order)
		check('stage all, ' .. order .. ' hunk each time: index equals file', num_staged == 6 and index_bytes(repo_dir) == every_kind_working(), num_staged .. ' staged')
	end

	-- Press stage on every hunk without waiting; the queue must apply them in order against the updated index.
	repo_dir = make_repo(every_kind_committed, every_kind_working())
	open(repo_dir .. '/file.txt')
	for _, hunk in ipairs(git_signs.hunks() or {}) do
		vim.api.nvim_win_set_cursor(0, { math.max(hunk.buffer_start, 1), 0 })
		vim.cmd('Gitsigns stage_hunk')
	end
	wait_idle()
	check('stage six hunks without waiting: index equals file', index_bytes(repo_dir) == every_kind_working())

	repo_dir = make_repo(every_kind_committed, every_kind_working())
	open(repo_dir .. '/file.txt')
	at(15, 'stage_hunk')
	local cached = shell('git -C ' .. repo_dir .. ' diff --cached -U0 | grep "^[-+@]" | grep -v "^[-+][-+][-+]"')
	check('stage one middle hunk: only it is staged', cached == '@@ -15,2 +14,0 @@ line 14\n-line 15\n-line 16\n' and #(git_signs.hunks() or {}) == 5, cached)

	repo_dir = make_repo(every_kind_committed, every_kind_working())
	open(repo_dir .. '/file.txt')
	apply_all('reset_hunk', 'first')
	check('reset all: file equals index', written_bytes(repo_dir) == every_kind_committed)
end


-- =============================================================================
-- FILE BYTES
-- =============================================================================
-- Unmodified files must show no hunks whatever their encoding, line endings, or BOM.
local unmodified_cases = {
	{ 'latin1', 'caf\233\nline two\n' },
	{ 'utf-8 BOM', '\239\187\191hello\nworld\n' },
	{ 'CRLF', 'a\r\nb\r\n' },
	{ 'mixed line endings', 'a\r\nb\nc\r\n' },
	{ 'single empty line', '\n' },
	{ 'empty file', '' },
	{ 'utf-8 BOM only', '\239\187\191' },
}
for _, case in ipairs(unmodified_cases) do
	local repo_dir = make_repo(case[2])
	open(repo_dir .. '/file.txt')
	check('unmodified ' .. case[1] .. ': no hunks', hunk_summary() == '', hunk_summary())
end

-- 'fixendofline' (on by default) makes :write add the missing newline, so the last line already differs.
do
	local repo_dir = make_repo('a\nb\nc')
	open(repo_dir .. '/file.txt')
	check('no final newline: last line marked because :w will add it', hunk_summary() == '-3,1+3,1', hunk_summary())
	vim.bo.fixendofline = false
	vim.api.nvim_exec_autocmds('TextChanged', {})
	vim.wait(500, function() return hunk_summary() == '' end, 10)
	check('no final newline with nofixeol: no hunks', hunk_summary() == '', hunk_summary())
end

-- Edit one line, stage it, and the index must hold exactly the bytes :write would produce.
local staging_cases = {
	{ 'no final newline, add after last line', 'a\nb\nc', function() vim.api.nvim_buf_set_lines(0, 3, 3, false, { 'added' }) end, 4, 'a\nb\nc\nadded\n' },
	{ 'no final newline, change last line', 'a\nb\nc', function() vim.api.nvim_buf_set_lines(0, 2, 3, false, { 'C' }) end, 3, 'a\nb\nC\n' },
	{ 'latin1 keeps its encoding', 'caf\233\nline two\n', function() vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'LINE TWO' }) end, 2, 'caf\233\nLINE TWO\n' },
	{ 'utf-8 BOM is kept', '\239\187\191hello\nworld\n', function() vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'WORLD' }) end, 2, '\239\187\191hello\nWORLD\n' },
	{ 'CRLF', 'a\r\nb\r\n', function() vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' }) end, 2, 'a\r\nB\r\n' },
	{ 'mixed line endings', 'a\r\nb\nc\r\n', function() vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' }) end, 2, 'a\r\nB\nc\r\n' },
	{ 'emptied buffer', 'x\ny\n', function() vim.cmd('silent normal! ggdG') end, 1, '' },
}
for _, case in ipairs(staging_cases) do
	local name, committed, edit, line, expected = unpack(case)
	local repo_dir = make_repo(committed)
	open(repo_dir .. '/file.txt')
	-- Stage straight after the edit, before the typing delay has redrawn the hunks.
	edit()
	at(line, 'stage_hunk')
	local staged = index_bytes(repo_dir)
	check('stage ' .. name, staged == expected, vim.inspect(staged))
end

-- Edit, reset, and write: the file must come back byte for byte.
local reset_cases = {
	{ 'no final newline', 'a\nb\nc', function() vim.api.nvim_buf_set_lines(0, 2, 3, false, { 'X' }) end, 3 },
	{ 'latin1', 'caf\233\nline two\n', function() vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'cafe' }) end, 1 },
	{ 'utf-8 BOM', '\239\187\191hello\nworld\n', function() vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'HELLO' }) end, 1 },
	{ 'CRLF', 'a\r\nb\r\n', function() vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' }) end, 2 },
	{ 'emptied file', 'x\ny\n', function() vim.api.nvim_buf_set_lines(0, 0, -1, false, {}) end, 1 },
	{ 'second-to-last line keeps the final newline', 'a\nb\nc\n', function() vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' }) end, 2 },
}
for _, case in ipairs(reset_cases) do
	local name, committed, edit, line = unpack(case)
	local repo_dir = make_repo(committed)
	open(repo_dir .. '/file.txt')
	edit()
	at(line, 'reset_hunk')
	check('reset ' .. name .. ': no hunks remain', hunk_summary() == '', hunk_summary())
	local written = written_bytes(repo_dir)
	check('reset ' .. name .. ': written file equals index', written == committed, vim.inspect(written))
end


-- =============================================================================
-- GIT BEHAVIOR
-- =============================================================================
do
	-- core.autocrlf: the index has LF while the working file has CRLF.
	local repo_dir = make_repo('a\nb\nc\n', nil, 'file.txt', { 'core.autocrlf true' })
	write_bytes(repo_dir .. '/file.txt', 'a\r\nb\r\nc\r\n')
	open(repo_dir .. '/file.txt')
	check('autocrlf: unmodified file has no hunks', hunk_summary() == '', hunk_summary())
	vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' })
	at(2, 'stage_hunk')
	check('autocrlf: staged index keeps LF', index_bytes(repo_dir) == 'a\nB\nc\n', vim.inspect(index_bytes(repo_dir)))

	-- The index changes outside Neovim with no focus event; staging must use the new index, not the cached one.
	local committed = table.concat(vim.tbl_map(function(number) return 'line ' .. number end, vim.fn.range(1, 20)), '\n') .. '\n'
	local working_lines = vim.split(committed, '\n', { plain = true })
	table.remove(working_lines)
	table.insert(working_lines, 10, 'NEW')
	table.remove(working_lines, 1); table.remove(working_lines, 1); table.remove(working_lines, 1)
	repo_dir = make_repo(committed, table.concat(working_lines, '\n') .. '\n')
	open(repo_dir .. '/file.txt')
	local without_top = table.concat(vim.tbl_map(function(number) return 'line ' .. number end, vim.fn.range(4, 20)), '\n') .. '\n'
	write_bytes(repo_dir .. '/without-top', without_top)
	shell('cd ' .. repo_dir .. ' && git update-index --cacheinfo 100644,$(git hash-object -w without-top),file.txt')
	at(7, 'stage_hunk')
	local expected = table.concat(working_lines, '\n') .. '\n'
	check('stage after the index changed outside Neovim', index_bytes(repo_dir) == expected, vim.inspect(index_bytes(repo_dir)))

	-- `git show :0:notes.txt` would be read as stage 0 of notes.txt without the explicit :0: prefix.
	repo_dir = make_repo('x\n', 'X\n', '0:notes.txt')
	write_bytes(repo_dir .. '/notes.txt', 'other\n')
	shell('git -C ' .. repo_dir .. ' add notes.txt && git -C ' .. repo_dir .. ' -c user.email=t@t -c user.name=t commit -qm notes')
	open(repo_dir .. '/0:notes.txt')
	check('file named 0:notes.txt diffs against itself', hunk_summary() == '-1,1+1,1', hunk_summary())
	at(1, 'reset_hunk')
	check('file named 0:notes.txt resets to its own text', table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n') == 'x')

	-- A repo's apply.whitespace=error must not reject a hunk with trailing whitespace.
	repo_dir = make_repo('a\n', 'a  \n', 'file.txt', { 'apply.whitespace error' })
	open(repo_dir .. '/file.txt')
	at(1, 'stage_hunk')
	check('apply.whitespace=error: trailing whitespace stages', index_bytes(repo_dir) == 'a  \n', vim.inspect(index_bytes(repo_dir)))

	-- Without autocrlf, converting a file to CRLF is a real change; staging stores it like `git add`.
	repo_dir = make_repo('a\nb\n', 'a\r\nb\r\n')
	open(repo_dir .. '/file.txt')
	check('CRLF conversion without autocrlf: shows as a change', hunk_summary() == '-1,2+1,2', hunk_summary())
	at(1, 'stage_hunk')
	check('CRLF conversion without autocrlf: stages CRLF like git add', index_bytes(repo_dir) == 'a\r\nb\r\n', vim.inspect(index_bytes(repo_dir)))

	-- A filter driver (like git-lfs or git-crypt) is a command from the repo's config: opening must never run it.
	repo_dir = vim.fn.tempname()
	vim.fn.mkdir(repo_dir, 'p')
	write_bytes(repo_dir .. '/.gitattributes', '*.up filter=evil\n')
	write_bytes(repo_dir .. '/file.up', 'hello\n')
	shell('cd ' .. repo_dir .. ' && git init -q && git add . && git -c user.email=t@t -c user.name=t commit -qm init')
	shell('cd ' .. repo_dir .. " && git config filter.evil.smudge 'touch RAN; cat' && git config filter.evil.clean 'touch RAN; cat'")
	open(repo_dir .. '/file.up')
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'HELLO' })
	at(1, 'stage_hunk')
	check('filter driver: no signs', git_signs.hunks() == nil)
	check('filter driver: opening and staging never run it', vim.uv.fs_stat(repo_dir .. '/RAN') == nil)
	check('filter driver: index untouched', index_bytes(repo_dir, 'file.up') == 'hello\n', vim.inspect(index_bytes(repo_dir, 'file.up')))

	-- ident runs inside git, so it is still diffed and staged through git's own conversion.
	repo_dir = make_repo('$Id$\nb\n')
	set_attributes(repo_dir, '* ident\n')
	shell('cd ' .. repo_dir .. ' && rm file.txt && git checkout -- file.txt')
	open(repo_dir .. '/file.txt')
	check('ident: expanded working copy has no hunks', hunk_summary() == '', hunk_summary())
	vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' })
	at(2, 'stage_hunk')
	check('ident: staging collapses $Id$', index_bytes(repo_dir) == '$Id$\nB\n', vim.inspect(index_bytes(repo_dir)))

	-- 'foo[1].txt' is a glob that also matches 'foo1.txt'; staging must touch only the opened file.
	repo_dir = make_repo('a\nb\n', 'a\nB\n', 'foo[1].txt')
	write_bytes(repo_dir .. '/foo1.txt', 'one\r\n')
	shell('git -C ' .. repo_dir .. ' add foo1.txt && git -C ' .. repo_dir .. ' -c user.email=t@t -c user.name=t commit -qm foo1')
	open(repo_dir .. '/foo[1].txt')
	check('glob-like file name: hunks from its own index entry', hunk_summary() == '-2,1+2,1', hunk_summary())
	at(2, 'stage_hunk')
	check('glob-like file name: stages only that file', index_bytes(repo_dir, 'foo[1].txt') == 'a\nB\n' and index_bytes(repo_dir, 'foo1.txt') == 'one\r\n')

	-- :file renames the buffer without writing; it must stop diffing against the old file.
	repo_dir = make_repo('a\n', 'A\n')
	open(repo_dir .. '/file.txt')
	vim.cmd('silent file ' .. repo_dir .. '/renamed.txt')
	wait_idle()
	check(':file rename to an untracked name: no hunks', git_signs.hunks() == nil)
end


-- =============================================================================
-- PATHS
-- =============================================================================
do
	-- A link in one repo pointing into another repo belongs to the target's repo.
	local repo_a = make_repo('a\n')
	local repo_b = make_repo('one\ntwo\n', 'one\nTWO\n')
	vim.uv.fs_symlink(repo_b .. '/file.txt', repo_a .. '/link.txt')
	open(repo_a .. '/link.txt')
	check('symlink into another repo: hunks come from the target repo', hunk_summary() == '-2,1+2,1', hunk_summary())
	at(2, 'stage_hunk')
	check('symlink into another repo: stages into the target repo', index_bytes(repo_b) == 'one\nTWO\n' and shell('git -C ' .. repo_a .. ' diff --cached --stat') == '')

	-- Dotfile style: a link outside any repo pointing into one.
	local outside_dir = vim.fn.tempname()
	vim.fn.mkdir(outside_dir, 'p')
	local repo_c = make_repo('one\ntwo\n', 'one\nTWO\n')
	vim.uv.fs_symlink(repo_c .. '/file.txt', outside_dir .. '/dotfile')
	open(outside_dir .. '/dotfile')
	check('dotfile symlink outside any repo: hunks from the target repo', hunk_summary() == '-2,1+2,1', hunk_summary())

	local repo_d = make_repo('a\n')
	write_bytes(repo_d .. '/untracked.txt', 'new\n')
	open(repo_d .. '/untracked.txt')
	check('untracked file: no hunks', git_signs.hunks() == nil)
	write_bytes(outside_dir .. '/plain.txt', 'plain\n')
	open(outside_dir .. '/plain.txt')
	check('file outside git: no hunks', git_signs.hunks() == nil)
end


-- =============================================================================
-- EDITOR BEHAVIOR
-- =============================================================================
do
	local repo_dir = make_repo('one\ntwo\nthree\nfour\n', 'one\n    two changed\nthree\nFOUR\n')
	open(repo_dir .. '/file.txt')
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.cmd('Gitsigns nav_hunk next')
	check('nav: lands on first non-blank', vim.fn.col('.') == 5, 'col ' .. vim.fn.col('.'))
	vim.cmd('execute "normal! \\<C-o>"')
	check('nav: jumplist entry returns with <C-o>', vim.fn.line('.') == 1, 'line ' .. vim.fn.line('.'))
	vim.o.wrapscan = false
	vim.api.nvim_win_set_cursor(0, { 4, 0 })
	vim.cmd('Gitsigns nav_hunk next')
	check('nav: no wrap with nowrapscan', vim.fn.line('.') == 4, 'line ' .. vim.fn.line('.'))
	vim.o.wrapscan = true

	vim.cmd('colorscheme default')
	local highlight = vim.api.nvim_get_hl(0, { name = 'GitSignsAdd' })
	check('colorscheme change keeps sign colors', highlight.link ~= nil or highlight.fg ~= nil, vim.inspect(highlight))

	-- Unloading a buffer while an update or git read is pending must not raise errors.
	vim.cmd('messages clear')
	repo_dir = make_repo('a\nb\n', 'a\nB\n')
	open(repo_dir .. '/file.txt')
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'A' })
	vim.cmd('silent write | bdelete')
	vim.cmd('edit ' .. repo_dir .. '/file.txt')
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'AA' })
	vim.cmd('bdelete!')
	vim.wait(800, function() return false end, 50)
	check(':w | bd and :bd! with pending work: no errors', error_messages() == '', error_messages())

	-- A reset whose line change fails must not flip 'endofline' for the next :w.
	repo_dir = make_repo('a\nb\nc', 'a\nb\nC')
	open(repo_dir .. '/file.txt')
	vim.bo.fixendofline = false
	local endofline_before = vim.bo.endofline
	vim.api.nvim_win_set_cursor(0, { 3, 0 })
	vim.cmd('Gitsigns reset_hunk')
	vim.bo.modifiable = false
	wait_idle()
	vim.bo.modifiable = true
	check('failed reset leaves endofline alone', vim.bo.endofline == endofline_before)
	-- The failure happened inside the queued action; the queue must still accept the next stage.
	at(3, 'stage_hunk')
	check('failed reset releases the queue for the next stage', not git_signs.pending() and index_bytes(repo_dir) == 'a\nb\nC', vim.inspect(index_bytes(repo_dir)))

	-- Two resets pressed back to back: the second must run after the first instead of being refused.
	repo_dir = make_repo('a\nb\nc\nd\ne\n', 'A\nb\nc\nd\nE\n')
	open(repo_dir .. '/file.txt')
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.cmd('Gitsigns reset_hunk')
	vim.api.nvim_win_set_cursor(0, { 5, 0 })
	vim.cmd('Gitsigns reset_hunk')
	wait_idle()
	check('two queued resets both apply', hunk_summary() == '', hunk_summary())

	-- Commit from outside, then focus: every visible buffer refreshes, not just the current one.
	local repo_e = make_repo('a\n', 'A\n')
	write_bytes(repo_e .. '/other.txt', 'x\n')
	shell('git -C ' .. repo_e .. ' add other.txt')
	commit(repo_e, 'other')
	write_bytes(repo_e .. '/other.txt', 'X\n')
	open(repo_e .. '/file.txt')
	local file_buffer = vim.api.nvim_get_current_buf()
	vim.cmd('split ' .. repo_e .. '/other.txt')
	wait_idle()
	local other_buffer = vim.api.nvim_get_current_buf()
	commit(repo_e, 'both')
	vim.api.nvim_exec_autocmds('FocusGained', {})
	vim.wait(3000, function()
		local file_hunks = git_signs.hunks(file_buffer) or { 1 }
		local other_hunks = git_signs.hunks(other_buffer) or { 1 }
		return #file_hunks == 0 and #other_hunks == 0
	end, 10)
	check('focus refreshes every visible buffer', #(git_signs.hunks(file_buffer) or { 1 }) == 0 and #(git_signs.hunks(other_buffer) or { 1 }) == 0)
	vim.cmd('only')
end

do
	-- Slow git must not block buffer switches or staging: both run in the background.
	local repo_dir = make_repo('a\n', 'A\n')
	write_bytes(repo_dir .. '/second.txt', 'b\n')
	open(repo_dir .. '/file.txt')
	with_slow_git(2, function()
		local started = vim.uv.hrtime()
		vim.cmd('edit ' .. repo_dir .. '/second.txt')
		vim.cmd('buffer #')
		local switch_ms = (vim.uv.hrtime() - started) / 1e6
		check('slow git does not block buffer switches', switch_ms < 500, string.format('%.0f ms', switch_ms))
		wait_idle()
		started = vim.uv.hrtime()
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd('Gitsigns stage_hunk')
		local stage_ms = (vim.uv.hrtime() - started) / 1e6
		check('slow git does not block staging', stage_ms < 500, string.format('%.0f ms', stage_ms))
		vim.wait(15000, function() return not git_signs.pending() end, 20)
	end)
	check('staging with slow git still lands', index_bytes(repo_dir) == 'A\n', vim.inspect(index_bytes(repo_dir)))

	-- Renaming the buffer while a stage waits on slow git must not stage into the other file.
	repo_dir = make_repo('a\nb\nc\n', 'a\nb\nADDED\nc\n')
	write_bytes(repo_dir .. '/other.txt', 'x\ny\nz\n')
	shell('git -C ' .. repo_dir .. ' add other.txt && git -C ' .. repo_dir .. ' -c user.email=t@t -c user.name=t commit -qm other')
	open(repo_dir .. '/file.txt')
	with_slow_git(1, function()
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		vim.cmd('Gitsigns stage_hunk')
		vim.wait(100, function() return false end, 10)
		vim.cmd('silent file ' .. repo_dir .. '/other.txt')
		vim.wait(15000, function() return not git_signs.pending() end, 20)
	end)
	check('rename during a queued stage: other file untouched', index_bytes(repo_dir, 'other.txt') == 'x\ny\nz\n', vim.inspect(index_bytes(repo_dir, 'other.txt')))
	check('rename during a queued stage: the pressed file is staged', index_bytes(repo_dir) == 'a\nb\nADDED\nc\n', vim.inspect(index_bytes(repo_dir)))
end


-- =============================================================================
-- LINE ENDINGS
-- =============================================================================
do
	-- eol=crlf with an LF working copy: git add stores LF either way, so only real edits are hunks.
	local repo_dir = make_repo('a\nb\nc\nd\n')
	set_attributes(repo_dir, '* eol=crlf\n')
	write_bytes(repo_dir .. '/file.txt', 'a\nB\nc\nD\n')
	open(repo_dir .. '/file.txt')
	check('eol=crlf, LF working copy: only edited lines are hunks', hunk_summary() == '-2,1+2,1 -4,1+4,1', hunk_summary())
	at(2, 'reset_hunk')
	check('eol=crlf, LF working copy: reset touches only its hunk and adds no CR', buffer_lines() == 'a|b|c|D', vim.inspect(buffer_lines()))
	at(4, 'stage_hunk')
	check('eol=crlf, LF working copy: staged index keeps LF', index_bytes(repo_dir) == 'a\nb\nc\nD\n', vim.inspect(index_bytes(repo_dir)))

	-- text=auto when the index already has CRLF: git add keeps the CRs, so staging must too.
	repo_dir = make_repo('a\r\nb\r\nc\r\n')
	set_attributes(repo_dir, '* text=auto\n')
	open(repo_dir .. '/file.txt')
	check('text=auto, CRLF in index: unmodified file has no hunks', hunk_summary() == '', hunk_summary())
	vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' })
	at(2, 'stage_hunk')
	check('text=auto, CRLF in index: staging keeps every CR', index_bytes(repo_dir) == 'a\r\nB\r\nc\r\n', vim.inspect(index_bytes(repo_dir)))

	-- autocrlf=input checks out LF, but git add still turns a CRLF working copy into LF.
	repo_dir = make_repo('a\nb\nc\n', 'a\r\nb\r\nc\r\n', 'file.txt', { 'core.autocrlf input' })
	open(repo_dir .. '/file.txt')
	check('autocrlf=input, CRLF working copy: no hunks', hunk_summary() == '', hunk_summary())
	vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' })
	at(2, 'stage_hunk')
	check('autocrlf=input, CRLF working copy: stages LF', index_bytes(repo_dir) == 'a\nB\nc\n', vim.inspect(index_bytes(repo_dir)))

	-- -text turns conversion off even with autocrlf, so a CRLF working copy is a real change.
	repo_dir = make_repo('a\nb\n', nil, 'file.txt', { 'core.autocrlf true' })
	set_attributes(repo_dir, '* -text\n')
	write_bytes(repo_dir .. '/file.txt', 'a\r\nb\r\n')
	open(repo_dir .. '/file.txt')
	check('-text with autocrlf: CRLF working copy is a change', hunk_summary() == '-1,2+1,2', hunk_summary())

	-- git ignores attribute values it doesn't know, like text=true and eol=CRLF; so must this.
	for _, attributes in ipairs({ '* text=true\n', '* eol=CRLF\n', '* eol\n' }) do
		repo_dir = make_repo('a\r\nb\r\nc\r\n')
		set_attributes(repo_dir, attributes)
		open(repo_dir .. '/file.txt')
		local name = vim.trim(attributes)
		check(name .. ' is ignored: unmodified CRLF file has no hunks', hunk_summary() == '', hunk_summary())
		vim.api.nvim_buf_set_lines(0, 1, 2, false, { 'B' })
		at(2, 'stage_hunk')
		check(name .. ' is ignored: staging keeps CRLF', index_bytes(repo_dir) == 'a\r\nB\r\nc\r\n', vim.inspect(index_bytes(repo_dir)))
	end

	-- A bare `autocrlf` line in the config means true.
	repo_dir = make_repo('a\nb\n')
	local config_handle = assert(io.open(repo_dir .. '/.git/config', 'ab'))
	config_handle:write('[core]\n\tautocrlf\n')
	config_handle:close()
	write_bytes(repo_dir .. '/file.txt', 'a\r\nb\r\n')
	open(repo_dir .. '/file.txt')
	check('bare autocrlf config: CRLF working copy has no hunks', hunk_summary() == '', hunk_summary())

	-- git's binary guess counts control characters: this content is binary to it, so autocrlf leaves the CR.
	repo_dir = make_repo('x\n', 'q\0013\r\n', 'file.txt', { 'core.autocrlf true' })
	open(repo_dir .. '/file.txt')
	at(1, 'stage_hunk')
	check('autocrlf, control characters: stages CRLF like git add', index_bytes(repo_dir) == 'q\0013\r\n', vim.inspect(index_bytes(repo_dir)))

	-- A staged lone CR (no CRLF) doesn't stop autocrlf from converting text content.
	repo_dir = make_repo('a\rb\nc\n')
	shell('git -C ' .. repo_dir .. ' config core.autocrlf true')
	write_bytes(repo_dir .. '/file.txt', 'ab\r\nc\r\n')
	open(repo_dir .. '/file.txt')
	at(1, 'stage_hunk')
	check('autocrlf, lone CR in index: stages LF like git add', index_bytes(repo_dir) == 'ab\nc\n', vim.inspect(index_bytes(repo_dir)))

	-- Under text, a CR before CRLF is part of the line; reset must put it back.
	repo_dir = make_repo('a\nz\r\nc\n')
	set_attributes(repo_dir, '* text\n')
	write_bytes(repo_dir .. '/file.txt', 'a\r\nZ\r\nc\r\n')
	open(repo_dir .. '/file.txt')
	check('text, CR inside a line: one hunk before reset', hunk_summary() == '-2,1+2,1', hunk_summary())
	at(2, 'reset_hunk')
	check('text, CR inside a line: reset restores it', hunk_summary() == '' and buffer_lines() == 'a|z\r|c', hunk_summary() .. ' ' .. vim.inspect(buffer_lines()))

	-- Without conversion, LF lines can't be written by a 'fileformat=dos' buffer: reset must say so.
	repo_dir = make_repo('a\nb\n', 'a\r\nB\r\n')
	open(repo_dir .. '/file.txt')
	local notifications = {}
	local original_notify = vim.notify
	vim.notify = function(message) table.insert(notifications, message) end
	at(1, 'reset_hunk')
	vim.notify = original_notify
	local warned = table.concat(notifications, ' | ')
	check("reset that can't restore line endings: warns", warned:find("can't be restored", 1, true) ~= nil, warned)

	-- Names git must quote in a patch: spaces, quotes, backslashes, tabs, and UTF-8.
	local odd_name = 'we ird "q" \\ \tcafé.txt'
	repo_dir = make_repo('a\nb\n', 'a\nB\n', odd_name)
	open(repo_dir .. '/' .. odd_name)
	at(2, 'stage_hunk')
	check('odd file name: stages through the patch', index_bytes(repo_dir, odd_name) == 'a\nB\n', vim.inspect(index_bytes(repo_dir, odd_name)))
end


-- =============================================================================
-- QUEUE AND INDEX CHANGES
-- =============================================================================
do
	-- The first reset removes lines above the second; the second must still reset the hunk it was pressed on.
	local repo_dir = make_repo('a\nb\nc\nd\ne\nf\ng\nh\n', 'a\nX\nY\nb\nc\nd\ne\nF\ng\nH\n')
	open(repo_dir .. '/file.txt')
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	vim.cmd('Gitsigns reset_hunk')
	vim.api.nvim_win_set_cursor(0, { 8, 0 })
	vim.cmd('Gitsigns reset_hunk')
	wait_idle()
	check('queued reset after lines moved: resets the hunk it was pressed on', buffer_lines() == 'a|b|c|d|e|f|g|H', vim.inspect(buffer_lines()))

	-- Wiping the buffer while a reset waits on git must not raise an error or warn.
	repo_dir = make_repo('a\n', 'A\n')
	open(repo_dir .. '/file.txt')
	local notifications = {}
	local original_notify = vim.notify
	vim.notify = function(message) table.insert(notifications, message) end
	with_slow_git(0.5, function()
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd('Gitsigns reset_hunk')
		vim.cmd('Gitsigns reset_hunk')
		vim.cmd('bwipeout!')
		vim.wait(3000, function() return false end, 50)
	end)
	vim.notify = original_notify
	check(':bwipeout with queued resets: no errors or warnings', #notifications == 0, table.concat(notifications, ' | '))

	-- Another git command changes the index between our read and our write: it must not be overwritten.
	repo_dir = make_repo('a\nb\n', 'a\nB\n')
	open(repo_dir .. '/file.txt')
	write_bytes(repo_dir .. '/elsewhere', 'elsewhere\n')
	local race = 'if [[ " $* " == *" apply "* ]]; then "$real_git" -C ' .. repo_dir .. ' update-index --cacheinfo 100644,$("$real_git" -C ' .. repo_dir .. ' hash-object -w elsewhere),file.txt; fi'
	vim.cmd('messages clear')
	with_git_wrapper(race, function() at(2, 'stage_hunk') end)
	check('index changed during staging: the other change is kept', index_bytes(repo_dir) == 'elsewhere\n', vim.inspect(index_bytes(repo_dir)))
	check('index changed during staging: reports the failure', error_messages():find('git apply failed', 1, true) ~= nil, error_messages())
	vim.cmd('messages clear')

	-- Deleting the last line when the index has no final newline and the line above repeats it:
	-- a zero-context patch would delete the line above instead.
	repo_dir = make_repo('a\nc\nc', 'a\nc\n')
	open(repo_dir .. '/file.txt')
	at(2, 'stage_hunk')
	check('delete a repeated last line: stages the right line', index_bytes(repo_dir) == 'a\nc\n', vim.inspect(index_bytes(repo_dir)))

	-- Staging from the editor of `git commit` would write into the commit's temporary index.
	repo_dir = make_repo('a\n', 'A\n')
	open(repo_dir .. '/file.txt')
	local lock_file = repo_dir .. '/.git/index.lock'
	shell('cp ' .. repo_dir .. '/.git/index ' .. lock_file)
	local lock_before = read_bytes(lock_file)
	vim.env.GIT_INDEX_FILE = lock_file
	vim.cmd('silent! Gitsigns stage_hunk')
	wait_idle()
	vim.env.GIT_INDEX_FILE = nil
	check('inside git commit: refuses to stage', read_bytes(lock_file) == lock_before and index_bytes(repo_dir) == 'a\n')
	os.remove(lock_file)

	-- Another plugin clears every namespace while a reset waits: warn instead of a traceback.
	repo_dir = make_repo('a\n', 'A\n')
	open(repo_dir .. '/file.txt')
	notifications = {}
	vim.notify = function(message) table.insert(notifications, message) end
	with_slow_git(0.3, function()
		vim.cmd('Gitsigns reset_hunk')
		for _, namespace in pairs(vim.api.nvim_get_namespaces()) do
			vim.api.nvim_buf_clear_namespace(0, namespace, 0, -1)
		end
		vim.wait(5000, function() return not git_signs.pending() end, 20)
	end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('reset mark cleared by a plugin: warns without a traceback', warned:find('lost track', 1, true) ~= nil and not warned:find('traceback', 1, true), warned)

	-- A reload from disk in a window that isn't current fires no TextChanged; its signs must still follow.
	repo_dir = make_repo('a\nb\n')
	write_bytes(repo_dir .. '/other.txt', 'x\n')
	open(repo_dir .. '/file.txt')
	local reloaded_buffer = vim.api.nvim_get_current_buf()
	vim.cmd('split ' .. repo_dir .. '/other.txt')
	wait_idle()
	-- A different size, so :checktime notices the change within the same second.
	write_bytes(repo_dir .. '/file.txt', 'a\nBB\n')
	vim.cmd('silent checktime')
	vim.wait(2000, function() return #(git_signs.hunks(reloaded_buffer) or {}) == 1 end, 10)
	check('reload in another window: signs follow', #(git_signs.hunks(reloaded_buffer) or {}) == 1)
	vim.cmd('only')

	-- A file outside any repo, then `git init` and `git add` from a shell: focus must find the new repo.
	local plain_dir = vim.fn.tempname()
	vim.fn.mkdir(plain_dir, 'p')
	write_bytes(plain_dir .. '/plain.txt', 'one\n')
	open(plain_dir .. '/plain.txt')
	shell('cd ' .. plain_dir .. ' && git init -q && git add plain.txt')
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'ONE' })
	vim.api.nvim_exec_autocmds('FocusGained', {})
	wait_idle()
	check('git init after opening: focus attaches', hunk_summary() == '-1,1+1,1', hunk_summary())

	-- Adding a .gitattributes changes the conversion; entering the buffer must notice.
	repo_dir = make_repo('a\nb\n', 'a\r\nb\r\n')
	open(repo_dir .. '/file.txt')
	check('before .gitattributes: CRLF is a change', hunk_summary() == '-1,2+1,2', hunk_summary())
	write_bytes(repo_dir .. '/.gitattributes', '* text=auto\n')
	vim.api.nvim_exec_autocmds('BufEnter', { buffer = 0 })
	wait_idle()
	check('after .gitattributes: BufEnter applies text=auto', hunk_summary() == '', hunk_summary())

	-- A paste over the line limit stops diffing; undoing it must bring the signs back.
	repo_dir = make_repo('a\n', 'A\n')
	open(repo_dir .. '/file.txt')
	local many_lines = {}
	for index = 1, 40001 do
		many_lines[index] = 'x'
	end
	vim.api.nvim_buf_set_lines(0, -1, -1, false, many_lines)
	vim.api.nvim_exec_autocmds('TextChanged', {})
	vim.wait(1000, function() return git_signs.hunks() == nil end, 10)
	check('over the line limit: hunks stop', git_signs.hunks() == nil)
	vim.api.nvim_buf_set_lines(0, 1, -1, false, {})
	vim.api.nvim_exec_autocmds('TextChanged', {})
	vim.wait(3000, function() return hunk_summary() == '-1,1+1,1' end, 10)
	check('back under the line limit: hunks return', hunk_summary() == '-1,1+1,1', hunk_summary())

	-- git add from a terminal sends no focus event; entering the buffer must notice the new index.
	repo_dir = make_repo('a\n')
	write_bytes(repo_dir .. '/new.txt', 'one\n')
	open(repo_dir .. '/new.txt')
	check('untracked before git add: no hunks', git_signs.hunks() == nil)
	shell('git -C ' .. repo_dir .. ' add new.txt')
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'ONE' })
	vim.api.nvim_exec_autocmds('BufEnter', { buffer = 0 })
	wait_idle()
	check('git add elsewhere: BufEnter picks up the new index', hunk_summary() == '-1,1+1,1', hunk_summary())

	-- Entering a buffer whose index is unchanged runs no git.
	vim.api.nvim_exec_autocmds('BufEnter', { buffer = 0 })
	check('unchanged index: BufEnter runs no git', not git_signs.pending())

	-- Right after :file, the old name's hunks must not show while the new name is read.
	repo_dir = make_repo('a\n', 'A\n')
	write_bytes(repo_dir .. '/other.txt', 'A\n')
	shell('git -C ' .. repo_dir .. ' add other.txt')
	commit(repo_dir, 'other')
	open(repo_dir .. '/file.txt')
	vim.cmd('silent file ' .. repo_dir .. '/other.txt')
	check(':file rename: old hunks clear at once', git_signs.hunks() == nil and sign_summary() == '', sign_summary())
	wait_idle()
	check(':file rename: then diffs against the new name', hunk_summary() == '', hunk_summary())
	wait_idle()
end


-- =============================================================================
-- UNTRUSTED REPOS AND LOST OUTPUT
-- =============================================================================
do
	local original_notify = vim.notify
	local notifications = {}
	local function capture_notify()
		notifications = {}
		vim.notify = function(message) table.insert(notifications, message) end
	end

	-- git reporting success with no output must never be read as an empty staged file: reset would delete everything.
	local repo_dir = make_repo('a\nb\n', 'a\nB\n')
	open(repo_dir .. '/file.txt')
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" cat-file "* ]]; then exit 0; fi', function() at(2, 'reset_hunk') end)
	vim.notify = original_notify
	local warned = table.concat(notifications, ' | ')
	check('lost git output: reset leaves the buffer alone', buffer_lines() == 'a|B', vim.inspect(buffer_lines()))
	check('lost git output: reset reports it', warned:find('could not read the staged file', 1, true) ~= nil, warned)

	-- core.fsmonitor in a cloned repo's config is a command; opening and staging must not run it.
	repo_dir = make_repo('a\n', 'A\n')
	write_bytes(repo_dir .. '/hook.sh', '#!/bin/sh\ntouch ' .. repo_dir .. '/RAN\nexit 1\n')
	vim.fn.setfperm(repo_dir .. '/hook.sh', 'rwxr-xr-x')
	shell('git -C ' .. repo_dir .. ' config core.fsmonitor ' .. repo_dir .. '/hook.sh')
	open(repo_dir .. '/file.txt')
	at(1, 'stage_hunk')
	check('core.fsmonitor: opening and staging never run it', vim.uv.fs_stat(repo_dir .. '/RAN') == nil)
	check('core.fsmonitor: staging still works', index_bytes(repo_dir) == 'A\n', vim.inspect(index_bytes(repo_dir)))

	-- git ignores a filter naming no configured driver, but git's list of drivers could have lost a line, so any
	-- named filter gets no signs.
	repo_dir = make_repo('a\n', 'A\n')
	set_attributes(repo_dir, '* filter=nothing\n')
	open(repo_dir .. '/file.txt')
	check('filter with no driver: no signs', git_signs.hunks() == nil, vim.inspect(git_signs.hunks()))

	-- core.autocrlf values are case-insensitive to git.
	repo_dir = make_repo('a\nb\n', 'a\r\nb\r\n', 'file.txt', { 'core.autocrlf Input' })
	open(repo_dir .. '/file.txt')
	check('autocrlf=Input: CRLF working copy has no hunks', hunk_summary() == '', hunk_summary())

	-- A file committed with an expanded $Id$ before ident was set: git's clean collapses it, so staging any
	-- hunk through hash-object would also rewrite line 1. Refuse instead.
	repo_dir = make_repo('$Id: old $\nb\n', '$Id: old $\nB\n')
	set_attributes(repo_dir, '* ident\n')
	open(repo_dir .. '/file.txt')
	capture_notify()
	at(2, 'stage_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check("ident that doesn't round-trip: refuses to stage", index_bytes(repo_dir) == '$Id: old $\nb\n', vim.inspect(index_bytes(repo_dir)))
	check("ident that doesn't round-trip: says why", warned:find("doesn't give back", 1, true) ~= nil, warned)

	-- Its working-tree form cut short must not be reset into the buffer.
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" --filters "* ]]; then "$real_git" "$@" | head -c 15; exit 0; fi', function() at(2, 'reset_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check("ident that doesn't round-trip, output cut short: reset refuses", buffer_lines() == '$Id: old $|B' and warned:find('cut short', 1, true) ~= nil, warned)

	-- Reset only writes the working-tree form into the buffer, so it doesn't need the round trip.
	-- Lines 1 ($Id$ expands differently) and 2 form one hunk.
	at(2, 'reset_hunk')
	check("ident that doesn't round-trip: reset still works", hunk_summary() == '' and buffer_lines():match('^%$Id: %x+ %$|b$') ~= nil, vim.inspect(buffer_lines()))

	-- Every index write runs the post-index-change hook; a cloned repo can ship one (see safe.bareRepository).
	repo_dir = make_repo('a\n', 'A\n')
	write_bytes(repo_dir .. '/.git/hooks/post-index-change', '#!/bin/sh\ntouch ' .. repo_dir .. '/RAN\n')
	vim.fn.setfperm(repo_dir .. '/.git/hooks/post-index-change', 'rwxr-xr-x')
	open(repo_dir .. '/file.txt')
	at(1, 'stage_hunk')
	check('post-index-change hook: staging never runs it', vim.uv.fs_stat(repo_dir .. '/RAN') == nil)
	check('post-index-change hook: staging still works', index_bytes(repo_dir) == 'A\n', vim.inspect(index_bytes(repo_dir)))

	-- git exiting 0 with its output cut short must not be read as a shorter staged file.
	local hundred_lines = table.concat(vim.tbl_map(function(number) return 'line ' .. number end, vim.fn.range(1, 100)), '\n') .. '\n'
	repo_dir = make_repo(hundred_lines, (hundred_lines:gsub('line 90\n', 'LINE 90\n')))
	open(repo_dir .. '/file.txt')
	local lines_before = buffer_lines()
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" cat-file "* ]]; then "$real_git" "$@" | head -c 400; exit 0; fi', function() at(90, 'reset_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('truncated git output: reset leaves the buffer alone', buffer_lines() == lines_before, vim.fn.line('$') .. ' lines')
	check('truncated git output: reset reports it', warned:find('could not read the staged file', 1, true) ~= nil, warned)

	-- Staging writes the index entry, which would clear skip-worktree and un-hide edits the user hid.
	repo_dir = make_repo('a\n', 'A\n')
	shell('git -C ' .. repo_dir .. ' update-index --skip-worktree file.txt')
	open(repo_dir .. '/file.txt')
	capture_notify()
	at(1, 'stage_hunk')
	vim.notify = original_notify
	check('skip-worktree: refuses to stage', index_bytes(repo_dir) == 'a\n' and shell('git -C ' .. repo_dir .. ' ls-files -v'):sub(1, 1) == 'S')

	-- A tracked symlink replaced by a regular file: its index entry is a link target, not the file's text.
	repo_dir = make_repo('a\n')
	vim.uv.fs_symlink('file.txt', repo_dir .. '/link.txt')
	shell('git -C ' .. repo_dir .. ' add link.txt')
	commit(repo_dir, 'link')
	os.remove(repo_dir .. '/link.txt')
	write_bytes(repo_dir .. '/link.txt', 'file.txt\nEXTRA\n')
	open(repo_dir .. '/link.txt')
	check('symlink replaced by a file: no hunks', git_signs.hunks() == nil)
	vim.cmd('silent! Gitsigns stage_hunk')
	wait_idle()
	check('symlink replaced by a file: staging leaves the link', shell('git -C ' .. repo_dir .. ' ls-files -s link.txt'):sub(1, 6) == '120000')

	-- Repeated lines can make the diff after a full restore have as many hunks as before; that is not a failure.
	repo_dir = make_repo('b\nc\n\na\nc\na\nc\n', 'b\nb\na\na\na\n')
	open(repo_dir .. '/file.txt')
	capture_notify()
	at(4, 'reset_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('reset with repeated lines: no false warning', warned == '', warned)

	-- core.autocrlf cut short ('tru') would read as unset and stage the CRLF buffer as is.
	repo_dir = make_repo('a\nb\n', 'a\r\nB\r\n', 'file.txt', { 'core.autocrlf true' })
	open(repo_dir .. '/file.txt')
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" core.autocrlf "* ]]; then "$real_git" "$@" | head -c 3; exit 0; fi', function() at(2, 'stage_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('autocrlf cut short: refuses to stage', index_bytes(repo_dir) == 'a\nb\n' and warned:find('cut short', 1, true) ~= nil, vim.inspect(index_bytes(repo_dir)) .. ' ' .. warned)

	-- An ident file with no final newline, its working-tree form cut short inside the last line, keeps its line count.
	repo_dir = make_repo('$Id$\na\nbbbbbbbbbbbbbbbbbbbb', '$Id$\nA\nbbbbbbbbbbbbbbbbbbbb')
	set_attributes(repo_dir, '* ident\n')
	open(repo_dir .. '/file.txt')
	lines_before = buffer_lines()
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" --filters "* ]]; then out="$("$real_git" "$@")"; printf %s "${out%bbbbbbbbbbbbbbb*}"; exit 0; fi', function() at(2, 'reset_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('ident output cut short in the last line: reset refuses', buffer_lines() == lines_before and warned:find('cut short', 1, true) ~= nil, vim.inspect(buffer_lines()) .. ' ' .. warned)

	-- A staged object name cut short must not go into the index.
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" hash-object -w "* ]]; then "$real_git" "$@" | head -c 20; exit 0; fi', function() at(2, 'stage_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('ident staging, object name cut short: index unchanged', index_bytes(repo_dir) == '$Id$\na\nbbbbbbbbbbbbbbbbbbbb' and warned:find('hash-object failed', 1, true) ~= nil, vim.inspect(index_bytes(repo_dir)) .. ' ' .. warned)
	-- 'fixeol' would add the final newline on write, so lines 2 and 3 are one hunk and staging adds it too.
	at(2, 'stage_hunk')
	check('ident staging through a temp file: stages the hunk', index_bytes(repo_dir) == '$Id$\nA\nbbbbbbbbbbbbbbbbbbbb\n', vim.inspect(index_bytes(repo_dir)))

	-- The staged file can hold a line that looks like git's answer for the end marker; output cut right after it
	-- must still be caught, or reset deletes the lines after it.
	local fake_end = string.rep('0', 40) .. ' missing'
	repo_dir = make_repo('a\n' .. fake_end .. '\nb\nc\n', 'a\n' .. fake_end .. '\nb\nC\n')
	set_attributes(repo_dir, '* ident\n')
	open(repo_dir .. '/file.txt')
	lines_before = buffer_lines()
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" --filters"* ]]; then out="$("$real_git" "$@")"; printf "%s\\n" "${out%%missing*}missing"; exit 0; fi', function() at(4, 'reset_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('ident output cut after a fake end line: reset refuses', buffer_lines() == lines_before and warned:find('cut short', 1, true) ~= nil, vim.inspect(buffer_lines()) .. ' ' .. warned)

	-- Bytes lost from the middle keep the end marker; with or without the round trip, reset must refuse.
	for _, first_line in ipairs({ '$Id$', '$Id: old $' }) do
		repo_dir = make_repo(first_line .. '\nl2\nl3\nl4\nl5\n', first_line .. '\nl2\nL3\nl4\nl5\n')
		set_attributes(repo_dir, '* ident\n')
		open(repo_dir .. '/file.txt')
		lines_before = buffer_lines()
		capture_notify()
		with_git_wrapper('if [[ " $* " == *" --filters"* ]]; then "$real_git" "$@" | grep -v "^l3$"; exit 0; fi', function() at(3, 'reset_hunk') end)
		vim.notify = original_notify
		warned = table.concat(notifications, ' | ')
		check('ident output missing a middle line (' .. first_line .. '): reset refuses', buffer_lines() == lines_before and warned:find('cut short', 1, true) ~= nil, vim.inspect(buffer_lines()) .. ' ' .. warned)
	end

	-- A staged character the working-tree-encoding can't hold: git passes the UTF-8 through and exits 0.
	repo_dir = make_repo('a\n', 'A\n')
	set_attributes(repo_dir, '* working-tree-encoding=SHIFT-JIS\n')
	write_bytes(repo_dir .. '/file.txt', 'a\n\240\159\152\128\n')
	shell('git -C ' .. repo_dir .. ' update-index --add --cacheinfo 100644,$(printf "a\\n\\360\\237\\230\\200\\n" | git -C ' .. repo_dir .. ' hash-object -w --stdin),file.txt')
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=sjis ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	-- Only an error keeps it from being diffed, so give a wrongly diffed buffer time to show it.
	vim.wait(1000, function() return git_signs.hunks() ~= nil end, 10)
	check('encoding failure: no hunks', git_signs.hunks() == nil, vim.bo.fileencoding .. ' ' .. vim.inspect(git_signs.hunks()))

	-- A driver setting lost from the middle of git's list must not let `cat-file --filters` run it.
	repo_dir = make_repo('a\n', 'A\n', 'file.txt', { 'filter.evil.smudge "touch RAN; cat"', 'filter.zzz.clean cat' })
	set_attributes(repo_dir, '* ident filter=evil\n')
	with_git_wrapper('if [[ " $* " == *" --get-regexp "* ]]; then "$real_git" "$@" | grep -v "^filter.evil.smudge$"; exit 0; fi', function()
		open(repo_dir .. '/file.txt')
		at(1, 'stage_hunk')
	end)
	check('filter setting lost from the middle: the driver never runs', vim.uv.fs_stat(repo_dir .. '/RAN') == nil)

	-- Bytes lost inside a line keep the line count; with no round trip, only the check against the raw blob sees it.
	repo_dir = make_repo('$Id: old $\nl2\nl3 hello world\n', '$Id: old $\nl2\nL3 hello world\n')
	set_attributes(repo_dir, '* ident\n')
	open(repo_dir .. '/file.txt')
	lines_before = buffer_lines()
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" --filters"* ]]; then "$real_git" "$@" | sed "s/hello //"; exit 0; fi', function() at(3, 'reset_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('bytes lost inside a line: reset refuses', buffer_lines() == lines_before and warned:find('cut short', 1, true) ~= nil, vim.inspect(buffer_lines()) .. ' ' .. warned)

	-- Bytes lost inside an expanded $Id$ still clean back to the staged file, so the round trip can't see it.
	repo_dir = make_repo('$Id$\na\n', '$Id$\nA\n')
	set_attributes(repo_dir, '* ident\n')
	open(repo_dir .. '/file.txt')
	lines_before = buffer_lines()
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" --filters"* ]]; then "$real_git" "$@" | sed -E "s/(Id: [0-9a-f]{10})[0-9a-f]+/\\1/"; exit 0; fi', function() at(2, 'reset_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('$Id$ cut short: reset refuses', buffer_lines() == lines_before and warned:find('cut short', 1, true) ~= nil, vim.inspect(buffer_lines()) .. ' ' .. warned)

	-- A character latin1 can't hold, with git's "failed to encode" warning lost: the text must still be refused.
	repo_dir = make_repo('a\n', 'A\n')
	set_attributes(repo_dir, '* working-tree-encoding=ISO-8859-1\n')
	write_bytes(repo_dir .. '/file.txt', 'caf\233\n')
	shell('git -C ' .. repo_dir .. ' update-index --add --cacheinfo 100644,$(printf "caf\\\\303\\\\251 \\\\342\\\\202\\\\254\\\\n" | git -C ' .. repo_dir .. ' hash-object -w --stdin),file.txt')
	with_git_wrapper('if [[ " $* " == *" --filters"* || " $* " == *" hash-object "* ]]; then "$real_git" "$@" 2>/dev/null; exit $?; fi', function()
		vim.cmd('silent! %bwipeout!')
		vim.cmd('edit ++enc=latin1 ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
		wait_idle()
		vim.wait(1000, function() return git_signs.hunks() ~= nil end, 10)
	end)
	check('encoding failure with its warning lost: no hunks', git_signs.hunks() == nil, vim.bo.fileencoding .. ' ' .. vim.inspect(git_signs.hunks()))

	-- A long line of $Id:x spans: the foreign-ident check must not search the rest of the file for each one.
	-- About 0.5 s when linear and 6.5 s when quadratic on an idle laptop; 4 s leaves room for load.
	repo_dir = make_repo(string.rep('$Id:x', 800000) .. '\n', string.rep('$Id:x', 800000) .. '\nmore\n')
	set_attributes(repo_dir, '* ident\n')
	local start_time = vim.uv.hrtime()
	open(repo_dir .. '/file.txt')
	local elapsed_ms = (vim.uv.hrtime() - start_time) / 1e6
	check('many $Id: spans: opens quickly', elapsed_ms < 4000 and git_signs.hunks() ~= nil, string.format('%d ms %s', elapsed_ms, hunk_summary()))

	-- A hunk that flips git's whole-file guess (a lone CR makes autocrlf see binary) would change every line ending.
	repo_dir = make_repo('a\nb\nc\n$Id$\n', 'a\r\nb\rx\r\nc\r\n$Id$\r\n', 'file.txt', { 'core.autocrlf true' })
	set_attributes(repo_dir, 'file.txt ident\n')
	open(repo_dir .. '/file.txt')
	capture_notify()
	at(2, 'stage_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('hunk that flips autocrlf: refuses to stage', index_bytes(repo_dir) == 'a\nb\nc\n$Id$\n' and warned:find('other lines', 1, true) ~= nil, vim.inspect(index_bytes(repo_dir)) .. ' ' .. warned)

	-- glibc knows wide encodings by many names; a newline that isn't one byte is what makes them undiffable.
	repo_dir = make_repo('a\nb\n', 'a\nB\n')
	open(repo_dir .. '/file.txt')
	vim.bo.fileencoding = 'csucs4'
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { 'A' })
	vim.cmd('doautocmd TextChanged')
	vim.wait(1500, function() return git_signs.hunks() == nil end, 10)
	check('wide encoding alias (csucs4): no signs', git_signs.hunks() == nil, vim.inspect(git_signs.hunks()))
	vim.cmd('silent! %bwipeout!')

	-- Stateful encodings (UTF-7, ISO-2022-JP) end a line's last non-ASCII run only when a newline follows; staging
	-- must store what :write writes, not drop the run's end.
	repo_dir = make_repo('a\nb\nc\n')
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=utf-7 ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	vim.api.nvim_buf_set_lines(0, 1, 2, false, { '\195\169\230\151\165' })
	vim.cmd('doautocmd TextChanged')
	vim.wait(1000, function() return git_signs.hunks() ~= nil and #git_signs.hunks() > 0 end, 10)
	at(2, 'stage_hunk')
	vim.cmd('silent write')
	check('UTF-7 buffer: stages what :write writes', index_bytes(repo_dir) == read_bytes(repo_dir .. '/file.txt'), vim.inspect(index_bytes(repo_dir)) .. ' ' .. vim.inspect(read_bytes(repo_dir .. '/file.txt')))
	vim.cmd('silent! %bwipeout!')

	-- Some encodings hold back a line's last character in case a combining mark follows (Big5-HKSCS when encoding,
	-- CP1258 when decoding); converting a bare line would drop it.
	repo_dir = make_repo('x\136\102\nb\nc\n')
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=big5-hkscs ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	check('Big5-HKSCS line ending in a held-back character: no hunks', hunk_summary() == '', hunk_summary())
	repo_dir = make_repo('first\nsecond line\n', 'first\nCHANGED\n')
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=cp1258 ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	at(2, 'reset_hunk')
	check('CP1258: reset restores the whole last character', buffer_lines() == 'first|second line', vim.inspect(buffer_lines()))
	vim.cmd('silent! %bwipeout!')

	-- vim.iconv puts '?' in place of a character the encoding can't hold; staging must refuse, not store '?'.
	repo_dir = make_repo('caf\233\nline two\n')
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=cp1252 ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	vim.api.nvim_buf_set_lines(0, 1, 2, false, { '\230\151\165\230\156\172' })
	vim.cmd('doautocmd TextChanged')
	vim.wait(1000, function() return git_signs.hunks() ~= nil and #git_signs.hunks() > 0 end, 10)
	capture_notify()
	at(2, 'stage_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check("character the encoding can't hold: refuses to stage", index_bytes(repo_dir) == 'caf\233\nline two\n' and warned:find("can't hold", 1, true) ~= nil, vim.inspect(index_bytes(repo_dir)) .. ' ' .. warned)
	vim.cmd('silent! %bwipeout!')

	-- Neovim converts to latin1 itself: 0xBF for a character it can't hold, and combining marks dropped.
	for _, typed in ipairs({ 'A\196\128B', 'e\204\129' }) do
		repo_dir = make_repo('caf\233\nline two\n')
		vim.cmd('silent! %bwipeout!')
		vim.cmd('edit ++enc=latin1 ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
		wait_idle()
		vim.api.nvim_buf_set_lines(0, 1, 2, false, { typed })
		vim.cmd('doautocmd TextChanged')
		vim.wait(1000, function() return git_signs.hunks() ~= nil and #git_signs.hunks() > 0 end, 10)
		capture_notify()
		at(2, 'stage_hunk')
		vim.notify = original_notify
		warned = table.concat(notifications, ' | ')
		check('latin1, ' .. vim.inspect(typed) .. ': refuses to stage', index_bytes(repo_dir) == 'caf\233\nline two\n' and warned:find("can't hold", 1, true) ~= nil, vim.inspect(index_bytes(repo_dir)) .. ' ' .. warned)
	end
	vim.cmd('silent! %bwipeout!')

	-- Reset must not put staged bytes the buffer's encoding can't decode into the buffer as they are.
	repo_dir = make_repo('a\nb\129\n', 'a\nB\n')
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=sjis ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	capture_notify()
	at(2, 'reset_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('undecodable staged bytes: reset refuses', buffer_lines() == 'a|B' and warned:find("isn't valid", 1, true) ~= nil, vim.inspect(buffer_lines()) .. ' ' .. warned)

	-- A NUL staged between the refresh and a reset: decoding it from UTF-7 crashes Neovim.
	repo_dir = make_repo('a\nb\n', 'a\nB\n')
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=utf-7 ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	shell('git -C ' .. repo_dir .. ' update-index --cacheinfo 100644,$(printf "a\\nb\\0\\n" | git -C ' .. repo_dir .. ' hash-object -w --stdin),file.txt')
	capture_notify()
	at(2, 'reset_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('NUL staged before a UTF-7 reset: refuses without crashing', buffer_lines() == 'a|B' and warned:find('binary', 1, true) ~= nil, vim.inspect(buffer_lines()) .. ' ' .. warned)
	vim.cmd('silent! %bwipeout!')

	-- ISO-2022-JP uses the byte '?' inside some characters (与 is ESC $ B M ?); that is not a failed conversion.
	local function iso_2022_jp(text) return vim.iconv(text, 'utf-8', 'iso-2022-jp') end
	repo_dir = make_repo(iso_2022_jp('\228\184\142\227\129\136\227\130\139\nline2\n'))
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=iso-2022-jp ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { '\228\184\142\227\129\136\227\129\170\227\129\132' })
	vim.cmd('doautocmd TextChanged')
	vim.wait(1000, function() return git_signs.hunks() ~= nil and #git_signs.hunks() > 0 end, 10)
	capture_notify()
	at(1, 'stage_hunk')
	vim.notify = original_notify
	local expected_index = iso_2022_jp('\228\184\142\227\129\136\227\129\170\227\129\132\nline2\n')
	check("ISO-2022-JP character containing '?': stages", index_bytes(repo_dir) == expected_index, vim.inspect(index_bytes(repo_dir)))
	vim.cmd('silent! %bwipeout!')

	-- git doesn't close a stateful encoding's last run without a final newline; a sign that could never clear
	-- would be wrong, so such files get no signs.
	repo_dir = make_repo('a\n\230\151\165\230\156\172')
	set_attributes(repo_dir, 'file.txt working-tree-encoding=UTF-7\n')
	write_bytes(repo_dir .. '/file.txt', vim.iconv('a\n\230\151\165\230\156\172', 'utf-8', 'utf-7'))
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=utf-7 ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	vim.wait(1000, function() return git_signs.hunks() ~= nil end, 10)
	check('UTF-7 working-tree-encoding, no final newline: no signs', git_signs.hunks() == nil, vim.inspect(git_signs.hunks()))
	vim.cmd('silent! %bwipeout!')

	-- BIG5-HKSCS holds back ê in case a combining mark follows; with no final newline git drops it from the
	-- working-tree form, and reset would delete it from the buffer.
	repo_dir = make_repo('a\nx\195\170')
	set_attributes(repo_dir, 'file.txt working-tree-encoding=BIG5-HKSCS\n')
	write_bytes(repo_dir .. '/file.txt', 'a\nx\136\167')
	vim.cmd('silent! %bwipeout!')
	vim.cmd('edit ++enc=big5-hkscs ' .. vim.fn.fnameescape(repo_dir .. '/file.txt'))
	wait_idle()
	vim.wait(1000, function() return git_signs.hunks() ~= nil end, 10)
	check('BIG5-HKSCS held-back last character, no final newline: no signs', git_signs.hunks() == nil, vim.inspect(git_signs.hunks()))
	vim.cmd('silent! %bwipeout!')

	-- Undo restores lines but not options, so a reset that changes 'endofline' or 'bomb' must say so; otherwise
	-- u and then :w would silently drop the final newline or add a BOM.
	repo_dir = make_repo('a\nb', 'a\nB\n')
	open(repo_dir .. '/file.txt')
	capture_notify()
	at(2, 'reset_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('reset that turns off endofline: sets it and says u does not undo it', vim.bo.endofline == false and warned:find("'noendofline'", 1, true) ~= nil and warned:find('u does not undo', 1, true) ~= nil, warned)
	repo_dir = make_repo('\239\187\191a\nz\n', 'A\nz\n')
	open(repo_dir .. '/file.txt')
	capture_notify()
	at(1, 'reset_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('reset that adds a BOM: sets bomb and says so', vim.bo.bomb and warned:find("'bomb'", 1, true) ~= nil, warned)
	vim.cmd('silent! %bwipeout!')

	-- An emptied BOM buffer: reset changes no option, so it must not warn that it did.
	repo_dir = make_repo('\239\187\191a\nb\n')
	open(repo_dir .. '/file.txt')
	vim.cmd('silent normal! ggdG')
	vim.cmd('doautocmd TextChanged')
	vim.wait(1000, function() return #(git_signs.hunks() or {}) > 0 end, 10)
	capture_notify()
	at(1, 'reset_hunk')
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('reset of an emptied BOM buffer: no false option warning', warned:find('u does not undo', 1, true) == nil and buffer_lines() == 'a|b', vim.inspect(buffer_lines()) .. ' ' .. warned)
	vim.cmd('silent! %bwipeout!')

	-- :write ignores 'bomb' under 'binary', so the BOM must count as gone, and reset must put it back as bytes.
	repo_dir = make_repo('\239\187\191hello\nworld\n')
	open(repo_dir .. '/file.txt')
	vim.bo.binary = true
	vim.cmd('doautocmd TextChanged')
	vim.wait(1000, function() return git_signs.hunks() ~= nil and #git_signs.hunks() > 0 end, 10)
	check("'bomb' under 'binary': line 1 is a change", hunk_summary() == '-1,1+1,1', hunk_summary())
	at(1, 'reset_hunk')
	vim.cmd('silent write')
	check("'bomb' under 'binary': reset then :w keeps the BOM", read_bytes(repo_dir .. '/file.txt') == '\239\187\191hello\nworld\n', vim.inspect(read_bytes(repo_dir .. '/file.txt')))
	vim.cmd('silent! %bwipeout!')

	-- vim.iconv crashes Neovim on a wide encoding ending in a partial character; git passes the crafted blob through.
	repo_dir = make_repo('a\n', 'hello\n')
	set_attributes(repo_dir, '* working-tree-encoding=UTF-16\n')
	shell('git -C ' .. repo_dir .. ' update-index --cacheinfo 100644,$(printf "\\\\377\\\\0\\\\0" | git -C ' .. repo_dir .. ' hash-object -w --stdin),file.txt')
	open(repo_dir .. '/file.txt')
	check('crafted UTF-16 blob: no crash and no hunks', git_signs.hunks() == nil, vim.inspect(git_signs.hunks()))

	-- check-attr shows filter=unspecified like no filter, but git still runs a driver by that name.
	repo_dir = make_repo('a\n', 'A\n', 'file.txt', { 'filter.unspecified.smudge "touch RAN; cat"', 'filter.unspecified.clean "touch RAN; cat"' })
	set_attributes(repo_dir, 'file.txt ident filter=unspecified\n')
	-- The setup commit itself runs the driver; only what git-signs runs counts.
	os.remove(repo_dir .. '/RAN')
	open(repo_dir .. '/file.txt')
	at(1, 'stage_hunk')
	check('filter named unspecified: the driver never runs', vim.uv.fs_stat(repo_dir .. '/RAN') == nil)
	check('filter named unspecified: staging still works', index_bytes(repo_dir) == 'A\n', vim.inspect(index_bytes(repo_dir)))

	-- Another tool's ident (with spaces) is left alone by git, so it is diffed like any line.
	repo_dir = make_repo('$Id: foo.c,v 1.2 joe Exp $\nb\n', '$Id: foo.c,v 1.2 joe Exp $\nB\n')
	set_attributes(repo_dir, '* ident\n')
	open(repo_dir .. '/file.txt')
	check('foreign ident: only the edited line is a hunk', hunk_summary() == '-2,1+2,1', hunk_summary())
	at(2, 'reset_hunk')
	check('foreign ident: reset works', buffer_lines() == '$Id: foo.c,v 1.2 joe Exp $|b', vim.inspect(buffer_lines()))

	-- One CR lost from mixed line endings under eol=crlf keeps the end marker and the line count.
	repo_dir = make_repo('a\r\nb\nc\n', 'a\r\nB\r\nc\r\n')
	set_attributes(repo_dir, '* ident eol=crlf\n')
	open(repo_dir .. '/file.txt')
	lines_before = buffer_lines()
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" --filters"* ]]; then "$real_git" "$@" | sed "3s/\\r$//"; exit 0; fi', function() at(2, 'reset_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('one CR lost: reset refuses', buffer_lines() == lines_before and warned:find('cut short', 1, true) ~= nil, vim.inspect(buffer_lines()) .. ' ' .. warned)

	-- git's answer for another object than the one asked for must not be used.
	repo_dir = make_repo('a\nb\n', 'a\nB\n')
	open(repo_dir .. '/file.txt')
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" cat-file --batch"* ]]; then "$real_git" "$@" | sed "1s/^./0/"; exit 0; fi', function() at(2, 'reset_hunk') end)
	vim.notify = original_notify
	warned = table.concat(notifications, ' | ')
	check('answer for another object: reset refuses', buffer_lines() == 'a|B' and warned:find('cut short', 1, true) ~= nil, warned)

	-- An object name cut short in ls-files output still resolves as a prefix; it must be refused.
	repo_dir = make_repo('a\n', 'A\n')
	with_git_wrapper('if [[ " $* " == *" ls-files "* ]]; then "$real_git" "$@" | sed -E "s/^(. [0-9]+ [0-9a-f]{39})[0-9a-f]/\\1/"; exit 0; fi', function()
		open(repo_dir .. '/file.txt')
	end)
	check('object name cut short in ls-files: no hunks', git_signs.hunks() == nil, vim.inspect(git_signs.hunks()))

	-- Filter driver settings lost at the end of git's list would make an lfs file look like plain text.
	repo_dir = make_repo('a\n', 'A\n', 'file.txt', { 'filter.other.clean cat', 'filter.lfs.clean cat', 'filter.lfs.smudge cat' })
	set_attributes(repo_dir, '* filter=lfs\n')
	capture_notify()
	with_git_wrapper('if [[ " $* " == *" --get-regexp "* ]]; then "$real_git" "$@" | head -n 1; exit 0; fi', function()
		open(repo_dir .. '/file.txt')
		at(1, 'stage_hunk')
	end)
	vim.notify = original_notify
	check('filter settings cut short: refuses to stage', index_bytes(repo_dir) == 'a\n', vim.inspect(index_bytes(repo_dir)))

	-- A tracked notes/x.md, then the directory replaced by a file `notes`: the pathspec matches notes/x.md.
	repo_dir = make_repo('x\n', 'x\n', 'x.md')
	vim.fn.mkdir(repo_dir .. '/notes', 'p')
	shell('git -C ' .. repo_dir .. ' mv x.md notes/x.md')
	commit(repo_dir, 'move')
	vim.fn.delete(repo_dir .. '/notes', 'rf')
	write_bytes(repo_dir .. '/notes', 'other\n')
	open(repo_dir .. '/notes')
	check('file replacing a tracked directory: no hunks from the files inside', git_signs.hunks() == nil, vim.inspect(git_signs.hunks()))
end


-- =============================================================================
-- MAIN
-- =============================================================================
io.stdout:write(string.format('\n%d passed, %d failed\n', num_passes, num_failures))
vim.cmd(num_failures == 0 and 'qa!' or 'cquit!')
