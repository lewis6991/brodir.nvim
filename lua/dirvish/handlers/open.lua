local api = vim.api

local ns = api.nvim_create_namespace('dirvish.handlers.open')

return function(buf, _, lines)
  local bufs = {}
  for _, b in ipairs(api.nvim_list_bufs()) do
    local name = api.nvim_buf_get_name(b)
    bufs[name] = b
  end

  for i, l in ipairs(lines) do
    if bufs[l] then
      api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
        hl_group = 'DirvishOpenBuf',
        -- Add the buffer number next
        virt_text = {{tostring(bufs[l]), 'NonText'}},
        end_col = #l
      })
    end
  end
end
