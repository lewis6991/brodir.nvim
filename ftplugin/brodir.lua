local function map(mode)
  return function(first)
    return function(second)
      local opts = {}
      if type(second) == 'table' then
        opts = second
        second = opts[1]
        opts[1] = nil
      end
      opts.buffer = true
      vim.keymap.set(mode, first, second, opts)
    end
  end
end

if vim.fn.hasmapto('<Plug>(brodir_quit)', 'n') == 0 then
  map 'n' '<ESC>' {'<Plug>(brodir_quit)', nowait=true, silent=true}
  map 'n' 'q'     {'<Plug>(brodir_quit)', nowait=true, silent=true}
end

if vim.fn.hasmapto('<Plug>(brodir_K)', 'n') == 0 then
  map {'n', 'x'} 'K' {'<Plug>(brodir_K)', nowait=true}
end

if vim.fn.hasmapto('<Plug>(brodir_up)', 'n') == 0 then
  map 'n' '-' {'<Plug>(brodir_up)', nowait=true}
end

map 'n' '~' {':<C-U>Brodir ~/<CR>', nowait=true, silent=true}

map 'n' 'g?' {':help brodir-mappings<CR>', silent=true}

-- Buffer-local / and ? mappings to skip the concealed path fragment.
map 'n' '/' {'/\\ze[^/]*[/]\\=$<Home>'}
map 'n' '?' {'?\\ze[^/]*[/]\\=$<Home>'}

local function map_open(a)
  return function()
    require('brodir').open(nil, a)
  end
end

map 'n' '<CR>' {map_open('edit'   )}
map 'n' 'v'    {map_open('vsplit' )}
map 'n' 'V'    {map_open('vsplit' )}
map 'n' 's'    {map_open('split'  )}
map 'n' 'S'    {map_open('split'  )}
map 'n' 't'    {map_open('tabedit')}
map 'n' 'T'    {map_open('tabedit')}
