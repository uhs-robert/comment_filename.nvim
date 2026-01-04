-- lua/comment_filename/init.lua
local Config = require("comment_filename.config")
local Save = require("comment_filename.save_filename_as_comment")

local M = {}
local state = { enabled = true }

function M.setup(opts)
  local cfg = Config.merge(opts)
  state.enabled = cfg.enabled

  vim.schedule(function()
    Save.create_autocmds(cfg, state)
  end)

  vim.api.nvim_create_user_command("CommentFilenameToggle", function()
    state.enabled = not state.enabled
    vim.notify("Comment Filename on Save (global): " .. (state.enabled and "ON" or "OFF"))
  end, {})

  vim.api.nvim_create_user_command("CommentFilenameBufferToggle", function()
    vim.b.comment_filename_disabled = not vim.b.comment_filename_disabled
    vim.notify("Comment Filename on Save (buffer): " .. (vim.b.comment_filename_disabled and "OFF" or "ON"))
  end, {})
end

function M.enable()
  state.enabled = true
end
function M.disable()
  state.enabled = false
end
function M.toggle()
  state.enabled = not state.enabled
end

return M
