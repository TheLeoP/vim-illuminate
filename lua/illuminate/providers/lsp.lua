local M = {}

local PREVIOUS_ID_INDEX = 1
local REFERENCES_INDEX = 3

---@type {[integer]: [integer, function, illuminate.Ref[]|nil]}
local bufs = {}

local function get_line_byte_from_position(buf, line, col, offset_encoding)
  if col == 0 then return col end

  local lines = vim.api.nvim_buf_get_lines(buf, line, line + 1, false)
  if not lines or #lines == 0 then return col end
  return vim.str_byteindex(lines[1], col, offset_encoding, true)
end

function M.get_references(buf)
  if not bufs[buf] or not bufs[buf][REFERENCES_INDEX] then return nil end

  return bufs[buf][REFERENCES_INDEX]
end

function M.is_ready(buf)
  return vim.iter(vim.lsp.get_clients { bufnr = buf }):any(
    ---@param client vim.lsp.Client
    function(client)
      return client:supports_method "textDocument/documentHighlight"
    end
  )
end

function M.initiate_request(buf, win)
  local id = 1
  if bufs[buf] then
    local prev_id, cancel_fn, references = unpack(bufs[buf])
    if references == nil then pcall(cancel_fn) end
    id = prev_id + 1
  end

  local params = function(client)
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end
  local cancel_fn = vim.lsp.buf_request_all(buf, "textDocument/documentHighlight", params, function(client_results)
    if bufs[buf][PREVIOUS_ID_INDEX] ~= id then return end
    if not vim.api.nvim_buf_is_valid(buf) then
      bufs[buf][REFERENCES_INDEX] = {}
      return
    end

    ---@type illuminate.Ref[]
    local references = {}
    for client_id, response in pairs(client_results) do
      local client = vim.lsp.get_client_by_id(client_id)
      if client and response.result then
        ---@cast response {result: lsp.DocumentHighlight[]}
        for _, res in ipairs(response.result) do
          local start_col =
            get_line_byte_from_position(buf, res.range.start.line, res.range.start.character, client.offset_encoding)
          local end_col =
            get_line_byte_from_position(buf, res.range["end"].line, res.range["end"].character, client.offset_encoding)
          table.insert(references, {
            { res.range.start.line, start_col },
            { res.range["end"].line, end_col },
            res.kind,
          })
        end
      end
    end

    bufs[buf][REFERENCES_INDEX] = references
  end)

  bufs[buf] = {
    id,
    cancel_fn,
  }
end

return M
