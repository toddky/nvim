
-- Automatically quits without saving after timeout_ms of inactivity

-- 72 hours
local timeout_ms = 72 * 60 * 60 * 1000

local timer = vim.loop.new_timer()

local function reset_timer()
	timer:stop()
	timer:start(timeout_ms, 0, vim.schedule_wrap(function()
		vim.cmd('qa!')
	end))
end

reset_timer()

-- Reset timer on cursor movement
vim.api.nvim_create_autocmd({'CursorMoved', 'CursorMovedI'}, {
	callback = function()
		reset_timer()
	end,
})

