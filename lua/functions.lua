
-- =============================================================================
-- REQUIRE
-- =============================================================================


-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Usage: Open a left and right split then run :Diff
vim.api.nvim_create_user_command('Diff', function()
	vim.cmd('windo diffthis')
end, {})

-- :Popup git status | less
vim.api.nvim_create_user_command('Popup', function(opts)
	vim.fn.system({"tmux", "display-popup", "-E", opts.args})
end, { nargs = 1 })

