local api = vim.api

vim.keymap.set('n', '-', function()
  require("brodir").open()
end, {silent=true})

local function hl_link(hl, link)
  api.nvim_set_hl(0, hl, { link = link, default = true })
end

hl_link('BrodirSuffix'  , 'SpecialKey')
hl_link('BrodirPathTail', 'Directory' )
hl_link('BrodirArg'     , 'Todo'      )

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
    local path = vim.uv.fs_realpath(api.nvim_buf_get_name(0)) or ''
    local util = require('brodir.util')
    if vim.bo.filetype ~= 'brodir' and util.isdirectory(path) then
      require('brodir').open()
    end
  end
})
