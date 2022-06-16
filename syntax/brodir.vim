if 'brodir' !=# get(b:, 'current_syntax', 'brodir')
  finish
endif

syntax spell notoplevel

let s:escape = 'substitute(escape(v:val, ".$~"), "*", ".*", "g")'

" Define once (per buffer).
if !exists('b:current_syntax')
  syntax match BrodirPathHead "/.*/\ze[^/]\+/\?$" conceal
  syntax match BrodirPathTail "[^/]\+/$"
  exe 'syntax match BrodirSuffix   "[^/]*\%('.join(map(split(&suffixes, ','), s:escape), '\|') . '\)$"'
endif

highlight default link BrodirSuffix   SpecialKey
highlight default link BrodirPathTail Directory
highlight default link BrodirOpenBuf  Todo

let b:current_syntax = 'brodir'
