
" ==============================================================================
" EXAMPLES
" ==============================================================================
" https://github.com/toddky/ultisnips/blob/master/c.snippets


" ==============================================================================
" SETTINGS
" ==============================================================================
set iskeyword+=#


" ==============================================================================
" ABBREVIATIONS
" ==============================================================================

" Include
iab include #include <><LEFT>
iab #stdint #include <stdint.h>
iab #stdio  #include <stdio.h>
iab #stdlib #include <stdlib.h>


iab #c 
\#ifdef __cplusplus
\<CR>extern "C" {
\<CR>#endif
\<CR>#ifdef __cplusplus
\<CR>} // extern "C"
\<CR>#endif


" Modelines
iab #vim 
\<CR>// vim: ft=c et ts=2 sw=0 sts=0
\<CR>// vim: ft=c noet ts=4 sw=0 sts


