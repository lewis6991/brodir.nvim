local function nmap(first, second, opts)
  opts = opts or {}
  opts.buffer = true
  vim.keymap.set('n', first, second, opts)
end

local function wrap(f, ...)
  local args = {...}
  return function()
    f(unpack(args))
  end
end

local brodir = require('brodir')

nmap('<ESC>', '<cmd>bdelete!<cr>'   , {nowait=true, silent=true})
nmap('q'    , '<cmd>bdelete!<cr>'   , {nowait=true, silent=true})
nmap('K'    , wrap(brodir.info)     , {nowait=true})
nmap('-'    , wrap(brodir.open_up)  , {nowait=true})
nmap('~'    , wrap(brodir.open, '~'), {nowait=true, silent=true})

nmap('g?', '<cmd>help brodir-mappings<CR>', {silent=true})

-- Buffer-local / and ? mappings to skip the concealed path fragment.
nmap('/', '/\\ze[^/]*[/]\\=$<Home>')
nmap('?', '?\\ze[^/]*[/]\\=$<Home>')

nmap('<CR>', wrap(brodir.open, nil, 'edit'   ))
nmap('v'   , wrap(brodir.open, nil, 'vsplit' ))
nmap('V'   , wrap(brodir.open, nil, 'vsplit' ))
nmap('s'   , wrap(brodir.open, nil, 'split'  ))
nmap('S'   , wrap(brodir.open, nil, 'split'  ))
nmap('t'   , wrap(brodir.open, nil, 'tabedit'))
nmap('T'   , wrap(brodir.open, nil, 'tabedit'))
