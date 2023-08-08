
local M = {}

--- @param d string
--- @return boolean
function M.isdirectory(d)
  local stat = vim.loop.fs_stat(d)
  return stat ~= nil and stat.type == 'directory'
end

return M
