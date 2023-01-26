
" :help group

if exists("b:current_syntax")
	finish
endif

" Error/Fatal
hi def link simlog_error Error
syn match simlog_error /\v<F(ATAL|atal)(:)?>(:|-\[.*\])?/
syn match simlog_error /\v<E(RROR|rror)>(:|-\[.*\])?/
syn match simlog_error /\v^\w+: \*[FE],\w+/

" Warning
hi def link simlog_warning Todo
syn match simlog_warning /\v\c^\w+: \*W,\w+/

" Info
hi def link simlog_info Statement
syn match simlog_info /\v<I(NFO|nfo)>(:|-\[.*\])?/

