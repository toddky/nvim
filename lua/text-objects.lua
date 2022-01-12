
-- =============================================================================
-- REQUIRE
-- =============================================================================
local util = require('util')


-- =============================================================================
-- LINE
-- =============================================================================

-- <c-u> clears command line
-- normal! executes command
-- g_ goes to last non-whitespace character
-- ^ goes to first non-whitespace character
util.xomap('il', ':<c-u>normal! g_v^<Enter>')
util.xomap('al', ':<c-u>normal! $v0<Enter>')


-- =============================================================================
-- NUMBER
-- =============================================================================
-- https://github.com/toddyamakawa/vim/blob/master/my-plugins/plugin/text-objects/number.vim


return colors

