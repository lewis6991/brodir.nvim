if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

if !hasmapto('<Plug>(dirvish_quit)', 'n')
  nmap <nowait><buffer> q :echohl WarningMsg<Bar>echo "q is deprecated, use gq instead"<Bar>echohl NONE<cr>
  nmap <nowait><buffer> gq <Plug>(dirvish_quit)
endif
if !hasmapto('<Plug>(dirvish_arg)', 'n')
  nmap <nowait><buffer> x <Plug>(dirvish_arg)
  xmap <nowait><buffer> x <Plug>(dirvish_arg)
endif
if !hasmapto('<Plug>(dirvish_K)', 'n')
  nmap <nowait><buffer> K <Plug>(dirvish_K)
  xmap <nowait><buffer> K <Plug>(dirvish_K)
endif

nnoremap <buffer><silent> <Plug>(dirvish_up) :<C-U>exe "Dirvish %:h".repeat(":h",v:count1)<CR>
nnoremap <buffer><silent> <Plug>(dirvish_split_up) :<C-U>exe 'split +Dirvish\ %:h'.repeat(':h',v:count1)<CR>
nnoremap <buffer><silent> <Plug>(dirvish_vsplit_up) :<C-U>exe 'vsplit +Dirvish\ %:h'.repeat(':h',v:count1)<CR>
if !hasmapto('<Plug>(dirvish_up)', 'n')
  nmap <nowait><buffer> - <Plug>(dirvish_up)
endif

nnoremap <nowait><buffer><silent> ~    :<C-U>Dirvish ~/<CR>
nnoremap <nowait><buffer><silent> i    :<C-U>.call dirvish#open("edit", 0)<CR>
nnoremap <nowait><buffer><silent> <CR> :<C-U>.call dirvish#open("edit", 0)<CR>
nnoremap <nowait><buffer><silent> a    :<C-U>.call dirvish#open("vsplit", 1)<CR>
nnoremap <nowait><buffer><silent> o    :<C-U>.call dirvish#open("split", 1)<CR>
nnoremap <nowait><buffer><silent> p    :<C-U>.call dirvish#open("p", 1)<CR>
nnoremap <nowait><buffer><silent> <2-LeftMouse> :<C-U>.call dirvish#open("edit", 0)<CR>
nnoremap <nowait><buffer><silent> dax  :<C-U>arglocal<Bar>silent! argdelete *<Bar>echo "arglist: cleared"<Bar>Dirvish %<CR>
nnoremap <nowait><buffer><silent> <C-n> <C-\><C-n>j:call feedkeys("p")<CR>
nnoremap <nowait><buffer><silent> <C-p> <C-\><C-n>k:call feedkeys("p")<CR>

xnoremap <nowait><buffer><silent> I    :call dirvish#open("edit", 0)<CR>
xnoremap <nowait><buffer><silent> <CR> :call dirvish#open("edit", 0)<CR>
xnoremap <nowait><buffer><silent> A    :call dirvish#open("vsplit", 1)<CR>
xnoremap <nowait><buffer><silent> O    :call dirvish#open("split", 1)<CR>
xnoremap <nowait><buffer><silent> P    :call dirvish#open("p", 1)<CR>

nnoremap <buffer><silent> R :<C-U><C-R>=v:count ? ':let g:dirvish_mode='.v:count.'<Bar>' : ''<CR>Dirvish %<CR>
nnoremap <buffer><silent>   g?    :help dirvish-mappings<CR>

nnoremap <expr><nowait><buffer> . ":<C-u>".(v:count ? "Shdo".(v:count?"!":"")." {}" : ("! ".shellescape(fnamemodify(getline("."),":."))))."<Home><C-Right>"
nnoremap <expr><nowait><buffer> cd ":<C-u>".(v:count ? "cd" : "lcd")." %<Bar>pwd<CR>"

" Buffer-local / and ? mappings to skip the concealed path fragment.
nnoremap <buffer> / /\ze[^/]*[/]\=$<Home>
nnoremap <buffer> ? ?\ze[^/]*[/]\=$<Home>

" Force autoload if `ft=dirvish`
if !exists('*dirvish#open')|try|call dirvish#open()|catch|endtry|endif
