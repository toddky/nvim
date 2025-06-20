
" Examples:
" https://github.com/toddky/ultisnips/blob/master/python.snippets

" ==============================================================================
" ABBREVIATIONS
" ==============================================================================
set iskeyword+=#

" Setup
iab #python #!/usr/bin/env python3
iab #pylint # pylint: disable=consider-using-with
iab #vim 
\<CR># vim: ft=python et ts=2 sw=0 sts=0
\<CR># vim: ft=python noet ts=4 sw=0 sts

" Import
iab #sys import sys
iab #os import os

" Functions
iab #def def func(arg1, arg2, *args, **kwargs):
iab #exit sys.exit(0)

" Options
iab #argv sys.argv
iab #main if __name__ == '__main__':

" Printing
"iab #2 sys.stderr.write(f'')
iab #stderr sys.stderr.write(f'')
iab #todd print(f'TODD {variable=}'); exit(0)

" Environment variables
iab #env 
\os.environ['']
\<CR>for key, value in sorted(os.environ.items()):
\<CR>print(f'{key}={value}')

iab #path sys.path.insert(0, '/path/to/somewhere'}) # $PYTHON_PATH

" File/directory operations
iab #basename os.path.basename(path)
iab #cd os.chdir(path)
iab #exists os.path.exists(path)
iab #dir os.path.isdir(path)
iab #dirname os.path.dirname(path)
iab #f os.path.isfile(file)
iab #glob glob.glob(f'{path}/*.txt')
iab #cp shutil.copyfile(src, dest)
"iab #mkdir os.mkdir(path, 0o755)
"iab #mkdir os.makedirs(path, 0o755, exist_ok=True)
iab #mkdir Path(path).mkdir(parents=True, exist_ok=True, mode=0o755)
"iab #mkdirp os.makedirs(path, 0o755)
iab #mv os.rename(old_file, new_file)
iab #pwd os.getcwd()
iab #read 
\f = open('file.txt', 'r')
\<CR>for line in f:
\<CR>line = line.rstrip()
\<CR>with open('file.txt', 'r') as f:
\<CR>lines = f.readlines()
iab #realpath os.path.realpath(path)

" Run
iab #run 
\cmd = ['ls', '-l']
\<CR>result = subprocess.run(cmd, capture_output=True)
\<CR>stdout = result.stdout.decode('utf-8')
\<CR>stdout = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout

" Debug
iab #bp breakpoint()

" Expressions
iab #ifr 
\match = re.match('regex', string)
\<CR>if match:
iab #in list(dict[key][index] for key in dict)
iab #try 
\try:
\<CR>#
\<CR>except KeyError:
\<CR>#
\<CR>except Exception as e:
\<CR>print(getattr(e, 'message', repr(e)))
\<CR>print(getattr(e, 'message', str(e)))

iab #for for key, value in dict.items():
iab #match 
\result = re.search(r"(\b[A-Z]+\b).+(\b\d+)", target_string)
\<CR>print(result.groups())
\<CR>print(result.group(1))

" Dictionaries/lists
iab #sort listname.sort(key=lambda x: x[1])

" Strings
iab #ljust stringname.ljust(width, '0')
iab #rjust stringname.rjust(width, '0')

" Time
iab #epoch datetime.datetime.fromtimestamp(epoch).strftime('%Y-%m-%d %a %T')

