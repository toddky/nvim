
" Examples:
" https://github.com/toddky/ultisnips/blob/master/python.snippets

" ==============================================================================
" ABBREVIATIONS
" ==============================================================================
set iskeyword+=#

" Import
iab #sys import sys

" Printing
"iab #2 sys.stderr.write(f'')
iab #stderr sys.stderr.write(f'')

" Environment variables
iab #env os.environ['']
iab #path sys.path.insert(0, '/path/to/somewhere'}) # $PYTHON_PATH

