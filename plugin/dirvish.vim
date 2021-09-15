if exists('g:loaded_dirvish') || &cp || &cpo =~# 'C'
  finish
endif
let g:loaded_dirvish = 1

let s:lua_module = luaeval('require("dirvish")')

function! dirvish#open(...) range abort
  call s:lua_module.open(a:firstline, a:lastline, a:000)
endfunction

command! -bar -nargs=? -complete=dir Dirvish call dirvish#open(<q-args>)

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

nnoremap <silent> <Plug>(dirvish_up)        <cmd>exe 'Dirvish %:p'.repeat(':h',v:count1)<CR>
nnoremap <silent> <Plug>(dirvish_split_up)  <cmd>exe 'split +Dirvish\ %:p'.repeat(':h',v:count1)<CR>
nnoremap <silent> <Plug>(dirvish_vsplit_up) <cmd>exe 'vsplit +Dirvish\ %:p'.repeat(':h',v:count1)<CR>

highlight default link DirvishSuffix   SpecialKey
highlight default link DirvishPathTail Directory
highlight default link DirvishArg      Todo

if mapcheck('-', 'n') ==# '' && !hasmapto('<Plug>(dirvish_up)', 'n')
  nmap - <Plug>(dirvish_up)
endif
