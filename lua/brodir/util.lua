
local M = {}

function M.isdirectory(d)
  local stat = vim.loop.fs_stat(d)
  return stat and stat.type == 'directory'
end

return M
