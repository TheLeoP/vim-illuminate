local hl = require "illuminate.highlight"
local ref = require "illuminate.reference"
local config = require "illuminate.config"
local util = require "illuminate.util"

local M = {}

local AUGROUP = "vim_illuminate_v2_augroup"
---@type uv.uv_timer_t[]
local timers = {}
---@type {[integer]: true}
local paused_bufs = {}
---@type {[integer]: true}
local stopped_bufs = {}
local is_paused = false
---@type {[integer]: true}
local written = {}
local error_timestamps = {}
---@type {[integer]: boolean}
local frozen_bufs = {}
---@type {[integer]: boolean}
local invisible_bufs = {}
local started = false

---@param buf integer
local function buf_should_illuminate(buf)
  if is_paused or paused_bufs[buf] or stopped_bufs[buf] then return false end

  return config.should_enable()(buf)
    and (config.max_file_lines() == nil or vim.fn.line "$" <= config.max_file_lines())
    and util.is_allowed(config.modes_allowlist(buf), config.modes_denylist(buf), vim.api.nvim_get_mode().mode)
    and util.is_allowed(config.filetypes_allowlist(), config.filetypes_denylist(), vim.bo[buf].filetype)
end

local function stop_timer(timer)
  if vim.uv.is_active(timer) then
    vim.uv.timer_stop(timer)
    vim.uv.close(timer)
  end
end

function M.start()
  started = true
  vim.api.nvim_create_augroup(AUGROUP, { clear = true })
  vim.api.nvim_create_autocmd({ "VimEnter", "CursorMoved", "CursorMovedI", "ModeChanged", "TextChanged" }, {
    group = AUGROUP,
    callback = function()
      M.refresh_references()
    end,
  })

  -- Set up auto-attach/detach for the treesitter provider if we can use builtin methods instead of
  -- treesitter modules.
  if vim.fn.has "nvim-0.9" == 1 then
    vim.api.nvim_create_autocmd({ "FileType" }, {
      callback = function(details)
        require("illuminate.providers.treesitter").detach(details.buf)

        local lang = vim.treesitter.language.get_lang(details.match)
        local ok, query = pcall(require, "nvim-treesitter.query")
        if not ok then return end

        local parsers
        ok, parsers = pcall(require, "nvim-treesitter.parsers")
        if not ok then return end

        if not parsers.has_parser(lang) then return false end

        if not lang or not query.has_locals(lang) then return end

        require("illuminate.providers.treesitter").attach(details.buf)
      end,
    })
    vim.api.nvim_create_autocmd({ "BufUnload" }, {
      callback = function(details)
        require("illuminate.providers.treesitter").detach(details.buf)
      end,
    })
  end

  -- If vim.lsp.buf.format is called, this will call vim.api.nvim_buf_set_text which messes up extmarks.
  -- By using this `written` variable, we can ensure refresh_references doesn't terminate early based on
  -- ref.buf_cursor_in_references being incorrect (we have references but they're not actually showing
  -- as illuminated). vim.lsp.buf.format will trigger CursorMoved so we don't need to do it here.
  vim.api.nvim_create_autocmd({ "BufWritePost" }, {
    group = AUGROUP,
    callback = function()
      written[vim.api.nvim_get_current_buf()] = true
    end,
  })
  vim.api.nvim_create_autocmd({ "VimLeave" }, {
    group = AUGROUP,
    callback = function()
      for _, timer in pairs(timers) do
        stop_timer(timer)
      end
    end,
  })
end

function M.stop()
  started = false
  vim.api.nvim_create_augroup(AUGROUP, { clear = true })
end

---Get the highlighted references for the item under the cursor for
---`buf` and clears any old reference highlights
---
---@param buf? number
---@param win? number
function M.refresh_references(buf, win)
  buf = buf or vim.api.nvim_get_current_buf()
  win = win or vim.api.nvim_get_current_win()

  if frozen_bufs[buf] then return end

  if not buf_should_illuminate(buf) then
    hl.buf_clear_references(buf)
    ref.buf_set_references(buf, {})
    return
  end

  -- We might want to optimize here by returning early if cursor is in references.
  -- The downside is that LSP servers can sometimes return a different list of references
  -- as you move around an existing reference (like return statements).
  if written[buf] or not ref.buf_cursor_in_references(buf, util.get_cursor_pos(win)) then
    hl.buf_clear_references(buf)
    ref.buf_set_references(buf, {})
  elseif config.large_file_cutoff() ~= nil and vim.fn.line "$" > config.large_file_cutoff() then
    return
  end
  written[buf] = nil

  if timers[buf] then stop_timer(timers[buf]) end

  local provider = M.get_provider(buf)
  if not provider then return end
  pcall(provider["initiate_request"], buf, win)

  local changedtick = vim.api.nvim_buf_get_changedtick(buf)

  local timer = assert(vim.uv.new_timer())
  timers[buf] = timer
  timer:start(
    config.delay(buf),
    17,
    vim.schedule_wrap(function()
      local ok, err = pcall(function()
        if not buf or not vim.api.nvim_buf_is_loaded(buf) then
          stop_timer(timer)
          return
        end

        hl.buf_clear_references(buf)
        ref.buf_set_references(buf, {})

        if not buf_should_illuminate(buf) then
          stop_timer(timer)
          return
        end

        if
          vim.api.nvim_buf_get_changedtick(buf) ~= changedtick
          or vim.api.nvim_get_current_win() ~= win
          or buf ~= vim.api.nvim_win_get_buf(0)
        then
          stop_timer(timer)
          return
        end

        provider = M.get_provider(buf)
        if not provider then
          stop_timer(timer)
          return
        end

        local references = provider.get_references(buf, util.get_cursor_pos(win))
        if references ~= nil then
          ref.buf_set_references(buf, references)
          if ref.buf_cursor_in_references(buf, util.get_cursor_pos(win)) then
            if not invisible_bufs[buf] == true then hl.buf_highlight_references(buf, ref.buf_get_references(buf)) end
          else
            ref.buf_set_references(buf, {})
          end
          stop_timer(timer)
        end
      end)

      if not ok then
        local time = vim.uv.hrtime()
        if #error_timestamps == 5 then
          vim.notify(
            "vim-illuminate: An internal error has occured: " .. vim.inspect(ok) .. vim.inspect(err),
            vim.log.levels.ERROR,
            {}
          )
          M.stop()
          stop_timer(timer)
        elseif #error_timestamps == 0 or time - error_timestamps[#error_timestamps] < 500000000 then
          table.insert(error_timestamps, time)
        else
          error_timestamps = { time }
        end
      end
    end)
  )
end

---@param buf integer
function M.get_provider(buf)
  for _, provider in ipairs(config.providers(buf) or {}) do
    local ok, providerModule = pcall(require, string.format("illuminate.providers.%s", provider))
    if ok and providerModule.is_ready(buf) then return providerModule, provider end
  end
  return nil
end

function M.pause()
  is_paused = true
  M.refresh_references()
end

function M.resume()
  is_paused = false
  M.refresh_references()
end

function M.toggle()
  is_paused = not is_paused
  M.refresh_references()
end

---@param buf? integer
function M.toggle_buf(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if paused_bufs[buf] then
    paused_bufs[buf] = nil
  else
    paused_bufs[buf] = true
  end
  M.refresh_references()
end

---@param buf? integer
function M.pause_buf(buf)
  paused_bufs[buf or vim.api.nvim_get_current_buf()] = true
  M.refresh_references()
end

---@param buf? integer
function M.resume_buf(buf)
  paused_bufs[buf or vim.api.nvim_get_current_buf()] = nil
  M.refresh_references()
end

---@param buf? integer
function M.stop_buf(buf)
  stopped_bufs[buf or vim.api.nvim_get_current_buf()] = true
  M.refresh_references()
end

---@param buf? integer
function M.freeze_buf(buf)
  frozen_bufs[buf or vim.api.nvim_get_current_buf()] = true
end

---@param buf? integer
function M.unfreeze_buf(buf)
  frozen_bufs[buf or vim.api.nvim_get_current_buf()] = nil
end

---@param buf? integer
function M.toggle_freeze_buf(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  frozen_bufs[buf] = not frozen_bufs[buf]
end

---@param buf? integer
function M.invisible_buf(buf)
  invisible_bufs[buf or vim.api.nvim_get_current_buf()] = true
  M.refresh_references()
end

---@param buf? integer
function M.visible_buf(buf)
  invisible_bufs[buf or vim.api.nvim_get_current_buf()] = nil
  M.refresh_references()
end

---@param buf? integer
function M.toggle_visibility_buf(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  invisible_bufs[buf] = not invisible_bufs[buf]
  M.refresh_references()
end

function M.debug()
  local buf = vim.api.nvim_get_current_buf()
  print("buf_should_illuminate", buf, buf_should_illuminate(buf))
  print("config", vim.inspect(config.get_raw()))
  print("started", started)
  print("provider", M.get_provider(buf))
  print("`termguicolors`", vim.opt.termguicolors:get())
end

function M.is_paused()
  return is_paused
end

return M
