
" :help group

if exists("b:current_syntax")
	finish
endif

" Error
hi def link simlog_error Error
syn match simlog_error /\v\c\bFATAL\b/
syn match simlog_error /\v\c\bERROR\b/
syn match simlog_error /\v\c^\w+: \*[FE],\w+/

" Warning
hi def link simlog_warning Todo
syn match simlog_warning /\v\c^\w+: \*W,\w+/

