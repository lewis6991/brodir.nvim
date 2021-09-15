local fn, api = vim.fn, vim.api

local M = {}

local srcdir = fn.expand('<sfile>:h:h:p')

local fnamemodify = fn.fnamemodify

local function getline(n)
  return api.nvim_buf_get_lines(0, n, n+1, false)[1]
end

local function getlines(n, m)
  return api.nvim_buf_get_lines(0, n, m, false)
end

local function isdirectory(d)
  return fn.isdirectory(d) == 1
end

local function restore_winlocal_settings()
  local ok, wdirvish = pcall(api.nvim_win_get_var, 0, 'dirvish')
  if not ok then
    -- can happen during VimLeave, etc.
    return
  end
  if wdirvish._w_cocu then
    api.nvim_win_set_option(0, 'concealcursor', wdirvish._w_cocu)
    api.nvim_win_set_option(0, 'conceallevel', wdirvish._w_cole)
  end
end

function M.on_bufunload()
  restore_winlocal_settings()
end

local function win_init()
  vim.w.dirvish = vim.tbl_extend('keep', vim.w.dirvish or {}, vim.b.dirvish)
  vim.wo.cursorline    = true
  vim.wo.wrap          = false
  vim.wo.concealcursor = 'nvc'
  vim.wo.conceallevel  = 2
end

function M.info(paths, dirsize)
  for _, f in ipairs(paths) do
    -- Slash decides how getftype() classifies directory symlinks. #138
    local noslash = fn.substitute(f, fn.escape('/','\\')..'$', '', 'g')
    local fname = #paths < 2 and '' or string.format('%12.12s ', fnamemodify(f:gsub('[\\/]+$', ''), ':t'))

    local size
    if fn.getfsize(f) ~= -1 and dirsize == 1 then
      size = fn.matchstr(fn.system('du -hs '..fn.shellescape(f)), '\\S\\+')
    else
      size = string.format('%.2f', fn.getfsize(f)/1000)..'K'
    end
    if fn.getfsize(f) == -1 then
      print('?')
    else
      local ty = fn.getftype(noslash):sub(1, 1)
      local time = fn.strftime('%Y-%m-%d.%H:%M:%S', fn.getftime(f))
      print(
        string.format('%s%s %s %s %s', fname, ty, fn.getfperm(f), time, size)
        ..('link'~= fn.getftype(noslash) and '' or ' -> '..fnamemodify(fn.resolve(f),':~:.'))
      )
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

local function parent_dir(dir)
  local mod = isdirectory(dir) and ':p:h:h' or ':p:h'
  return normalize_dir(fnamemodify(dir, mod), false)
end

local function suf()
  local m = vim.g.dirvish_mode or 1
  return type(m) == 'number' and m <= 1
end

local function globlist(dir_esc, pat)
  return fn.globpath(dir_esc, pat, not suf(), 1)
end

-- Returns true if the buffer was modified by the user.
function M.buf_modified()
  if vim.b.dirvish and vim.b.dirvish._c and vim.b.changedtick > vim.b.dirvish._c then
    return true
  else
    return false
  end
end

function M.on_bufenter()
  if api.nvim_buf_get_name(0) == '' then -- Something is very wrong. #136
    return
  elseif not vim.b.dirvish or (fn.empty(getline(0)) and 1 == fn.line('$')) then
    vim.cmd[[Dirvish %]]
  elseif vim.wo.conceallevel ~= 3 and not M.buf_modified() then
    win_init()
  else
    -- Ensure w:dirvish for window splits, `:b <nr>`, etc.
    vim.w.dirvish = vim.tbl_extend('keep', vim.w.dirvish or {}, vim.b.dirvish)
  end
end

function M.save_state(d)
  -- Remember previous ('original') buffer.
  d.prevbuf = (api.nvim_buf_is_valid(0) or not vim.w.dirvish) and fn.bufnr('%') or vim.w.dirvish.prevbuf
  if not api.nvim_buf_is_valid(d.prevbuf) then
    -- If reached via :edit/:buffer/etc. we cannot get the (former) altbuf.
    d.prevbuf = (vim.b.dirvish and api.nvim_buf_is_valid(vim.b.dirvish.prevbuf)) and vim.b.dirvish.prevbuf or fn.bufnr('#')
  end

  -- Remember alternate buffer.
  d.altbuf = (api.nvim_buf_is_valid(fn.bufnr('#')) or not vim.w.dirvish) and fn.bufnr('#') or vim.w.dirvish.altbuf
  if vim.b.dirvish and ((d.altbuf == d.prevbuf) or not api.nvim_buf_is_valid(d.altbuf)) then
    d.altbuf = vim.b.dirvish.altbuf
  end

  -- Save window-local settings.
  vim.w.dirvish = vim.tbl_extend('force', vim.w.dirvish or {}, d)
  vim.w.dirvish._w_wrap, vim.w.dirvish._w_cul = vim.wo.wrap, vim.wo.cul
  if not vim.b.dirvish then
    vim.w.dirvish._w_cocu, vim.w.dirvish._w_cole = vim.w.concealcursor, vim.w.conceallevel
  end

  return d
end

local function is_valid_altbuf(bnr)
  return bnr ~= api.nvim_get_current_buf()
    and fn.bufexists(bnr) == 1
    and vim.tbl_isempty(api.nvim_buf_get_var(bnr, 'dirvish') or {})
end

local function try_visit(bnr, noau)
  if is_valid_altbuf(bnr) then
    -- If _previous_ buffer is _not_ loaded (because of 'nohidden'), we must
    -- allow autocmds (else no syntax highlighting; #13).
    noau = (noau and api.nvim_buf_is_loaded(bnr)) and 'noau' or ''
    vim.cmd(string.format('silent keepjumps %s noswapfile buffer %d', noau, bnr))
    return 1
    end
  return 0
end

function M.buf_close()
  local d = vim.w.dirvish or {}
  if vim.tbl_isempty(d) then
    return
  end

  local altbuf, prevbuf = d.altbuf or 0, d.prevbuf or 0
  local found_alt = try_visit(altbuf, 1)
  if not try_visit(prevbuf, 0)
    and not found_alt
      and (1 == fn.bufnr('%') or (prevbuf ~= fn.bufnr('%') and altbuf ~= fn.bufnr('%'))) then
    vim.cmd[[bdelete]]
  end
end

local function list_dir(dir)
  -- Escape for globpath().
  local dir_esc = fn.escape(fn.substitute(dir,'\\[','[[]','g'), ',;*?{}^$\\')
  local paths = globlist(dir_esc, '*')
  -- Append dot-prefixed files. globpath() cannot do both in 1 pass.
  paths = vim.list_extend(paths, globlist(dir_esc, '.[^.]*'))

  if vim.g.dirvish_relative_paths and dir ~= parent_dir(fn.getcwd()) then -- avoid blank CWD
    return vim.tbl_map(function(v) return fnamemodify(v, ':p:.') end, paths)
  else
    return vim.tbl_map(function(v) return fnamemodify(v, ':p') end, paths)
  end
end

local function set_altbuf(bnr)
  if not is_valid_altbuf(bnr) then return end

  vim.cmd('let @# = '..bnr)

  local curbuf = api.nvim_get_current_buf()
  if try_visit(bnr, 1) then
    local noau = fn.bufloaded(curbuf) and 'noau' or ''
    -- Return to the current buffer.
    vim.cmd(string.format('silent keepjumps %s noswapfile buffer %d', noau, curbuf))
  end
end

local function should_reload()
  return not M.buf_modified() or (getline(0) == '' and fn.line('$') == 1)
end

-- Performs `cmd` in all windows showing `bname`.
local function bufwin_do(cmd, bname)
  vim.tbl_map(
    function(v)
      return fn.win_execute(v.winid, 'silent noautocmd keepjumps '..cmd)
    end,
    vim.tbl_filter(
      function(v)
        return bname == api.nvim_buf_get_name(v.bufnr)
      end,
      fn.getwininfo()
    )
  )
end

function M.set_args(...)
  local args = {...}
  if fn.arglistid() == 0 then
    vim.cmd'arglocal'
  end

  local normalized_args = vim.tbl_map(function(v) return fnamemodify(v, ":p") end, args)

  for f in ipairs(args) do
    local i = fn.index(normalized_args, f)
    if i == -1 then
      vim.cmd( '$argadd '..fn.fnameescape(fnamemodify(f, ':p')))
    elseif 1 == #args then
      vim.cmd( (i+1)..'argdelete')
      vim.cmd'syntax clear DirvishArg'
    end
  end
  print('arglist: '..#args..' files')

  -- Define (again) DirvishArg syntax group.
  vim.cmd('source '..fn.fnameescape(srcdir..'/syntax/dirvish.vim'))
end

function M.buf_render(dir, lastpath)
  local bname = fn.bufname('%')
  local isnew = getline(0) == ''

  if not isdirectory(bname) then
    api.nvim_err_writeln('dirvish: fatal: buffer name is not a directory: '..fn.bufname('%'))
    return
  end

  if not isnew then
    bufwin_do('let w:dirvish["_view"] = winsaveview()', bname)
  end

  local ul = vim.bo.undolevels
  vim.bo.undolevels = -1

  vim.cmd'silent keepmarks keepjumps %delete _'
  api.nvim_buf_set_lines(0, 0, -1, false, list_dir(dir))

  if type(vim.g.dirvish_mode) == 'string' then -- Apply user's filter.
    vim.cmd(vim.g.dirvish_mode)
  end

  vim.bo.undolevels = ul

  if not isnew then
    bufwin_do('call winrestview(w:dirvish["_view"])', bname)
  end

  if lastpath == '' then
    local pat = vim.g.dirvish_relative_paths and fnamemodify(lastpath, ':p:.') or lastpath
    pat = pat == '' and lastpath or pat  -- no longer in CWD
    fn.search('\\V\\^'..fn.escape(pat, '\\')..'\\$', 'cw')
  end
  -- Place cursor on the tail (last path segment).
  fn.search('\\/\\zs[^\\/]\\+\\/\\?$', 'c', fn.line('.'))
end

local function open_selected(splitcmd, bg, line1, line2)
  if type(bg) == 'number' then
    bg = bg == 1
  end

  local curbuf = api.nvim_get_current_buf()
  local curtab = api.nvim_get_current_tabpage()
  local wincount = fn.winnr('$')
  local curwin = api.nvim_get_current_win()
  local p = splitcmd == 'p'  -- Preview-mode

  local paths = fn.getline(line1, line2)
  for _, path in ipairs(paths) do
    if not isdirectory(path) and fn.filereadable(path) == 0 then
      msg_error("invalid (access denied?): "..path)
    else
      if p then -- Go to previous window.
        if fn.winnr('$') > 1 then
          local cur_win = api.nvim_win_get_number(0)
          vim.cmd('wincmd p')
          if fn.winnr() == cur_win then
            vim.cmd('wincmd w')
          end
        else
          vim.cmd('vsplit')
        end
      end

      if isdirectory(path) then
        vim.cmd(((p or splitcmd == 'edit') and '' or splitcmd..'|')..' Dirvish '..fn.fnameescape(path))
      else
        vim.cmd((p and 'edit' or splitcmd)..' '..fn.fnameescape(path))
      end

      -- Return to previous window after _each_ split, else we get lost.
      if bg and (p or (vim.startswith(splitcmd, 'sp') and fn.winnr('$') > wincount)) then
        vim.cmd'wincmd p'
      end
    end
  end

  if bg then -- return to dirvish buffer
    if splitcmd == 'tabedit' then
      vim.cmd('tabnext '..curtab..' | '..curwin..' wincmd w')
    elseif splitcmd == 'edit' then
      vim.cmd( 'silent keepalt keepjumps buffer '.. curbuf)
    end
  elseif vim.b.dirvish and vim.w.dirvish then
    set_altbuf(vim.w.dirvish.prevbuf)
  end
end

local function buf_init()
  vim.cmd[[
  augroup dirvish_buflocal
    autocmd! * <buffer>
    autocmd BufEnter,WinEnter <buffer> lua package.loaded.dirvish.on_bufenter()
    autocmd TextChanged,TextChangedI <buffer> if v:lua.package.loaded.dirvish.buf_modified() | setlocal conceallevel=0 | endif
  augroup END
  ]]

  -- BufUnload is fired for :bwipeout/:bdelete/:bunload, _even_ if
  -- 'nobuflisted'. BufDelete is _not_ fired if 'nobuflisted'.
  -- NOTE: For 'nohidden' we cannot reliably handle :bdelete like this.
  if vim.o.hidden then
    vim.cmd[[autocmd dirvish_buflocal BufUnload <buffer> lua package.loaded.dirvish.on_bufunload()]]
  end

  vim.bo.buftype = 'nofile'
  vim.bo.swapfile = false
end

function M.open_dir(d, reload)
  if type(reload) == 'number' then
    reload = reload == 1
  end

  -- Vim tends to 'simplify' buffer names. Examples (gvim 7.4.618):
  --     ~\foo\, ~\foo, foo\, foo
  -- Try to find an existing buffer before creating a new one.
  local bnr = -1
  for _, pat in ipairs{'', ':~:.', ':~'} do
    local dir = fnamemodify(d._dir, pat)
    if dir ~= '' then
      bnr = fn.bufnr('^'..dir..'$')
      if bnr ~= -1 then
        break
      end
    end
  end

  if bnr == -1 then
    vim.cmd('silent noswapfile keepalt edit '..fn.fnameescape(d._dir))
  else
    vim.cmd('silent noswapfile buffer '..bnr)
  end

  -- Use :file to force a normalized path.
  -- - Avoids ".././..", ".", "./", etc. (breaks %:p, not updated on :cd).
  -- - Avoids [Scratch] in some cases (":e ~/" on Windows).
  if fn.bufname('%') ~= d._dir then
    vim.cmd('silent noswapfile file '..fn.fnameescape(d._dir))
  end

  if not isdirectory(fn.bufname('%')) then -- sanity check
    error('invalid directory: '..fn.bufname('%'))
  end

  if vim.bo.buflisted and fn.bufnr('$') > 1 then
    vim.bo.buflisted = false
  end

  set_altbuf(d.prevbuf) -- in case of :bd, :read#, etc.

  vim.b.dirvish = vim.tbl_extend('force', vim.b.dirvish or {}, d)

  buf_init()
  win_init()

  if reload or should_reload() then
    M.buf_render(vim.b.dirvish._dir, vim.b.dirvish.lastpath or '')
    -- Set up Dirvish before any other `FileType dirvish` handler.
    vim.cmd('source '..fn.fnameescape(srcdir..'/ftplugin/dirvish.vim'))
    local curwin = api.nvim_win_get_number(0)
    vim.bo.filetype = 'dirvish'

    if curwin ~= api.nvim_win_get_number(0) then
      error('FileType autocmd changed the window')
    end
    vim.b.dirvish._c = vim.b.changedtick
  end
end

function M.open(firstline, lastline, args)
  if vim.o.autochdir then
    msg_error("'autochdir' is not supported")
    return
  end

  if not vim.o.autowriteall
    and not vim.o.hidden
    and vim.bo.modified
    and (#(fn.win_findbuf(api.nvim_win_get_buf(0))) == 1) then
    msg_error("E37: No write since last change")
    return
  end

  if #args > 1 then
    open_selected(args[1], args[2], firstline, lastline)
    return
  end

  local d = {}
  local is_uri    = fn.match(args[1], '^\\w\\+:[\\/][\\/]') ~= -1
  local from_path = api.nvim_buf_get_name(0)
  local to_path   = fnamemodify(args[1], ':p') -- resolves to CWD if a:1 is empty

  d._dir = fn.filereadable(to_path) == 1 and fnamemodify(to_path, ':p:h') or to_path
  d._dir = normalize_dir(d._dir, is_uri)
  -- Fallback to CWD for URIs. #127
  if d._dir == '' and is_uri then
    d._dir = normalize_dir(fn.getcwd(), is_uri)
  end

  if d._dir == '' then  -- s:normalize_dir() already showed error.
    return
  end

  local reloading = vim.b.dirvish and d._dir == vim.b.dirvish._dir

  if reloading then
    d.lastpath = ''         -- Do not place cursor when reloading.
  elseif not is_uri and d._dir == parent_dir(from_path) then
    d.lastpath = from_path  -- Save lastpath when navigating _up_.
  end

  M.save_state(d)
  M.open_dir(d, reloading)
end

function M.setup()
  local function keymap(mode, l, r)
    api.nvim_set_keymap(mode, l, r, {noremap=true, silent=true})
  end

  keymap('n', '<Plug>(dirvish_quit)' , [[<cmd>lua package.loaded.dirvishbuf_close()<CR>]])
  keymap('n', '<Plug>(dirvish_quit)' , [[<cmd>lua package.loaded.dirvishbuf_close()<CR>]])
  keymap('n', '<Plug>(dirvish_arg)'  , [[<cmd>lua package.loaded.dirvish.set_args({vim.fn.getline('.')})<CR>]])
  keymap('x', '<Plug>(dirvish_arg)'  , [[<cmd>lua package.loaded.dirvish.set_args(vim.fn.getline("'<", "'>"))<CR>]])
  keymap('n', '<Plug>(dirvish_K)'    , [[<cmd>lua package.loaded.dirvish.info({vim.fn.getline('.')},vim.v.count)<CR>]])
  keymap('x', '<Plug>(dirvish_K)'    , [[<cmd>lua package.loaded.dirvish.info(vim.fn.getline("'<", "'>"),vim.v.count)<CR>]])
end

M.setup()

return M
