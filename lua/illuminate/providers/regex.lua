local config = require "illuminate.config"
local util = require "illuminate.util"

local M = {}

local START_WORD_REGEX = vim.regex [[^\k*]]
local END_WORD_REGEX = vim.regex [[\k*$]]

-- foo
-- foo
-- Foo
-- fOo

---@param buf integer
---@param cursor illuminate.Pos
local function get_cur_word(buf, cursor)
  local line = vim.api.nvim_buf_get_lines(buf, cursor[1], cursor[1] + 1, false)[1]
  local left_part = line:sub(0, cursor[2] + 1)
  local right_part = line:sub(cursor[2] + 1)
  local start_idx, _ = END_WORD_REGEX:match_str(left_part)
  local _, end_idx = START_WORD_REGEX:match_str(right_part)
  local word = ("%s%s"):format(left_part:sub(start_idx + 1), right_part:sub(2, end_idx))
  local modifiers = [[\V]]
  if config.case_insensitive_regex() then modifiers = modifiers .. [[\c]] end
  local ok, escaped = pcall(vim.fn.escape, word, [[/\]])
  if ok then return modifiers .. [[\<]] .. escaped .. [[\>]] end
end

---@param buf integer
---@param cursor illuminate.Pos
function M.get_references(buf, cursor)
  local refs = {}
  local ok, re = pcall(vim.regex, get_cur_word(buf, cursor))
  if not ok then return refs end

  local line_count = vim.api.nvim_buf_line_count(buf)
  for i = 0, line_count - 1 do
    local start_byte, end_byte = 0, 0
    while true do
      local start_offset, end_offset = re:match_line(buf, i, end_byte)
      if not start_offset then break end

      start_byte = end_byte + start_offset
      end_byte = end_byte + end_offset
      table.insert(refs, {
        { i, start_byte },
        { i, end_byte },
        vim.lsp.protocol.DocumentHighlightKind.Text,
      })
    end
  end

  return refs
end

---@param buf integer
function M.is_ready(buf)
  local name = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.synID(vim.fn.line ".", vim.fn.col ".", 1)), "name")
  if util.is_allowed(config.provider_regex_syntax_allowlist(buf), config.provider_regex_syntax_denylist(buf), name) then
    return true
  end
  return false
end

return M
