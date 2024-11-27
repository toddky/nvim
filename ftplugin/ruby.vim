
" vim: ft=vim

" ==============================================================================
" ABBREVIATIONS
" ==============================================================================
set iskeyword+=#

" Setup
iab #ruby #!/usr/bin/env ruby
iab #vim 
\<CR># vim: ft=ruby et ts=2 sw=0 sts=0
\<CR># vim: ft=ruby noet ts=4 sw=0 sts

" Cool stuff
iab #fib fib = Hash.new{\|h,k\| h[k] = k < 2 ? k : h[k-1] + h[k-2]}

iab #now Time.now.strftime("%Y%m%d-%H%M%S")

