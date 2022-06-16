if exists('g:loaded_brodir')
  finish
endif
let g:loaded_brodir = 1

lua require("brodir")

command! -bar -nargs=? -complete=dir Brodir lua package.loaded.brodir.open(<f-args>)
