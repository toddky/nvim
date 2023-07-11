
" ==============================================================================
" EXAMPLES
" ==============================================================================
" https://github.com/toddky/ultisnips/blob/master/sh.snippets
" https://sharats.me/posts/shell-script-best-practices/
" Inserting abbreviation from file:
"   https://vi.stackexchange.com/questions/31601/inserting-abbreviation-from-file


" ==============================================================================
" SETTINGS
" ==============================================================================
set iskeyword+=#


" ==============================================================================
" CONTROL
" ==============================================================================

" Conditions
iab #f [[ -f "$file" ]]
iab #d [[ -d "$dir" ]]
iab #n [[ -n "$string" ]]
iab #z [[ -z "$string" ]]

" If
iab #ifd if [[ -d "$dir" ]]; then<CR><CR>fi<UP>
iab #iff if [[ -f "$file" ]]; then<CR><CR>fi<UP>

" Init
iab #set set -euo pipefail
iab #debug ((TRACE)) && set -o xtrace
iab #curr CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
iab #now now="$(date +'%Y%m%d-%H%M%S')"

" Commands
iab #while while [[ condition ]]; do<CR><CR>done<UP>
iab #read while read line; do<CR><CR>done < <(command)<UP>
"iab #2 1>&2

" On Exit
iab #at_exit 
\<CR>function cleanup() {
\<CR>rm "$tempfile"
\<CR>}
\<CR>trap cleanup EXIT

" Temp
iab #temp 
\<CR>tempdir="$(mktemp -d)"
\<CR>function cleanup() {
\<CR>rm -rf "$tempdir"
\<CR>}
\<CR>trap cleanup EXIT

" Case
iab #case 
\<CR>case "$var" in
\<CR>-h\|--help) echo "USAGE";;
\<CR>*)
\<CR>exit 1
\<CR>;;
\<CR>esac


" ==============================================================================
" DOCUMENTATION
" ==============================================================================

" Header
iab #= 
\<CR># ==============================================================================
\<CR>#
\<CR># ==============================================================================<UP>

" Comments
iab #! #!/usr/bin/env bash
iab #bash #!/usr/bin/env bash
iab #des # USAGE: <CR># DESCRIPTION:
iab #vim 
\<CR># vim: ft=sh et ts=2 sw=0 sts=0
\<CR># vim: ft=sh et ts=4 sw=0 sts=0
\<CR># vim: ft=sh noet ts=4 sw=0 sts

" TODO: Fix weird indentation
" Usage
iab #usage 
\<CR>function print_usage() {
\<CR>cat <<EOF
\<CR>USAGE: \$0 [options] <command>
\<CR>
\<CR>Write a description here.
\<CR>
\<CR>Options:
\<CR>    -h, --help                   Show this message
\<CR>
\<CR>    -v, --verbose                Increase verbosity
\<CR>EOF
\<CR>}
\<CR>


