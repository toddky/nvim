
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

iab #run 
\<CR>require 'open3'
\<CR>stdout, stderr, status = Open3.capture3(*cmd)
\<CR>exitstatus = status.exitstatus


" ==============================================================================
" ADVENT OF CODE
" ==============================================================================
" 4 directions
iab #D4 
\<CR>Dir.D4(r,c).each do \|nr,nc\|
\<CR>end<UP>

" Priority queue
iab #pq 
\<CR>pq = Heap.new { \|a,b\| a[0] > b[0] } # less than
\<CR>pq.push([v,r,c])
\<CR>until pq.empty?
\<CR>	v,r,c = pq.pop
\<CR>end


