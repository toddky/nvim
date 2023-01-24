
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
iab #include #include <><LEFT>
iab #inc     #include <><LEFT>
iab #stdint  #include <stdint.h>
iab #int     #include <stdint.h>
iab #stdio   #include <stdio.h>
iab #io      #include <stdio.h>
iab #stdlib  #include <stdlib.h>
iab #lib     #include <stdlib.h>

" Expressions
iab #p printf("\n");<LEFT><LEFT><LEFT><LEFT><LEFT>

" extern "C"
iab #c 
\#ifdef __cplusplus
\<CR>extern "C" {
\<CR>#endif
\<CR>#ifdef __cplusplus
\<CR>} // extern "C"
\<CR>#endif

" main
iab #main 
\int main(int argc, char *argv[]) {
\<CR>
\<CR>}<UP>

" printf wrapper
iab #_printf 
\void _printf(const char *fmt, ...) {
\<CR>va_list args;
\<CR>va_start(args, fmt);
\<CR>printf("[_PRINTF] ");
\<CR>vprintf(fmt, args);
\<CR>va_end(args);
\<CR>}

" Modelines
iab #vim 
\<CR>// vim: ft=c et ts=2 sw=0 sts=0
\<CR>// vim: ft=c noet ts=4 sw=0 sts

