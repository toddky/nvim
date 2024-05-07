
-- =============================================================================
-- EXAMPLES
-- =============================================================================
-- https://github.com/b0o/nvim-conf/blob/main/lua/user/mappings.lua


-- =============================================================================
-- REQUIRE
-- =============================================================================
local util = require('util')


-- =============================================================================
-- NORMAL MODE
-- =============================================================================

-- Command
util.nvmap('<Enter>', ':')

-- Indentation
util.nmap('<Tab>', '>>')
util.nmap('<S-Tab>', '<<')

-- Black hole registers
util.nmap('c', '"_c')
util.nmap('C', '"_C')

-- Redo
util.nmap('U', '<C-r>')

-- Disable Ex mode
util.nmap('Q', '<Nop>')

-- Disable Ctrl-c warning
util.nmap('<C-c>', '<Nop>')


-- =============================================================================
-- MOVEMENT
-- =============================================================================

-- Remap for dealing with word wrap
util.nvmap('j', "v:count == 0 ? 'gj' : 'j'", {expr=true})
util.nvmap('k', "v:count == 0 ? 'gk' : 'k'", {expr=true})

-- Beginning/end of line
--util.nvmap('gh', '^')
--util.nvmap('gl', '$')
util.nvmap('H', '^')
util.nvmap('L', '$')

-- Center after search
util.nvmap('N', 'Nzzzv')
util.nvmap('n', 'nzzzv')

-- Mark with `M` and jump with `m`
util.nvmap('M', 'm')
util.nvmap('m', "'")

-- TODO: Center after movement
--util.nvmap('{', '{zz')
--util.nvmap('}', '}zz')
--util.nvmap('<C-o>', '<C-o>zz')
--util.nvmap('<C-i>', '<C-i>zz')

-- Repeat latest f, t, F or T in opposite direction
-- Opposite direction of ;
util.nvmap(':', ',')


-- =============================================================================
-- TABS
-- =============================================================================
util.nmap('>', '<cmd>tabnext<Enter>')
util.nmap('<', '<cmd>tabprev<Enter>')
util.leader('tn', '<cmd>tabnew %<Enter>')
util.leader('td', '<cmd>tabclose<Enter>')


-- =============================================================================
-- WINDOWS
-- =============================================================================
util.leader('h', '<C-w>h')
util.leader('j', '<C-w>j')
util.leader('k', '<C-w>k')
util.leader('l', '<C-w>l')

util.leader('w', '<C-w>', {noremap = false})
util.nmap('<C-w>e', '<C-w>=')


-- =============================================================================
-- BUFFERS
-- =============================================================================
util.leader('fj', '<cmd>bnext<Enter>')
util.leader('fk', '<cmd>bprevious<Enter>')
util.leader('fw', '<cmd>w<Enter>')
util.leader('fx', '<cmd>x<Enter>')
util.leader('fq', '<cmd>q!<Enter>')
util.nmap('<C-j>', '<cmd>bnext<Enter>')
util.nmap('<C-k>', '<cmd>bprev<Enter>')


-- =============================================================================
-- EDITING
-- =============================================================================
-- TODO: Make this work
--util.leader('-', ':s/ -/ \\\r  -/g<Enter>')


-- =============================================================================
-- INSERT MODE
-- =============================================================================
util.imap('jj', '<esc>')


-- =============================================================================
-- VISUAL MODE
-- =============================================================================
-- Paste without overwriting buffer
util.vmap('p', '"_dP')

-- Visual block mode
util.vmap('v', '<C-v>')

-- Quit
util.vmap('q', '<Esc>')

-- Search for visually selected text
-- https://vim.fandom.com/wiki/Search_for_visually_selected_text
--util.vmap('*', 'y/<C-R>"<Enter>')

-- TODO: Figure out how this works
-- Use dot over visual selection
--util.xmap('.', '<cmd>norm.<Enter>')

-- TODO: Figure out how this works
-- Use macro over visual selection
--util.xmap('@', [[<cmd>'<,'>:normal @@<Enter>]])

-- Indentation
--util.vmap('<Tab>', '>gv')
-- UltiSnips remaps this, so I have to use this autocmd
vim.api.nvim_command([[autocmd VimEnter * vnoremap <Tab> >gv]])
util.vmap('<S-Tab>', '<gv')


-- =============================================================================
-- PLUGINS
-- =============================================================================
util.nmap(',ce',  '<cmd>ContextEnableWindow<Enter>')
util.nmap(',cp',  '<cmd>Copilot enable<Enter>')
util.nmap(',cs',  '<cmd>Copilot panel<Enter>')
util.nmap(',cq',  '<cmd>ContextDisable<Enter>')
util.nmap(',gd',  '<cmd>Gitsigns reset_hunk<Enter>')
util.nmap(',gh',  '<cmd>Gitsigns stage_hunk<Enter>')
util.nmap(',te',  '<cmd>NvimTreeToggle<Enter>')
util.nmap(',tsh', '<cmd>TSHighlightCapturesUnderCursor<Enter>')
util.nmap(',tsp', '<cmd>TSPlaygroundToggle<Enter>')
util.nmap(',ps',  '<cmd>Lazy sync<Enter>')
util.nmap(',pu',  '<cmd>Lazy update<Enter>')

------------------------------------------------------------
-- TELESCOPE
------------------------------------------------------------
-- :help telescope.builtin
if pcall(require, 'telescope') then
	local telescope = require('telescope.builtin')
	util.nmap('//a', telescope.live_grep,   {desc='Telescope Grep [A]ll'})
	util.nmap('//b', telescope.buffers,     {desc='Telescope [B]uffers'})
	util.nmap('//c', telescope.colorscheme, {desc='Telescope [C]olorscheme'})
	util.nmap('//d', telescope.diagnostics, {desc='Telescope [D]iagnostics'})
	util.nmap('//f', telescope.find_files,  {desc='Telescope [F]iles'})
	util.nmap('//g', telescope.git_files,   {desc='Telescope [G]it Files'})
	util.nmap('//h', telescope.help_tags,   {desc='Telescope [H]elp'})
	util.nmap('//k', telescope.keymaps,     {desc='Telescope [K]eymaps'})
	util.nmap('//w', telescope.grep_string, {desc='Telescope Current [W]ord'})

	util.nmap('//l', require('setup.telescope').log_files, {desc='Telescope [L]og'})

	util.nmap('///',
		function()
			-- You can pass additional configuration to telescope to change theme, layout, etc.
			telescope.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
				winblend = 10,
				previewer = false,
			})
		end,
		{desc='[/] Fuzzily search in current buffer'}
	)

	util.vmap('//',
		function()
			local text = util.get_selection()
			telescope.live_grep({default_text=text})
		end,
		{noremap = true, silent=true}
	)
end -- pcall(require, 'telescope') then

-- Bazel
-- Open TOP/some/path/BUILD from //some/path:target
util.nmap('gb',
	function()
		-- Get filename under cursor
		local orig_isfname = vim.o.isfname
		vim.o.isfname = vim.o.isfname .. ',:'
		local filename = vim.fn.expand('<cfile>')
		vim.o.isfname = orig_isfname

		-- Get WORKSPACE
		-- TODO: Get WORKSPACE instead of .git
		if string.sub(filename, 1, 2) == "//" then
			local git_path = vim.fn.finddir(".git", ".;")
			local git_top = vim.fn.fnamemodify(git_path, ":h")
			filename = git_top .. string.sub(filename, 2, -1)
		end

		if string.sub(filename, -4, -1) == ".bzl" then
			-- Get .bzl file
			filename = string.gsub(filename, ":", "/")
		else
			-- Get BUILD file
			filename = string.gsub(filename, ":[^:]+$", "/BUILD")
		end

		vim.cmd('e ' .. filename)
	end,
	{noremap = true, silent=true , desc = 'Go [B]azel'}
)


-- =============================================================================
-- OPTIONS
-- =============================================================================
util.leader('sfd', '<cmd>set foldmethod=diff<Enter>')
util.leader('sfi', '<cmd>set foldmethod=indent<Enter>')
util.leader('sfm', '<cmd>set foldmethod=manual<Enter>')
util.leader('st2', '<cmd>set tabstop=2<Enter>')
util.leader('st4', '<cmd>set tabstop=4<Enter>')
util.leader('ste', '<cmd>set expandtab<Enter>')
util.leader('stn', '<cmd>set noexpandtab<Enter>')


-- =============================================================================
-- TERMINAL MODE
-- =============================================================================
util.tmap('<Esc>', '<C-\\><C-n>')


-- =============================================================================
-- COMMAND MODE
-- =============================================================================
-- :w!! to save with sudo
-- https://www.reddit.com/r/commandline/comments/vqzg5c/comment/iesmv4r/
util.cmap('w!!', 'w !sudo tee > /dev/null %')

