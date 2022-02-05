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

  " Reset horizontal scroll when moving cursor
  " Need to do this as Conceal causes some weird scrolling behaviour on narrow
  " windows.
  autocmd FileType dirvish
      \ autocmd WinScrolled <buffer> normal 99zH
augroup END

