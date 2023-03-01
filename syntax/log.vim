
" :help group

if exists("b:current_syntax")
	finish
endif

" Error/Fatal
hi def link simlog_error DiagnosticError
syn match simlog_error /\v<F(ATAL|atal)(:)?>(:|-\[.*\])?/
syn match simlog_error /\v<E(RROR|rror)>(:|-\[.*\])?/
syn match simlog_error /\v^\w+: \*[FE],\w+/
syn match simlog_error /\vUVM_FATAL.*\ze\@/
syn match simlog_error /\vUVM_ERROR.*\ze\@/
syn match simlog_error /\vStack ?[Tt]race:/
syn match simlog_error /\vAssertion output stop:/

" Warning
hi def link simlog_warning DiagnosticWarn
syn match simlog_warning /\vWARN(ING)?\ze:/
syn match simlog_warning /\v\c^\w+: \*W,\w+/

" Info
hi def link simlog_info DiagnosticInfo
syn match simlog_info /\v<I(NFO|nfo)>(:|-\[.*\])?/
syn match simlog_info /\vUVM_INFO.*\ze\@/

" Keywords
hi def link simlog_constant Constant
syn match simlog_constant /\vinstr_id:\zs0x[0-9a-f]+/

let b:current_syntax = "log"

