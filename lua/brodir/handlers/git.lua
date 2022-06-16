local fn, api = vim.fn, vim.api

local util = require('brodir.util')

local ns = api.nvim_create_namespace('brodir.handlers.git')

local function git_status(dir)
  local toplevel = fn.systemlist{'git', '-C', dir, 'rev-parse', '--show-toplevel'}[1]

  if not util.isdirectory(toplevel) then
    return
  end

  local entries = fn.systemlist{'git', '-C', dir, 'status', '.', '--porcelain'}

  local ret = {}
  for _, entry in ipairs(entries) do
    if #entry > 4 then
      local s = entry:sub(2, 2)
      local name = entry:sub(4)
      ret[toplevel..'/'..name] = s
    end
  end

  return ret
end

local GITSTATUS_HL = {
  M = 'Directory',
  A = 'Question',
  D = 'ErrorMsg',
}

return function(buf, dir, lines)
  local status = git_status(dir)

  if not status then
    return
  end

  for i, l in ipairs(lines) do
    local s = status[l]
    if not s then
      for n, _ in pairs(status) do
        if vim.startswith(n, l) then
          s = 'M'
          break
        end
      end
    end

    if s then
      local icon = util.isdirectory(l) and '○' or '●'
      api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
        virt_text = {{icon, GITSTATUS_HL[s] or 'Error'}},
      })
    end
  end
end
