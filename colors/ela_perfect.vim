" ==============================================================================
" ela-perfect
" ==============================================================================

set background=dark
hi clear

if exists('syntax_on')
    syntax reset
endif

let g:colors_name='ela_perfect'

" cterm values are the nearest xterm-256 color to each hex.
" bg            = "#1A1A1A"  234
" surface       = "#242424"  235
" panel         = "#2E2E2E"  236
" hover         = "#393939"  237
" border_subtle = "#444444"  238  also listchars and indent guides
" line_nr       = "#6A6A6A"  242  not in the theme; picked for 3.2:1 contrast on bg
" text          = "#E8E8E8"  254
" text_dim      = "#A7A7A7"  248
" cyan          = "#66C6E3"  80   primary, H1, link, function
" purple        = "#A783F8"  141  accent, H2, keyword
" green         = "#90D64F"  113  success, H3, string
" orange        = "#E3A15A"  179  warning, inline code, number
" red           = "#F4005F"  197  error
" blue          = "#5496DD"  68   secondary, builtin

hi Normal           guisp=NONE      guifg=#E8E8E8   guibg=#1A1A1A   ctermfg=254     ctermbg=234  gui=NONE           cterm=NONE
hi Visual           guisp=NONE      guifg=NONE      guibg=#393939   ctermfg=NONE    ctermbg=237  gui=bold           cterm=bold

hi Conceal          guisp=NONE      guifg=#A7A7A7   guibg=NONE      ctermfg=248     ctermbg=NONE gui=NONE           cterm=NONE
hi ColorColumn      guisp=NONE      guifg=NONE      guibg=#242424   ctermfg=NONE    ctermbg=235  gui=NONE           cterm=NONE
hi Cursor           guisp=NONE      guifg=#1A1A1A   guibg=#E8E8E8   ctermfg=234     ctermbg=254  gui=NONE           cterm=NONE
hi lCursor          guisp=NONE      guifg=#1A1A1A   guibg=#E8E8E8   ctermfg=234     ctermbg=254  gui=NONE           cterm=NONE
hi CursorIM         guisp=NONE      guifg=#1A1A1A   guibg=#E8E8E8   ctermfg=234     ctermbg=254  gui=NONE           cterm=NONE
hi CursorColumn     guisp=NONE      guifg=NONE      guibg=#242424   ctermfg=NONE    ctermbg=235  gui=NONE           cterm=NONE
hi CursorLine       guisp=NONE      guifg=NONE      guibg=#242424   ctermfg=NONE    ctermbg=235  gui=NONE           cterm=NONE
hi Directory        guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=NONE           cterm=NONE
hi DiffAdd          guisp=NONE      guifg=#1A1A1A   guibg=#90D64F   ctermfg=234     ctermbg=113  gui=NONE           cterm=NONE
hi DiffChange       guisp=NONE      guifg=#1A1A1A   guibg=#E3A15A   ctermfg=234     ctermbg=179  gui=NONE           cterm=NONE
hi DiffDelete       guisp=NONE      guifg=#E8E8E8   guibg=#F4005F   ctermfg=254     ctermbg=197  gui=NONE           cterm=NONE
hi DiffText         guisp=NONE      guifg=#1A1A1A   guibg=#66C6E3   ctermfg=234     ctermbg=80   gui=NONE           cterm=NONE
hi EndOfBuffer      guisp=NONE      guifg=NONE      guibg=NONE      ctermfg=NONE    ctermbg=NONE gui=NONE           cterm=NONE
hi ErrorMsg         guisp=NONE      guifg=#F4005F   guibg=NONE      ctermfg=197     ctermbg=NONE gui=bold           cterm=bold
hi VertSplit        guisp=NONE      guifg=#444444   guibg=NONE      ctermfg=238     ctermbg=NONE gui=NONE           cterm=NONE
hi Folded           guisp=NONE      guifg=#66C6E3   guibg=#2E2E2E   ctermfg=80      ctermbg=236  gui=NONE           cterm=NONE
hi FoldColumn       guisp=NONE      guifg=#A7A7A7   guibg=#1A1A1A   ctermfg=248     ctermbg=234  gui=NONE           cterm=NONE
hi SignColumn       guisp=NONE      guifg=#444444   guibg=#1A1A1A   ctermfg=238     ctermbg=234  gui=NONE           cterm=NONE
hi IncSearch        guisp=NONE      guifg=#1A1A1A   guibg=#E3A15A   ctermfg=234     ctermbg=179  gui=bold           cterm=bold
hi CurSearch        guisp=NONE      guifg=#1A1A1A   guibg=#E3A15A   ctermfg=234     ctermbg=179  gui=bold           cterm=bold
hi CursorLineNR     guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=bold           cterm=bold
hi LineNr           guisp=NONE      guifg=#6A6A6A   guibg=NONE      ctermfg=242     ctermbg=NONE gui=NONE           cterm=NONE
hi MatchParen       guisp=NONE      guifg=#E3A15A   guibg=NONE      ctermfg=179     ctermbg=NONE gui=bold           cterm=bold
hi ModeMsg          guisp=NONE      guifg=#E8E8E8   guibg=NONE      ctermfg=254     ctermbg=NONE gui=bold           cterm=bold
hi MoreMsg          guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=NONE           cterm=NONE
hi NonText          guisp=NONE      guifg=#444444   guibg=NONE      ctermfg=238     ctermbg=NONE gui=NONE           cterm=NONE
hi NormalFloat      guisp=NONE      guifg=#E8E8E8   guibg=#242424   ctermfg=254     ctermbg=235  gui=NONE           cterm=NONE
hi FloatBorder      guisp=NONE      guifg=#66C6E3   guibg=#242424   ctermfg=80      ctermbg=235  gui=NONE           cterm=NONE
hi Pmenu            guisp=NONE      guifg=#E8E8E8   guibg=#2E2E2E   ctermfg=254     ctermbg=236  gui=NONE           cterm=NONE
hi PmenuSel         guisp=NONE      guifg=#E8E8E8   guibg=#393939   ctermfg=254     ctermbg=237  gui=bold           cterm=bold
hi PmenuSbar        guisp=NONE      guifg=NONE      guibg=#393939   ctermfg=NONE    ctermbg=237  gui=NONE           cterm=NONE
hi PmenuThumb       guisp=NONE      guifg=NONE      guibg=#66C6E3   ctermfg=NONE    ctermbg=80   gui=NONE           cterm=NONE
hi Question         guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=NONE           cterm=NONE
hi QuickFixLine     guisp=NONE      guifg=NONE      guibg=#393939   ctermfg=NONE    ctermbg=237  gui=bold           cterm=bold
hi Search           guisp=NONE      guifg=#1A1A1A   guibg=#A783F8   ctermfg=234     ctermbg=141  gui=NONE           cterm=NONE
hi SpecialKey       guisp=NONE      guifg=#A7A7A7   guibg=NONE      ctermfg=248     ctermbg=NONE gui=NONE           cterm=NONE
hi SpellBad         guisp=#F4005F   guifg=NONE      guibg=NONE      ctermfg=197     ctermbg=NONE gui=undercurl      cterm=underline
hi SpellCap         guisp=#E3A15A   guifg=NONE      guibg=NONE      ctermfg=179     ctermbg=NONE gui=undercurl      cterm=underline
hi SpellLocal       guisp=#66C6E3   guifg=NONE      guibg=NONE      ctermfg=80      ctermbg=NONE gui=undercurl      cterm=underline
hi SpellRare        guisp=#90D64F   guifg=NONE      guibg=NONE      ctermfg=113     ctermbg=NONE gui=undercurl      cterm=underline
hi StatusLine       guisp=NONE      guifg=#E8E8E8   guibg=#242424   ctermfg=254     ctermbg=235  gui=NONE           cterm=NONE
hi StatusLineNC     guisp=NONE      guifg=#A7A7A7   guibg=#242424   ctermfg=248     ctermbg=235  gui=NONE           cterm=NONE
hi TabLine          guisp=NONE      guifg=#A7A7A7   guibg=#242424   ctermfg=248     ctermbg=235  gui=NONE           cterm=NONE
hi TabLineFill      guisp=NONE      guifg=NONE      guibg=#242424   ctermfg=NONE    ctermbg=235  gui=NONE           cterm=NONE
hi TabLineSel       guisp=NONE      guifg=#66C6E3   guibg=#393939   ctermfg=80      ctermbg=237  gui=bold           cterm=bold
hi Title            guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=bold           cterm=bold
hi VisualNOS        guisp=NONE      guifg=NONE      guibg=#393939   ctermfg=NONE    ctermbg=237  gui=bold           cterm=bold
hi WarningMsg       guisp=NONE      guifg=#E3A15A   guibg=NONE      ctermfg=179     ctermbg=NONE gui=NONE           cterm=NONE
hi WildMenu         guisp=NONE      guifg=NONE      guibg=#393939   ctermfg=NONE    ctermbg=237  gui=NONE           cterm=NONE
hi Comment          guisp=NONE      guifg=#A7A7A7   guibg=NONE      ctermfg=248     ctermbg=NONE gui=italic         cterm=italic
hi Constant         guisp=NONE      guifg=#E3A15A   guibg=NONE      ctermfg=179     ctermbg=NONE gui=NONE           cterm=NONE
hi Identifier       guisp=NONE      guifg=#E8E8E8   guibg=NONE      ctermfg=254     ctermbg=NONE gui=NONE           cterm=NONE
hi Statement        guisp=NONE      guifg=#A783F8   guibg=NONE      ctermfg=141     ctermbg=NONE gui=NONE           cterm=NONE
hi PreProc          guisp=NONE      guifg=#A783F8   guibg=NONE      ctermfg=141     ctermbg=NONE gui=NONE           cterm=NONE
hi Type             guisp=NONE      guifg=#5496DD   guibg=NONE      ctermfg=68      ctermbg=NONE gui=NONE           cterm=NONE
hi Special          guisp=NONE      guifg=#5496DD   guibg=NONE      ctermfg=68      ctermbg=NONE gui=NONE           cterm=NONE
hi Underlined       guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=underline      cterm=underline
hi Error            guisp=NONE      guifg=#F4005F   guibg=NONE      ctermfg=197     ctermbg=NONE gui=bold           cterm=bold
hi Todo             guisp=NONE      guifg=#1A1A1A   guibg=#E3A15A   ctermfg=234     ctermbg=179  gui=bold           cterm=bold

hi String           guisp=NONE      guifg=#90D64F   guibg=NONE      ctermfg=113     ctermbg=NONE gui=NONE           cterm=NONE
hi Character        guisp=NONE      guifg=#90D64F   guibg=NONE      ctermfg=113     ctermbg=NONE gui=NONE           cterm=NONE
hi Number           guisp=NONE      guifg=#E3A15A   guibg=NONE      ctermfg=179     ctermbg=NONE gui=NONE           cterm=NONE
hi Boolean          guisp=NONE      guifg=#E3A15A   guibg=NONE      ctermfg=179     ctermbg=NONE gui=NONE           cterm=NONE
hi Float            guisp=NONE      guifg=#E3A15A   guibg=NONE      ctermfg=179     ctermbg=NONE gui=NONE           cterm=NONE
hi Function         guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=NONE           cterm=NONE
hi Conditional      guisp=NONE      guifg=#A783F8   guibg=NONE      ctermfg=141     ctermbg=NONE gui=NONE           cterm=NONE
hi Repeat           guisp=NONE      guifg=#A783F8   guibg=NONE      ctermfg=141     ctermbg=NONE gui=NONE           cterm=NONE
hi Label            guisp=NONE      guifg=#A783F8   guibg=NONE      ctermfg=141     ctermbg=NONE gui=NONE           cterm=NONE
hi Operator         guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=NONE           cterm=NONE
hi Keyword          guisp=NONE      guifg=#A783F8   guibg=NONE      ctermfg=141     ctermbg=NONE gui=NONE           cterm=NONE
hi Include          guisp=NONE      guifg=#A783F8   guibg=NONE      ctermfg=141     ctermbg=NONE gui=NONE           cterm=NONE
hi StorageClass     guisp=NONE      guifg=#5496DD   guibg=NONE      ctermfg=68      ctermbg=NONE gui=NONE           cterm=NONE
hi Structure        guisp=NONE      guifg=#5496DD   guibg=NONE      ctermfg=68      ctermbg=NONE gui=NONE           cterm=NONE
hi Typedef          guisp=NONE      guifg=#5496DD   guibg=NONE      ctermfg=68      ctermbg=NONE gui=NONE           cterm=NONE
hi debugPC          guisp=NONE      guifg=NONE      guibg=#242424   ctermfg=NONE    ctermbg=235  gui=NONE           cterm=NONE
hi debugBreakpoint  guisp=NONE      guifg=#F4005F   guibg=#1A1A1A   ctermfg=197     ctermbg=234  gui=NONE           cterm=NONE

hi DiagnosticError  guisp=NONE      guifg=#F4005F   guibg=NONE      ctermfg=197     ctermbg=NONE gui=NONE           cterm=NONE
hi DiagnosticWarn   guisp=NONE      guifg=#E3A15A   guibg=NONE      ctermfg=179     ctermbg=NONE gui=NONE           cterm=NONE
hi DiagnosticInfo   guisp=NONE      guifg=#66C6E3   guibg=NONE      ctermfg=80      ctermbg=NONE gui=NONE           cterm=NONE
hi DiagnosticHint   guisp=NONE      guifg=#A783F8   guibg=NONE      ctermfg=141     ctermbg=NONE gui=NONE           cterm=NONE
hi DiagnosticOk     guisp=NONE      guifg=#90D64F   guibg=NONE      ctermfg=113     ctermbg=NONE gui=NONE           cterm=NONE

hi DiagnosticUnderlineError guisp=#F4005F guifg=NONE guibg=NONE  ctermfg=NONE    ctermbg=NONE gui=undercurl      cterm=underline
hi DiagnosticUnderlineWarn  guisp=#E3A15A guifg=NONE guibg=NONE  ctermfg=NONE    ctermbg=NONE gui=undercurl      cterm=underline
hi DiagnosticUnderlineInfo  guisp=#66C6E3 guifg=NONE guibg=NONE  ctermfg=NONE    ctermbg=NONE gui=undercurl      cterm=underline
hi DiagnosticUnderlineHint  guisp=#A783F8 guifg=NONE guibg=NONE  ctermfg=NONE    ctermbg=NONE gui=undercurl      cterm=underline
hi DiagnosticUnderlineOk    guisp=#90D64F guifg=NONE guibg=NONE  ctermfg=NONE    ctermbg=NONE gui=undercurl      cterm=underline

" gitsigns and diff signs take their colors from these.
hi Added            guisp=NONE      guifg=#90D64F   guibg=NONE      ctermfg=113     ctermbg=NONE gui=NONE           cterm=NONE
hi Changed          guisp=NONE      guifg=#E3A15A   guibg=NONE      ctermfg=179     ctermbg=NONE gui=NONE           cterm=NONE
hi Removed          guisp=NONE      guifg=#F4005F   guibg=NONE      ctermfg=197     ctermbg=NONE gui=NONE           cterm=NONE

" Treesitter defaults @variable to nvim's own text color instead of Normal.
hi @variable        guisp=NONE      guifg=#E8E8E8   guibg=NONE      ctermfg=254     ctermbg=NONE gui=NONE           cterm=NONE

" CUSTOM
" Same color as NonText so leading dots, eol arrows, and ibl indent guides all match.
hi Whitespace       guisp=NONE      guifg=#444444   guibg=NONE      ctermfg=238     ctermbg=NONE gui=NONE           cterm=NONE

" hi clear does not reset these, so the previous colorscheme's :terminal colors would linger.
let g:terminal_color_0  = '#1A1A1A'
let g:terminal_color_1  = '#F4005F'
let g:terminal_color_2  = '#90D64F'
let g:terminal_color_3  = '#E3A15A'
let g:terminal_color_4  = '#5496DD'
let g:terminal_color_5  = '#A783F8'
let g:terminal_color_6  = '#66C6E3'
let g:terminal_color_7  = '#A7A7A7'
let g:terminal_color_8  = '#444444'
let g:terminal_color_9  = '#F4005F'
let g:terminal_color_10 = '#90D64F'
let g:terminal_color_11 = '#E3A15A'
let g:terminal_color_12 = '#5496DD'
let g:terminal_color_13 = '#A783F8'
let g:terminal_color_14 = '#66C6E3'
let g:terminal_color_15 = '#E8E8E8'

hi link Define PreProc
hi link Macro PreProc
hi link PreCondit PreProc
hi link SpecialChar Special
hi link Tag Special
hi link Delimiter Special
hi link SpecialComment Special
hi link Debug Special
hi link Exception Error
hi link StatusLineTerm StatusLine
hi link StatusLineTermNC StatusLineNC
hi link Terminal Normal
hi link Ignore Comment
hi link WinSeparator VertSplit
