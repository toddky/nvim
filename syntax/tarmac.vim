
" :help group

if exists("b:current_syntax")
	finish
endif

" Timestamps
hi def link tarmac_ts Comment
syn match tarmac_ts /\v^\s*\d+\s+(tic ES|clk)\s+(cpu\d+)/

" IT
hi def link tarmac_instr Operator
syn match tarmac_instr /\v:\zs\s+[A-Z0-9]{3,}\s+.*/

"" Error/Fatal
hi def link tarmac_el3 DiagnosticError
syn match tarmac_el3 /\v\s+EL3\w+\s+/

let b:current_syntax = "tarmac"

