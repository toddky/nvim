-- =============================================================================
-- SETUP
-- =============================================================================
-- vim: noet ts=4 sts=0 sw=0
if not pcall(require, 'CopilotChat') then
	return
end

vim.api.nvim_create_autocmd('BufEnter', {
	pattern = 'copilot-*',
	callback = function()
		-- Set buffer-local options
		vim.opt_local.relativenumber = false
		vim.opt_local.number = false
		vim.opt_local.conceallevel = 0

		--REVISIT: Figure out how to disable bad keymaps
		--pcall(vim.api.nvim_buf_del_keymap, 0, 'n', ':')
		--pcall(vim.api.nvim_buf_del_keymap, 0, 'i', '<Enter>')

	end
})


-- =============================================================================
-- FUNCTIONS
-- =============================================================================


-- =============================================================================
-- SETTINGS
-- =============================================================================


-- =============================================================================
-- MAPPINGS
-- =============================================================================
vim.api.nvim_set_keymap('n', ',cc', '<cmd>CopilotChat<CR>', { noremap = true, silent = true })

