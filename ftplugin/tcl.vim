
" Examples:
" https://github.com/toddky/ultisnips/blob/master/tcl.snippets

" ==============================================================================
" SETTINGS
" ==============================================================================
set iskeyword+=#


" ==============================================================================
" COMMENTS
" ==============================================================================
iab #= 
\<CR># ==============================================================================
\<CR>#
\<CR># ==============================================================================<UP>

" Shebangs
iab #! #!/usr/bin/env tclsh
iab #tcl #!/usr/bin/env tclsh
iab #tclsh #!/usr/bin/env tclsh

" Modelines
iab #vim 
\<CR># vim: ft=tcl et ts=2 sw=0 sts=0
\<CR># vim: ft=tcl et ts=4 sw=0 sts
\<CR># vim: ft=tcl noet ts=4 sw=0 sts


" ==============================================================================
" ABBREVIATIONS
" ==============================================================================
"
" File/directory operations
iab #ln file link -symbolic /path/to/original/file /path/to/symlink
iab #mkdir file mkdir /path/to/dir

