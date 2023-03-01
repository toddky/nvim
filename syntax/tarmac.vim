
" :help group

if exists("b:current_syntax")
	finish
endif

" Timestamps and NOPs
hi def link tarmac_ts Comment
syn match tarmac_ts /\v^\s*\d+\s+(tic ES|clk)\s+(cpu\d+\S*|gic\S+)/
syn match tarmac_ts /\v^.*d503201f.*NOP.*$/

" IT
"hi def link tarmac_instr Operator
hi def link tarmac_instr Constant
"syn match tarmac_instr /\v:\zs\s+[A-Z0-9]{3,}($|\s+.*)/
syn match tarmac_instr /\vIT\s.*:\zs\s+[A-Z0-9]{3,}($|\s+.*)/
"syn region tarmac_ts start=/\v^\s*\d/ end=/\v(tic ES|clk)/

"" Error/Fatal
hi def link tarmac_el3 DiagnosticError
"syn match tarmac_el3 /\v\s+EL3\w+\s+/

let b:current_syntax = "tarmac"

