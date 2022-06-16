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

let b:current_syntax = 'brodir'
