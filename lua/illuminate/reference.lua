local M = {}

---@class illuminate.Pos
---@field [1] integer line (0-indexed)
---@field [2] integer col (0-indexed)

---@class illuminate.Ref
---@field [1] illuminate.Pos start pos
---@field [2] illuminate.Pos end pos
---@field [3] integer? LSP kind

---@type {[integer]: illuminate.Ref[]|nil}
local buf_references = {}

---@param buf integer
local function get_references(buf)
  return buf_references[buf] or {}
end

---@param pos1 illuminate.Pos
---@param pos2 illuminate.Pos
local function pos_before(pos1, pos2)
  if pos1[1] < pos2[1] then return true end
  if pos1[1] > pos2[1] then return false end
  if pos1[2] < pos2[2] then return true end
  return false
end

---@param pos1 illuminate.Pos
---@param pos2 illuminate.Pos
local function pos_equal(pos1, pos2)
  return pos1[1] == pos2[1] and pos1[2] == pos2[2]
end

---@param ref1 illuminate.Ref
---@param ref2 illuminate.Ref
local function ref_before(ref1, ref2)
  return pos_before(ref1[1], ref2[1]) or pos_equal(ref1[1], ref2[1]) and pos_before(ref1[2], ref2[2])
end

---@param buf integer
local function buf_sort_references(buf)
  local should_sort = false
  for i, ref in ipairs(get_references(buf)) do
    if i > 1 then
      if not ref_before(get_references(buf)[i - 1], ref) then
        should_sort = true
        break
      end
    end
  end

  if should_sort then table.sort(get_references(buf), ref_before) end
end

---@param pos illuminate.Pos
---@param ref illuminate.Ref
function M.is_pos_in_ref(pos, ref)
  return (pos_before(ref[1], pos) or pos_equal(ref[1], pos)) and (pos_before(pos, ref[2]) or pos_equal(pos, ref[2]))
end

---@param references illuminate.Ref[]
---@param pos illuminate.Pos
function M.bisect_left(references, pos)
  local l, r = 1, #references + 1
  while l < r do
    local m = l + math.floor((r - l) / 2)
    if pos_before(references[m][2], pos) then
      l = m + 1
    else
      r = m
    end
  end
  return l
end

---@param buf integer
function M.buf_get_references(buf)
  return get_references(buf)
end

---@param buf integer
---@param references illuminate.Ref[]
function M.buf_set_references(buf, references)
  buf_references[buf] = references
  buf_sort_references(buf)
end

---@param buf integer
---@param cursor_pos illuminate.Pos
function M.buf_cursor_in_references(buf, cursor_pos)
  if not get_references(buf) then return false end

  local i = M.bisect_left(get_references(buf), cursor_pos)

  if i > #get_references(buf) then return false end
  if not M.is_pos_in_ref(cursor_pos, get_references(buf)[i]) then return false end

  return true
end

return M
