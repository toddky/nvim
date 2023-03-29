
" :help group

if exists("b:current_syntax")
	finish
endif

" Error/Fatal
hi def link simlog_error DiagnosticError
syn match simlog_error /\v<F(ATAL|atal)(:)?>(:|-\[.*\])?/
syn match simlog_error /\v<E(RROR|rror)>(:|-\[.*\])?/
syn match simlog_error /\vFAIL:/
syn match simlog_error /\v^\w+: \*[FE],\w+/
syn match simlog_error /\vUVM_FATAL.*\ze\@/
syn match simlog_error /\vUVM_ERROR.*\ze\@/
syn match simlog_error /\vStack ?[Tt]race:/
syn match simlog_error /\vAssertion output stop:/
syn match simlog_error /\v\w*MISMATCH\w*/

" Warning
hi def link simlog_warning DiagnosticWarn
syn match simlog_warning /\vWARN(ING)?\ze:/
syn match simlog_warning /\v\c^\w+: \*W,\w+/

" Info
hi def link simlog_info DiagnosticInfo
syn match simlog_info /\v<I(NFO|nfo)>(:|-\[.*\])?/
syn match simlog_info /\vUVM_INFO.*\ze\@/ conceal cchar=I

" Keywords
hi def link simlog_constant Constant
syn match simlog_constant /\vinstr_id:\zs0x[0-9a-f]+/

" String
hi def link simlog_string String
syn match simlog_string /\v\[[a-zA-z]+\]/

" Comments
hi def link simlog_comment Comment
syn match simlog_comment /\v.*opcode: *(0x)?d503201f.*$/
syn match simlog_comment /\vuvm_test_top\S*\s+/ conceal


set conceallevel=2

let b:current_syntax = "log"

