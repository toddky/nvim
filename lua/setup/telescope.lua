-- =============================================================================
-- SETUP
-- =============================================================================
-- vim: noet ts=4 sts=0 sw=0
if not pcall(require, 'telescope') then
	return
end

local pickers    = require("telescope.pickers")
local finders    = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf       = require("telescope.config").values

-- Disable wrap in Telescope preview
vim.cmd([[autocmd User TelescopePreviewerLoaded setlocal nowrap]])


-- =============================================================================
-- FUNCTIONS
-- =============================================================================
-- Search for log files
local log_files = function(opts)
	opts = opts or {}
	opts.layout_strategy = opts.layout_strategy or 'vertical'
	opts.layout_config = opts.layout_config or { anchor = 'CENTER', height = 0.8, width = 0.8}
	pickers.new(opts, {
		prompt_title = 'logs',
		finder = finders.new_oneshot_job({'find', '.', '-type', 'f', '-name', '*.log'}, opts),
		sorter = conf.generic_sorter(opts),
		previewer = previewers.cat.new(opts),
	}):find()
end


-- =============================================================================
-- SETTINGS
-- =============================================================================

-- See `:help telescope` and `:help telescope.setup()`
require('telescope').setup {
	defaults = {

		file_ignore_patterns = {
			'bazel_output_base/',
			'bazel_output_user_root/',
			'%.db',
			'%.fsdb',
			'%.xcui',
		},

		extensions = {
			fzf = {
				-- REVISIT: Figure out why this doesn't work
				fuzzy = false,
				case_mode = "smart_case",
			}
		},

		mappings = {
			i = {
				['<C-u>'] = false,
				['<C-d>'] = false,
			},
		},
	},
}

-- Enable telescope fzf native, if installed
pcall(require('telescope').load_extension, 'fzf')

local M = {}
M.log_files = log_files
return M


-- =============================================================================
-- EXAMPLES
-- =============================================================================

-- vimgrep_arguments = {
-- 	'rg',
-- 	'--color=never',
-- 	'--no-heading',
-- 	'--with-filename',
-- 	'--line-number',
-- 	'--column',
-- 	'--smart-case'
-- },

-- prompt_position = "bottom",
-- prompt_prefix = "> ",
-- selection_caret = "> ",
-- entry_prefix = "  ",
-- initial_mode = "insert",
-- selection_strategy = "reset",
-- sorting_strategy = "descending",

-- layout_strategy = "horizontal",
-- layout_defaults = {
-- 	horizontal = {
-- 		mirror = false,
-- 	},
-- 	vertical = {
-- 		mirror = false,
-- 	},
-- },

-- file_sorter =  require'telescope.sorters'.get_fuzzy_file,
-- generic_sorter =  require'telescope.sorters'.get_generic_fuzzy_sorter,
-- shorten_path = true,
-- winblend = 0,
-- width = 0.75,
-- preview_cutoff = 120,
-- results_height = 1,
-- results_width = 0.8,
-- border = {},
-- borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
-- color_devicons = true,
-- use_less = true,
-- set_env = { ['COLORTERM'] = 'truecolor' }, -- default = nil,
-- file_previewer = require'telescope.previewers'.vim_buffer_cat.new,
-- grep_previewer = require'telescope.previewers'.vim_buffer_vimgrep.new,
-- qflist_previewer = require'telescope.previewers'.vim_buffer_qflist.new,

