local fn, api, luv = vim.fn, vim.api, vim.loop

local util = require('brodir.util')

local ns = api.nvim_create_namespace('brodir')

local fnamemodify = fn.fnamemodify
local format = string.format

local buf_name = api.nvim_buf_get_name

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

    local size = fn.getfsize(f)
    if size > 0 then
      size = format('%.2f', size/1000)..'K'
    elseif size == 0 and dirsize <= 1 then
      size = fn.matchstr(fn.system{'du', '-hs', f}, '\\S\\+')
    end

    if size == -1 then
      print('?')
    else
      local stat = luv.fs_stat(f)
      local ty = stat.type:sub(1, 1)
      local time = fn.strftime('%Y-%m-%d %H:%M', stat.mtime.sec)
      local msg = format('%s %s %s %6s ', ty, fn.getfperm(f), time, size)
        ..('link' ~= fn.getftype(noslash) and '' or ' -> '..fnamemodify(fn.resolve(f),':~:.'))
      local id = api.nvim_buf_set_extmark(0, ns, i-1, 0, {
        id = i,
        virt_text = {{ msg , 'Comment' }},
        virt_text_pos = 'right_align'
      })

      api.nvim_create_autocmd('CursorMoved', {
        buffer = 0,
        once = true,
        callback = function()
          api.nvim_buf_del_extmark(0, ns, id)
        end
      })
    end
  end
end

local function msg_error(msg)
  vim.notify(msg, vim.log.levels.WARN, {title = 'brodir'})
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
  for p, ty in vim.fs.dir(dir) do
    local trailslash = ty == 'directory' and '/' or ''
    paths[#paths+1] = dir..p..trailslash
  end

  return paths
end

local function get_or_create_win(buf)
  for _, w in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(w) == buf then
      return w
    end
  end

  local win

  if buf_name(0) == '' then
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
  fn.setreg('#', buf)

  return win
end

-- Buffer to use for floats and new windows
local dbuf = api.nvim_create_buf(false, true)

local function get_buf(dir)
  for _, b in ipairs(api.nvim_list_bufs()) do
    if vim.bo[b].filetype == 'brodir' or normalize_dir(buf_name(b), true) == dir then
      -- Buf with dir already open
      return b
    end
  end
  return dbuf
end

local handlers = {
  'brodir.handlers.git',
  'brodir.handlers.open',
  'brodir.handlers.icons'
}

local function buf_render(buf, dir, from_path)
  api.nvim_buf_set_name(buf, dir)

  -- nvim_buf_set_name creates an alternate buffer with the name we are changing
  -- from. Delete it.
  local alt = api.nvim_buf_call(buf, function()
    return fn.bufnr('#')
  end)
  if alt ~= buf and alt ~= -1 then
    pcall(api.nvim_buf_delete, alt, {force=true})
  end

  vim.bo[buf].filetype = 'brodir'
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
  local path = vim.fs.dirname(buf_name(0))
  M.open(path, splitcmd)
end

local function get_path()
  if vim.bo.filetype == 'brodir' then
    local line = api.nvim_win_get_cursor(0)[1]
    return getline(line-1)
  end
  return buf_name(0)
end

function M.open(path, splitcmd)
  if vim.o.autochdir then
    msg_error("'autochdir' is not supported")
    return
  end

  path = path or get_path()

  if splitcmd then
    if fn.filereadable(path) == 1 then
      if vim.bo.filetype == 'brodir' and fn.win_gettype() == 'popup' then
        -- close the brodir float
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

  local to_path = fnamemodify(path, ':p')
  local dir = luv.fs_stat(to_path) and fnamemodify(to_path, ':p:h') or to_path
  dir = normalize_dir(dir, is_uri)

  if not util.isdirectory(dir) then
    api.nvim_err_writeln('brodir: fatal: buffer name is not a directory: '..dir)
    error('DEBUG')
    return
  elseif dir == '' then  -- normalize_dir() already showed error.
    error('DEBUG')
    return
  end

  local from_path = fnamemodify(buf_name(0), ':p')
  buf_render(get_buf(dir), dir, from_path)
end

local function setup_autocmds()
  local group = api.nvim_create_augroup('brodir', {})

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
      local path = luv.fs_realpath(buf_name(0)) or ''
      if vim.bo.filetype ~= 'brodir' and util.isdirectory(path) then
        M.open()
      end
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
  keymap('n', '<Plug>(brodir_up)'  , M.open_up)
  keymap('n', '<Plug>(brodir_quit)', [[<cmd>bdelete!<CR>]])
  keymap({'n', 'x'}, '<Plug>(brodir_K)', info)

  local function hl_link(hl, link)
    api.nvim_set_hl(0, hl, { link = link, default = true })
  end

  hl_link('BrodirSuffix'  , 'SpecialKey')
  hl_link('BrodirPathTail', 'Directory' )
  hl_link('BrodirArg'     , 'Todo'      )

  setup_autocmds()
end

M.setup()

return M
