if exists('g:loaded_dirvish') || &cp || &cpo =~# 'C'
  finish
endif
let g:loaded_dirvish = 1

lua require("dirvish")

command! -bar -nargs=? -complete=dir Dirvish lua package.loaded.dirvish.open(<f-args>)

function! s:isdir(dir)
  return !empty(a:dir) && (isdirectory(a:dir) ||
    \ (!empty($SYSTEMDRIVE) && isdirectory('/'.tolower($SYSTEMDRIVE[0]).a:dir)))
endfunction

augroup dirvish
  autocmd!
  " Remove netrw and NERDTree directory handlers.
  autocmd VimEnter *
      \   if exists('#FileExplorer')
      \ |   exe 'au! FileExplorer *'
      \ | endif

  autocmd BufEnter *
    \   if !exists('b:dirvish') && <SID>isdir(expand('%:p'))
    \ |   exe 'Dirvish %:p'
    \ | elseif exists('b:dirvish') && &buflisted && bufnr('$') > 1
    \ |   setlocal nobuflisted
    \ | endif

  autocmd FileType dirvish
      \   if exists('#fugitive')
      \ |   call FugitiveDetect(@%)
      \ | endif

  autocmd ShellCmdPost * if exists('b:dirvish') | exe 'Dirvish %' | endif
augroup END

