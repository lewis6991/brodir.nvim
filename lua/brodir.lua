local fn, api, luv = vim.fn, vim.api, vim.loop

local util = require('brodir.util')

local ns = api.nvim_create_namespace('brodir')

local fnamemodify = fn.fnamemodify
local format = string.format

local buf_name = api.nvim_buf_get_name

-- Buffer to use for floats and new windows
local dbuf = api.nvim_create_buf(false, true)

local M = {}

local function get_stat(f)
  f = vim.trim(f)
  -- Slash decides how getftype() classifies directory symlinks. #138
  local noslash = fn.substitute(f, fn.escape('/','\\')..'$', '', 'g')

  local stat = luv.fs_stat(f)

  if not stat then
    local link = luv.fs_readlink(f)
    if link then
      return 'broken link -> '..link
    end
    return '?'
  end

  local size = stat.size
  if size > 0 then
    size = format('%.2f', size/1000)..'K'
  elseif size == 0 then
    size = fn.matchstr(fn.system{'du', '-hs', f}, '\\S\\+')
  end
  local ty = stat.type:sub(1, 1)
  local time = fn.strftime('%Y-%m-%d %H:%M', stat.mtime.sec)
  local link = 'link' ~= fn.getftype(noslash) and '' or ' -> '..fnamemodify(fn.resolve(f),':~:.')
  return format('%s %s %s %6s %s', ty, fn.getfperm(f), time, size, link)
end

function M.info()
  for i, f in ipairs(api.nvim_buf_get_lines(0, 0, -1, false)) do
    local id = api.nvim_buf_set_extmark(0, ns, i-1, 0, {
      id = i,
      virt_text = {{ get_stat(f) , 'Comment' }},
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

local function msg_error(msg)
  vim.notify(msg, vim.log.levels.ERROR, {title = 'brodir'})
end

local function normalize_dir(dir, silent)
  if not util.isdirectory(dir) then
    if not silent then
      error("invalid directory: '"..dir.."'")
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

  local lines   = vim.o.lines
  local columns = vim.o.columns
  local width   = math.ceil(columns * 0.3)
  local height  = math.ceil(lines * 0.8)
  local top     = ((lines - height) / 2) - 1

  local win = api.nvim_open_win(buf, true, {
    relative = 'editor',
    row      = top,
    col      = 10000,
    width    = width,
    height   = height,
    style    = 'minimal',
    border   = 'rounded'
  })

  -- Set the alternate buffer to itself
  fn.setreg('#', buf)

  return win
end

local function set_buf_options(buf)
  vim.bo[buf].filetype = 'brodir'
  vim.bo[buf].buftype  = 'nofile'
  vim.bo[buf].swapfile = false
  if buf ~= dbuf then
    vim.bo[buf].bufhidden = 'wipe'
  end
end

local function delete_alt(buf)
  local alt = api.nvim_buf_call(buf, function()
    return fn.bufnr('#')
  end)
  if alt ~= buf and alt ~= -1 then
    pcall(api.nvim_buf_delete, alt, {force=true})
  end
end

local function is_brodir(buf)
  return vim.bo[buf].filetype == 'brodir'
end

local function get_buf(dir)
  -- Prioritize current buffer
  if is_brodir(0) or buf_name(0) == '' or normalize_dir(buf_name(0), true) == dir then
    return api.nvim_get_current_buf()
  end

  return dbuf
end

local handlers = {
  'brodir.handlers.git',
  'brodir.handlers.open',
  'brodir.handlers.icons'
}

local function buf_render(dir, from_path)
  dir = normalize_dir(dir)

  local buf = get_buf(dir)
  api.nvim_buf_set_name(buf, dir)

  set_buf_options(buf)
  -- nvim_buf_set_name creates an alternate buffer with the name we are changing
  -- from. Delete it.
  delete_alt(buf)

  local win = get_or_create_win(buf)

  for name, v in pairs {
    cursorline     = true,
    number         = false,
    relativenumber = false,
    wrap           = false,
    concealcursor  = 'nvc',
    conceallevel   = 2
  } do
  api.nvim_set_option_value(name, v, { scope = 'local', win = win })
end

  local lines = list_dir(dir)
  if fn.win_gettype(win) == 'popup' then
    api.nvim_win_set_height(win, math.min(#lines, math.ceil(vim.o.lines * 0.8)))
  end

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

function M.open_up(splitcmd)
  local path = vim.fs.dirname(buf_name(0))
  M.open(path, splitcmd)
end

local function get_path()
  if vim.bo.filetype == 'brodir' then
    local line = api.nvim_win_get_cursor(0)[1]
    return api.nvim_buf_get_lines(0, line-1, line, false)[1]
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
    if luv.fs_stat(path) then
      if not util.isdirectory(path) then
        if vim.bo.filetype == 'brodir' and fn.win_gettype() == 'popup' then
          -- close the brodir float
          api.nvim_win_close(0, false)
        end
        -- Reduce the path since this will be used as the buffer name
        path = fnamemodify(path, ':.')
        print(splitcmd, path)
        vim.cmd[splitcmd]{ path, mods = { keepalt = true } }
        return
      end
    else
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
  buf_render(dir, from_path)
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

local function hl_link(hl, link)
  api.nvim_set_hl(0, hl, { link = link, default = true })
end

function M.setup()
  vim.keymap.set('n', '-', M.open, {silent=true})

  hl_link('BrodirSuffix'  , 'SpecialKey')
  hl_link('BrodirPathTail', 'Directory' )
  hl_link('BrodirArg'     , 'Todo'      )

  setup_autocmds()
end

return M
