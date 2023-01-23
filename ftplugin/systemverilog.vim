
" ==============================================================================
" ABBREVIATIONS
" ==============================================================================
set iskeyword+=#

" Hacks for setting keyword
cab skey set iskeyword+=#
autocmd BufNewFile,BufRead *.sv set iskeyword+=#

" Setup
iab #vim // vim: ft=systemverilog et ts=2 sw=0 sts=0

" Header
iab #= 
\<CR>// =============================================================================
\<CR>//
\<CR>// =============================================================================<UP>

