local fn, api = vim.fn, vim.api

local util = require('dirvish.util')

local ns = api.nvim_create_namespace('dirvish')

local fnamemodify = fn.fnamemodify
local format = string.format

local function getline(n)
  return api.nvim_buf_get_lines(0, n, n+1, false)[1]
end

local function getlines(buf)
  return api.nvim_buf_get_lines(buf or 0, 0, -1, false)
end

local function info()
  local dirsize = vim.v.count
  local paths = getlines()

  for i, f in ipairs(paths) do
    f = util.trim(f)
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
  if not util.isdirectory(dir) then
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

local function list_dir(dir)
  local paths = {}
  for p in vim.fs.dir(dir) do
    paths[#paths+1] = dir..p
  end

  return vim.tbl_map(function(v)
    return fnamemodify(v, ':p')
  end, paths)
end

local function get_or_create_win(buf)
  for _, w in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(w) == buf then
      return w
    end
  end

  local win

  if api.nvim_buf_get_name(0) == '' then
    win = api.nvim_get_current_win()
    api.nvim_win_set_buf(win, buf)
  else
    local lines   = vim.o.lines
    local columns = vim.o.columns
    local width   = math.ceil(columns * 0.3)
    local height  = math.ceil(lines * 0.8)
    local top     = ((lines - height) / 2) - 1
    local left    = columns - width

    win = api.nvim_open_win(buf, true, {
      relative = 'editor',
      row      = top,
      col      = left,
      width    = width,
      height   = height,
      style    = 'minimal',
      border   = 'rounded'
    })
  end

  -- Set the alternate buffer to itself
  vim.fn.setreg('#', buf)

  return win
end

-- Buffer to use for floats and new windows
local dbuf = api.nvim_create_buf(false, true)

local function get_buf(dir)
  for _, b in ipairs(api.nvim_list_bufs()) do
    if vim.bo[b].filetype == 'dirvish' or normalize_dir(api.nvim_buf_get_name(b), true) == dir then
      -- Buf with dir already open
      return b
    end
  end
  return dbuf
end

local handlers = {
  'dirvish.handlers.git',
  'dirvish.handlers.open',
  'dirvish.handlers.icons'
}

local function buf_render(buf, dir, from_path)
  api.nvim_buf_set_name(buf, dir)

  -- nvim_buf_set_name creates an alternate buffer with the name we are changing
  -- from. Delete it.
  api.nvim_buf_call(buf, function()
    local alt = fn.bufnr('#')
    if alt ~= buf and alt ~= -1 then
      pcall(api.nvim_buf_delete, alt, {force=true})
    end
  end)

  vim.bo[buf].filetype = 'dirvish'
  vim.bo[buf].buftype  = 'nofile'
  vim.bo[buf].swapfile = false

  local win = get_or_create_win(buf)

  vim.wo[win].cursorline    = true
  vim.wo[win].wrap          = false
  vim.wo[win].concealcursor = 'nvc'
  vim.wo[win].conceallevel  = 2

  local lines = list_dir(dir)

  vim.bo[buf].modifiable = true

  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  if type(vim.g.dirvish_mode) == 'string' then -- Apply user's filter.
    api.nvim_buf_call(buf, function()
      vim.cmd(vim.g.dirvish_mode)
    end)
  end

  vim.bo[buf].modifiable = false

  for _, handler in ipairs(handlers) do
    require(handler)(buf, dir, lines)
  end

  fn.search([[\V\^\s\*]]..from_path..'\\$', 'cw')

  -- Place cursor on the tail (last path segment).
  fn.search('\\/\\zs[^\\/]\\+\\/\\?$', 'c', fn.line('.'))
end

local M = {}

function M.open_up(splitcmd)
  local path = api.nvim_buf_get_name(0)
  M.open(vim.fn.fnamemodify(path, ':h'), splitcmd)
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
      if vim.bo.filetype == 'dirvish' and fn.win_gettype() == 'popup' then
        -- close the dirvish float
        api.nvim_win_close(0, false)
      end
      vim.cmd('keepalt '..splitcmd..' '..fn.fnameescape(path))
      return
    end

    if not util.isdirectory(path) then -- sanity check
      msg_error("invalid (access denied?): "..path)
    end
  end

  local is_uri = fn.match(path, '^\\w\\+:[\\/][\\/]') ~= -1

  local to_path = fnamemodify(path, ':p') -- resolves to CWD if a:1 is empty
  local dir = fn.filereadable(to_path) == 1 and fnamemodify(to_path, ':p:h') or to_path
  dir = normalize_dir(dir, is_uri)

  if not util.isdirectory(dir) then
    api.nvim_err_writeln('dirvish: fatal: buffer name is not a directory: '..dir)
    error('DEBUG')
    return
  elseif dir == '' then  -- normalize_dir() already showed error.
    error('DEBUG')
    return
  end

  local from_path = fnamemodify(api.nvim_buf_get_name(0), ':p')
  buf_render(get_buf(dir), dir, from_path)
end

local function setup_autocmds()
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
      if vim.bo.filetype ~= 'dirvish' and vim.fn.isdirectory(fn.expand('%:p')) == 1 then
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
      api.nvim_create_autocmd('WinScrolled', {
        buffer = api.nvim_get_current_buf(),
        command = 'normal 99zH'
      })
    end
  })
end

function M.setup()
  local function keymap(mode, l, r)
    if type(r) == 'function' then
      local r1 = r
      r = function() r1() end
    end
    vim.keymap.set(mode, l, r, {silent=true})
  end

  keymap('n', '-', M.open)
  keymap('n', '<Plug>(dirvish_up)'  , M.open_up)
  keymap('n', '<Plug>(dirvish_quit)', [[<cmd>bdelete!<CR>]])
  keymap({'n', 'x'}, '<Plug>(dirvish_K)', info)

  local function hl_link(hl, link)
    api.nvim_set_hl(0, hl, { link = link })
  end

  hl_link('DirvishSuffix'  , 'SpecialKey')
  hl_link('DirvishPathTail', 'Directory' )
  hl_link('DirvishArg'     , 'Todo'      )

  setup_autocmds()
end

M.setup()

return M
