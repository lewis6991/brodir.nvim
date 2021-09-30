if 'dirvish' !=# get(b:, 'current_syntax', 'dirvish')
  finish
endif

syntax spell notoplevel

let s:escape = 'substitute(escape(v:val, ".$~"), "*", ".*", "g")'

" Define once (per buffer).
if !exists('b:current_syntax')
  syntax match DirvishPathHead "/.*/\ze[^/]\+/\?$" conceal
  syntax match DirvishPathTail "[^/]\+/$"
  exe 'syntax match DirvishSuffix   "[^/]*\%('.join(map(split(&suffixes, ','), s:escape), '\|') . '\)$"'
endif

highlight default link DirvishSuffix   SpecialKey
highlight default link DirvishPathTail Directory
highlight default link DirvishOpenBuf  Todo

let b:current_syntax = 'dirvish'
