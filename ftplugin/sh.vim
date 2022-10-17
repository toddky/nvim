
" Examples:
" https://github.com/toddky/ultisnips/blob/master/sh.snippets

" ==============================================================================
" ABBREVIATIONS
" ==============================================================================
set iskeyword+=#

" Test
iab #f [[ -f "$file" ]]
iab #d [[ -d "$dir" ]]
iab #n [[ -n "$string" ]]
iab #z [[ -z "$string" ]]

" If
iab #ifd if [[ -d "$dir" ]]; then<CR><CR>fi<UP>
iab #iff if [[ -f "$file" ]]; then<CR><CR>fi<UP>

" Commands
iab #bash #!/usr/bin/env bash
iab #while while [[ condition ]]; do<CR><CR>done<UP>
iab #read while read line; do<CR><CR>done < <(command)<UP>
"iab #2 1>&2

"function cleanup() {
	"rm "$tempfile"
"}
"trap cleanup EXIT


" Comments
iab #= # ==============================================================================


" TODO: Figure out how to use multiline abbrevs
"iab #usage
"\<CR>function print_usage()
"\<CR>cat <<EOF
"\<CR>USAGE: \$0 [options] <command>
"\<CR>
"\<CR>Write a description here.
"\<CR>
"\<CR>Options:
"\<CR>    -h, --help                   Show this message
"\<CR>
"\<CR>    -v, --verbose                Increase verbosity
"\<CR>EOF
"

"iab #temp
"tempfile="$(mktemp)"
"function cleanup() {
"	rm "$tempfile"
"}
"trap cleanup EXIT


