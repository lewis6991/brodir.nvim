local api = vim.api

local ns = api.nvim_create_namespace('brodir.handlers.icons')

local ok, devicons = pcall(require, 'nvim-web-devicons')

return function(buf, _, lines)
  if not ok then
    return
  end
  for i, l in ipairs(lines) do
    local icon, icon_hl = devicons.get_icon(l, nil, {default=true})
    api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
      sign_text = icon,
      sign_hl_group = icon_hl
    })
  end
end
