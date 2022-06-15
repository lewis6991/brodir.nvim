-- if vim.fn.exists("b:did_ftplugin") == 1 then
--   return
-- end

-- vim.b.did_ftplugin = 1

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

if vim.fn.hasmapto('<Plug>(dirvish_quit)', 'n') == 0 then
  map 'n' '<ESC>' {'<Plug>(dirvish_quit)', nowait=true, silent=true}
  map 'n' 'q'     {'<Plug>(dirvish_quit)', nowait=true, silent=true}
end

if vim.fn.hasmapto('<Plug>(dirvish_K)', 'n') == 0 then
  map {'n', 'x'} 'K' {'<Plug>(dirvish_K)', nowait=true}
end

if vim.fn.hasmapto('<Plug>(dirvish_up)', 'n') == 0 then
  map 'n' '-' {'<Plug>(dirvish_up)', nowait=true}
end

map 'n' '~' {':<C-U>Dirvish ~/<CR>', nowait=true, silent=true}

map 'n' 'g?' {':help dirvish-mappings<CR>', silent=true}

-- Buffer-local / and ? mappings to skip the concealed path fragment.
map 'n' '/' {'/\\ze[^/]*[/]\\=$<Home>'}
map 'n' '?' {'?\\ze[^/]*[/]\\=$<Home>'}

local module = require('dirvish')

map 'n' '<CR>'  {function() module.open(nil, 'edit'   ) end, silent=true}
map 'n' 'v'     {function() module.open(nil, 'vsplit' ) end, silent=true}
map 'n' 'V'     {function() module.open(nil, 'vsplit' ) end, silent=true}
map 'n' 's'     {function() module.open(nil, 'split'  ) end, silent=true}
map 'n' 'S'     {function() module.open(nil, 'split'  ) end, silent=true}
map 'n' 't'     {function() module.open(nil, 'tabedit') end, silent=true}
map 'n' 'T'     {function() module.open(nil, 'tabedit') end, silent=true}
