
" Examples:
" https://github.com/toddky/ultisnips/blob/master/python.snippets

" ==============================================================================
" ABBREVIATIONS
" ==============================================================================
set iskeyword+=#

" Setup
iab #python #!/usr/bin/env python3
iab #sys import sys

" Printing
"iab #2 sys.stderr.write(f'')
iab #stderr sys.stderr.write(f'')

" Environment variables
iab #env os.environ['']
iab #path sys.path.insert(0, '/path/to/somewhere'}) # $PYTHON_PATH

" File/Directory Operations
iab #exists os.path.exists(path)
iab #dir os.path.isdir(path)
iab #f os.path.isfile(file)
iab #read f = open("file.txt", "r")<CR>for line in f:<CR>line = line.rstrip()
iab #cp shutil.copyfile(src, dest)
iab #mkdir os.mkdir(path, 0o755)
iab #mkdirp os.makedirs(path, 0o755)

" Expressions
iab #in list(dict[key][index] for key in dict)
iab #try try:<CR>#<CR>except KeyError:<UP>

" Time
iab #epoch datetime.datetime.fromtimestamp(epoch).strftime('%Y-%m-%d %a %T')

