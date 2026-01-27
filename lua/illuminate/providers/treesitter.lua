local M = {}

---@type {[integer]: true}
local buf_attached = {}

---@param buf integer
function M.get_references(buf)
  local ok, locals = pcall(require, "nvim-treesitter.locals")
  if not ok then return end

  local node_at_point = vim.treesitter.get_node()
  if not node_at_point then return end

  local refs = {}
  local def_node, scope, kind = locals.find_definition(node_at_point, buf)
  local usages = locals.find_usages(def_node, scope, buf)
  for _, node in ipairs(usages) do
    if kind ~= nil and node == def_node then
      local range = { def_node:range() }
      table.insert(refs, {
        { range[1], range[2] },
        { range[3], range[4] },
        vim.lsp.protocol.DocumentHighlightKind.Write,
      })
    else
      local range = { node:range() }
      table.insert(refs, {
        { range[1], range[2] },
        { range[3], range[4] },
        vim.lsp.protocol.DocumentHighlightKind.Read,
      })
    end
  end

  return refs
end

function M.is_ready(buf)
  return buf_attached[buf] and vim.bo[buf].filetype ~= "yaml"
end

function M.attach(buf)
  buf_attached[buf] = true
end

function M.detach(buf)
  buf_attached[buf] = nil
end

return M
