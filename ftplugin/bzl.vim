
" ==============================================================================
" ABBREVIATIONS
" ==============================================================================
set iskeyword+=#

" Setup
iab #vim # vim: ft=bzl et ts=4 sw=0 sts=0
iab #public package(default_visibility = ["//visibility:public"])
iab #export exports_files(glob(["*"]))

" Header
iab #= 
\<CR># ==============================================================================
\<CR>#
\<CR># ==============================================================================<UP>

" C
iab #cclib 
\<CR>cc_library(
\<CR>	name = "name",
\<CR>    srcs = glob(["*.cc"]),
\<CR>    hdrs = glob(["*.h"]),
\<CR>)

