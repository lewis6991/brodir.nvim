local fn, api = vim.fn, vim.api

local M = {}

local ns = api.nvim_create_namespace('dirvish')

local fnamemodify = fn.fnamemodify
local format = string.format

local function getline(n)
  return api.nvim_buf_get_lines(0, n, n+1, false)[1]
end

local function isdirectory(d)
  local stat = vim.loop.fs_stat(d)
  return stat and stat.type == 'directory'
end

local function trim(s)
   return s:gsub("^%s*(.-)%s*$", "%1")
end

function M.info()
  local dirsize = vim.v.count
  local paths = api.nvim_buf_get_lines(0, 0, -1, false)

  for i, f in ipairs(paths) do
    f = trim(f)
    -- Slash decides how getftype() classifies directory symlinks. #138
    local noslash = fn.substitute(f, fn.escape('/','\\')..'$', '', 'g')

    local size
    if fn.getfsize(f) ~= -1 and dirsize == 1 then
      size = fn.matchstr(fn.system('du -hs '..fn.shellescape(f)), '\\S\\+')
    else
      size = format('%.2f', fn.getfsize(f)/1000)..'K'
    end
    if fn.getfsize(f) == -1 then
      print('?')
    else
      local ty = fn.getftype(noslash):sub(1, 1)
      local time = fn.strftime('%Y-%m-%d.%H:%M:%S', fn.getftime(f))
      local msg = format('%s %s %s %s ', ty, fn.getfperm(f), time, size)
        ..('link' ~= fn.getftype(noslash) and '' or ' -> '..fnamemodify(fn.resolve(f),':~:.'))
      local id = api.nvim_buf_set_extmark(0, ns, i-1, 0, {
        id = i,
        virt_text = {{ msg , 'Comment' }},
        virt_text_pos = 'right_align'
      })

      vim.cmd(format(
        [[autocmd CursorMoved <buffer> ++once lua vim.api.nvim_buf_del_extmark(%d, %d, %d)]], 0, ns, id
      ))
    end
  end
end

local function msg_error(msg)
  vim.notify(msg, vim.log.levels.WARN, {title = 'dirvish'})
end

local function normalize_dir(dir, silent)
  if not isdirectory(dir) then
    -- Fallback for cygwin/MSYS paths lacking a drive letter.
    if not silent then
      msg_error("invalid directory: '"..dir.."'")
    end
    return ''
  end

  -- Always end with separator.
  if dir:sub(-1) ~= '/' then
    dir = dir..'/'
  end

  return dir
end

local function suf()
  local m = vim.g.dirvish_mode or 1
  return type(m) == 'number' and m <= 1
end

local function globlist(dir_esc, pat)
  return fn.globpath(dir_esc, pat, not suf(), 1)
end

local function list_dir(dir)
  -- Escape for globpath().
  local dir_esc = fn.escape(fn.substitute(dir,'\\[','[[]','g'), ',;*?{}^$\\')
  local paths = globlist(dir_esc, '*')
  -- Append dot-prefixed files. globpath() cannot do both in 1 pass.
  paths = vim.list_extend(paths, globlist(dir_esc, '.[^.]*'))

  return vim.tbl_map(function(v) return fnamemodify(v, ':p') end, paths)
end

local function get_or_create_win(buf)
  for _, w in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(w) == buf then
      return w
    end
  end

  local lines   = vim.o.lines
  local columns = vim.o.columns
  local width   = fn.float2nr(columns * 0.3)
  local height  = fn.float2nr(lines * 0.8)
  local top     = ((lines - height) / 2) - 1
  local left    = columns - width
  local win

  if api.nvim_buf_get_name(0) == '' then
    win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
  else
    win = api.nvim_open_win(buf, true, {
      relative = 'editor',
      row      = top,
      col      = left,
      width    = width,
      height   = height,
      style    = 'minimal',
      border   = 'single'
    })
  end

  -- Set the alternate buffer to itself
  vim.fn.setreg('#', buf)

  return win
end

local function get_or_create_buf(name)
  for _, b in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_get_option(b, 'filetype') == 'dirvish' then
      return b
    elseif normalize_dir(api.nvim_buf_get_name(b), true) == normalize_dir(name, true) then
      return b
    end
  end
  return api.nvim_create_buf(false, true)
end

-- Change a buffers name and delete any newly created alternate buffers
local function buf_set_name(buf, name)
  api.nvim_buf_set_name(buf, name)

  -- -- nvim_buf_set_name creates an alternate buffer with the name we are changing
  -- -- from. Delete it.
  -- api.nvim_buf_call(buf, function()
  --   local alt = fn.bufnr('#')
  --   if alt ~= buf and alt ~= -1 then
  --     pcall(api.nvim_buf_delete, alt, {force=true})
  --   end
  -- end)
end

local function get_icon(line)
  local ext = line:match('%.([a-zA-Z]+)$')
  return require('nvim-web-devicons').get_icon(line, ext, {default=true})
end

local function add_icons(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)

  for i, l in ipairs(lines) do
    local icon = get_icon(l)
    api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
      virt_text = {{icon, 'NonText'}},
      virt_text_pos = 'overlay'
    })
  end
end

local function highlight_open_paths(buf)
  local lines = api.nvim_buf_get_lines(buf, 0, -1, false)

  local bufs = {}
  for _, b in ipairs(api.nvim_list_bufs()) do
    local name = api.nvim_buf_get_name(b)
    bufs[name] = b
  end

  for i, l in ipairs(lines) do
    if bufs[l] then
      api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
        hl_group = 'DirvishOpenBuf',
        end_col = #l
      })
    end
  end
end

local function buf_render(dir, from_path)
  local buf = get_or_create_buf(dir)

  api.nvim_buf_set_option(buf, 'filetype' , 'dirvish')
  api.nvim_buf_set_option(buf, 'buftype'  , 'nofile')
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'swapfile' , false)

  buf_set_name(buf, dir)

  local win = get_or_create_win(buf)

  api.nvim_win_set_option(win, 'cursorline'   , true)
  api.nvim_win_set_option(win, 'wrap'         , false)
  api.nvim_win_set_option(win, 'concealcursor', 'nvc')
  api.nvim_win_set_option(win, 'conceallevel' , 2)

  api.nvim_buf_set_option(buf, 'modifiable', true)

  local lines = list_dir(dir)
  for i = 1, #lines do
    -- Insert padding to place an icon
    lines[i] = '  '..lines[i]
  end

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  if type(vim.g.dirvish_mode) == 'string' then -- Apply user's filter.
    api.nvim_buf_call(buf, function()
      vim.cmd(vim.g.dirvish_mode)
    end)
  end

  api.nvim_buf_set_option(buf, 'modifiable' , false)

  highlight_open_paths(buf)
  add_icons(buf)

  fn.search([[\V\^\s\*]]..from_path..'\\$', 'cw')

  -- -- FIXME: this hides the icon in floating window
  -- -- Place cursor on the tail (last path segment).
  -- fn.search('\\/\\zs[^\\/]\\+\\/\\?$', 'c', fn.line('.'))
end

function M.open(path, splitcmd)
  if vim.o.autochdir then
    msg_error("'autochdir' is not supported")
    return
  end

  if not path then
    if vim.bo.filetype == 'dirvish' then
      local line = api.nvim_win_get_cursor(0)[1]
      path = getline(line-1):match('^%s*(.*)')
    else
      path = api.nvim_buf_get_name(0)
    end
  end

  if splitcmd then
    if fn.filereadable(path) == 1 then
      if fn.win_gettype() == 'popup' then
        vim.cmd'bwipeout' -- close the dirvish float
      end
      vim.cmd(splitcmd..' '..fn.fnameescape(path))
      return
    end

    if not isdirectory(path) then -- sanity check
      msg_error("invalid (access denied?): "..path)
    end
  end

  local is_uri = fn.match(path, '^\\w\\+:[\\/][\\/]') ~= -1

  local to_path = fnamemodify(path, ':p') -- resolves to CWD if a:1 is empty
  local dir = fn.filereadable(to_path) == 1 and fnamemodify(to_path, ':p:h') or to_path
  dir = normalize_dir(dir, is_uri)

  if not isdirectory(dir) then
    api.nvim_err_writeln('dirvish: fatal: buffer name is not a directory: '..dir)
    return
  elseif dir == '' then  -- normalize_dir() already showed error.
    return
  end

  local from_path = fnamemodify(api.nvim_buf_get_name(0), ':p')
  buf_render(dir, from_path)
end

function M.setup()
  local function keymap(mode, l, r)
    api.nvim_set_keymap(mode, l, r, {noremap=true, silent=true})
  end

  keymap('n', '<Plug>(dirvish_up)'       , [[<cmd>exe 'Dirvish %:p'.repeat(':h',v:count1)<CR>]])
  keymap('n', '<Plug>(dirvish_split_up)' , [[<cmd>exe 'split +Dirvish\ %:p'.repeat(':h',v:count1)<CR>]])
  keymap('n', '<Plug>(dirvish_vsplit_up)', [[<cmd>exe 'vsplit +Dirvish\ %:p'.repeat(':h',v:count1)<CR>]])
  keymap('n', '<Plug>(dirvish_quit)'     , [[<cmd>bdelete!<CR>]])
  keymap('n', '<Plug>(dirvish_K)'        , [[<cmd>lua package.loaded.dirvish.info()<CR>]])
  keymap('x', '<Plug>(dirvish_K)'        , [[<cmd>lua package.loaded.dirvish.info()<CR>]])

  api.nvim_set_keymap('n', '-', '<cmd>lua package.loaded.dirvish.open()<CR>' , {silent=true})

  vim.cmd[[
    highlight default link DirvishSuffix   SpecialKey
    highlight default link DirvishPathTail Directory
    highlight default link DirvishArg      Todo
  ]]

  local group = api.nvim_create_augroup('dirvish', {})

  -- Remove netrw directory handlers.
  api.nvim_create_autocmd('VimEnter', {
    group = group,
    callback = function()
      api.nvim_create_augroup('FileExplorer', {}) -- clear the group
      api.nvim_del_augroup_by_name('FileExplorer')
    end
  })

  api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function()
      if vim.bo.filetype ~= 'dirvish' and vim.fn.isdirectory(vim.fn.expand('%:p')) == 1 then
        M.open()
      end
    end
  })

  api.nvim_create_autocmd('FileType', {
    pattern = 'dirvish',
    group = group,
    callback = function()
      if vim.fn.exists('#fugitive') == 1 then
        vim.cmd'call FugitiveDetect(@%)'
      end

      -- Reset horizontal scroll when moving cursor
      -- Need to do this as Conceal causes some weird scrolling behaviour on narrow
      -- windows.
      vim.cmd'autocmd WinScrolled <buffer> normal 99zH'
    end
  })

end

M.setup()

return M
