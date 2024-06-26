-- =============================================================================
-- SETUP
-- =============================================================================
-- vim: noet ts=4 sts=0 sw=0
if not pcall(require, 'nvim-treesitter') then
	return
end

-- =============================================================================
-- CONFIG
-- =============================================================================
-- nvim-treesitter setup
-- See `:help nvim-treesitter`

-- REVISIT: Clean up,  this was copied directly from kickstart.nvim
require('nvim-treesitter.configs').setup {
	-- Treesitter languages
	ensure_installed = {
		'c',
		--'cpp',
		'go',
		'lua',
		'python',
		'rust',
		--'tsx',
		--'typescript',
		--'help',
		--'vim',
	},
	auto_install = false,
	--TODO: Figure out how to add -std=c99
	--src/scanner.c:120:3: note: use option -std=c99 or -std=gnu99 to compile your code

	highlight = { enable = true },
	indent = { enable = true, disable = { 'python' } },
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = '<c-space>',
			node_incremental = '<c-space>',
			scope_incremental = '<c-s>',
			node_decremental = '<M-space>',
		},
	},

	textobjects = {
		select = {
			enable = true,
			lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
			keymaps = {
			-- You can use the capture groups defined in textobjects.scm
			['aa'] = '@parameter.outer',
			['ia'] = '@parameter.inner',
			['af'] = '@function.outer',
			['if'] = '@function.inner',
			['ac'] = '@class.outer',
			['ic'] = '@class.inner',
			},
		},
		move = {
			enable = true,
			set_jumps = true, -- whether to set jumps in the jumplist
			goto_next_start = {
				[']m'] = '@function.outer',
				[']]'] = '@class.outer',
			},
			goto_next_end = {
				[']M'] = '@function.outer',
				[']['] = '@class.outer',
			},
			goto_previous_start = {
				['[m'] = '@function.outer',
				['[['] = '@class.outer',
			},
			goto_previous_end = {
				['[M'] = '@function.outer',
				['[]'] = '@class.outer',
			},
		},
		swap = {
			enable = true,
			swap_next = {
				['<leader>a'] = '@parameter.inner',
			},
			swap_previous = {
				['<leader>A'] = '@parameter.inner',
			},
		},
	},
}

