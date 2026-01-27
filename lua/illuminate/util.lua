local M = {}

---@param win? integer
function M.get_cursor_pos(win)
  win = win or vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  cursor[1] = cursor[1] - 1 -- we always want line to be 0-indexed
  return cursor
end

---@param list unknown[]
function M.list_to_set(list)
  if list == nil then return nil end

  ---@type {[unknown]: true}
  local set = {}
  for _, v in pairs(list) do
    set[v] = true
  end
  return set
end

---@param allow_list unknown[]
---@param deny_list unknown[]
---@param thing unknown
function M.is_allowed(allow_list, deny_list, thing)
  if #allow_list == 0 and #deny_list == 0 then return true end

  if #deny_list > 0 then return not vim.tbl_contains(deny_list, thing) end

  return vim.tbl_contains(allow_list, thing)
end

function M.has_keymap(mode, lhs)
  return vim.fn.mapcheck(lhs, mode) ~= ""
end

return M
