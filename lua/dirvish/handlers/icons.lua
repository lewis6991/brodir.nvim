local api = vim.api

local ns = api.nvim_create_namespace('dirvish.handlers.icons')

local get_icon = require('nvim-web-devicons').get_icon

return function(buf, _, lines)
  for i, l in ipairs(lines) do
    local icon, icon_hl = get_icon(l, nil, {default=true})
    api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
      sign_text = icon,
      sign_hl_group = icon_hl
    })
  end
end
