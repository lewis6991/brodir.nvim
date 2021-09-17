if exists('g:loaded_dirvish')
  finish
endif
let g:loaded_dirvish = 1

lua require("dirvish")

command! -bar -nargs=? -complete=dir Dirvish lua package.loaded.dirvish.open(<f-args>)

augroup dirvish
  autocmd!

  " Remove netrw directory handlers.
  autocmd VimEnter * silent! autocmd! FileExplorer *

  autocmd BufEnter *
    \   if &l:ft != 'dirvish' && isdirectory(expand('%:p'))
    \ |   exe 'lua package.loaded.dirvish.open()'
    \ | endif

  autocmd FileType dirvish
      \   if exists('#fugitive')
      \ |   call FugitiveDetect(@%)
      \ | endif
augroup END

