
local M = {}

function M.isdirectory(d)
  local stat = vim.loop.fs_stat(d)
  return stat and stat.type == 'directory'
end

function M.trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end

return M
