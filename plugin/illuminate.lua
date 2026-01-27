if _G.loaded_illuminate then return end
_G.loaded_illuminate = true

require("illuminate.engine").start()
vim.api.nvim_create_user_command("IlluminatePause", require("illuminate").pause, { bang = true })
vim.api.nvim_create_user_command("IlluminateResume", require("illuminate").resume, { bang = true })
vim.api.nvim_create_user_command("IlluminateToggle", require("illuminate").toggle, { bang = true })
vim.api.nvim_create_user_command("IlluminatePauseBuf", require("illuminate").pause_buf, { bang = true })
vim.api.nvim_create_user_command("IlluminateResumeBuf", require("illuminate").resume_buf, { bang = true })
vim.api.nvim_create_user_command("IlluminateToggleBuf", require("illuminate").toggle_buf, { bang = true })
vim.api.nvim_create_user_command("IlluminateDebug", require("illuminate").debug, { bang = true })

if not require("illuminate.config").disable_keymaps() then
  if not require("illuminate.util").has_keymap("n", "<a-n>") then
    vim.keymap.set("n", "<a-n>", require("illuminate").goto_next_reference, { desc = "Move to next reference" })
  end
  if not require("illuminate.util").has_keymap("n", "<a-p>") then
    vim.keymap.set("n", "<a-p>", require("illuminate").goto_prev_reference, { desc = "Move to previous reference" })
  end
  if not require("illuminate.util").has_keymap("o", "<a-i>") then
    vim.keymap.set("o", "<a-i>", require("illuminate").textobj_select)
  end
  if not require("illuminate.util").has_keymap("x", "<a-i>") then
    vim.keymap.set("x", "<a-i>", require("illuminate").textobj_select)
  end
end

require("illuminate").set_highlight_defaults()

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("vim_illuminate_autocmds", { clear = true }),
  callback = function()
    require("illuminate").set_highlight_defaults()
  end,
})
