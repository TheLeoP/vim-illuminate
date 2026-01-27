local M = {}

local references = {}

function M.get_document_highlights(bufnr)
  return references[bufnr]
end

function M.configure(config)
  require("illuminate.config").set(config)
end

function M.pause()
  require("illuminate.engine").pause()
end

function M.resume()
  require("illuminate.engine").resume()
end

function M.toggle()
  require("illuminate.engine").toggle()
end

function M.toggle_buf()
  require("illuminate.engine").toggle_buf()
end

function M.pause_buf()
  require("illuminate.engine").pause_buf()
end

function M.stop_buf()
  require("illuminate.engine").stop_buf()
end

function M.resume_buf()
  require("illuminate.engine").resume_buf()
end

function M.freeze_buf()
  require("illuminate.engine").freeze_buf()
end

function M.unfreeze_buf()
  require("illuminate.engine").unfreeze_buf()
end

function M.toggle_freeze_buf()
  require("illuminate.engine").toggle_freeze_buf()
end

function M.invisible_buf()
  require("illuminate.engine").invisible_buf()
end

function M.visible_buf()
  require("illuminate.engine").visible_buf()
end

function M.toggle_visibility_buf()
  require("illuminate.engine").toggle_visibility_buf()
end

function M.goto_next_reference(wrap)
  if wrap == nil then wrap = vim.o.wrapscan end
  require("illuminate.goto").goto_next_reference(wrap)
end

function M.goto_prev_reference(wrap)
  if wrap == nil then wrap = vim.o.wrapscan end
  require("illuminate.goto").goto_prev_reference(wrap)
end

function M.textobj_select()
  require("illuminate.textobj").select()
end

function M.debug()
  require("illuminate.engine").debug()
end

function M.is_paused()
  return require("illuminate.engine").is_paused()
end

function M.set_highlight_defaults()
  vim.cmd [[
    hi def IlluminatedWordText guifg=none guibg=none gui=underline
    hi def IlluminatedWordRead guifg=none guibg=none gui=underline
    hi def IlluminatedWordWrite guifg=none guibg=none gui=underline
    ]]
end

return M
