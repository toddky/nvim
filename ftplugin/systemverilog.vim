
" ==============================================================================
" SETTINGS
" ==============================================================================
set iskeyword+=#

" Hacks for setting keyword
cab skey set iskeyword+=#
autocmd BufNewFile,BufRead *.sv set iskeyword+=#


" ==============================================================================
" COMMENTS
" ==============================================================================
" Setup
iab #vim // vim: ft=systemverilog et ts=2 sw=0 sts=0

" Header
iab #= 
\<CR>// =============================================================================
\<CR>//
\<CR>// =============================================================================<UP>

" ==============================================================================
" UVM
" ==============================================================================
"
" # Logging
iab #fatal `uvm_fatal(get_type_name(), $sformatf("", ));
iab #full `uvm_info(get_type_name(), $sformatf("", ), UVM_FULL);

