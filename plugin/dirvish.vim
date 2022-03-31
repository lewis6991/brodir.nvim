if exists('g:loaded_dirvish')
  finish
endif
let g:loaded_dirvish = 1

lua require("dirvish")

command! -bar -nargs=? -complete=dir Dirvish lua package.loaded.dirvish.open(<f-args>)
