-- This file simply bootstraps the installation of Lazy.nvim and then calls other files for execution
-- This file doesn't necessarily need to be touched, BE CAUTIOUS editing this file and proceed at your own risk.
local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  -- stylua: ignore
  local result = vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
  if vim.v.shell_error ~= 0 then
    -- stylua: ignore
    vim.api.nvim_echo({ { ("Error cloning lazy.nvim:\n%s\n"):format(result), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
  end
end

vim.opt.rtp:prepend(lazypath)

-- validate that lazy is available
if not pcall(require, "lazy") then
  -- stylua: ignore
  vim.api.nvim_echo({ { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end

require "lazy_setup"

vim.api.nvim_create_user_command("Code", function()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    vim.notify("Current buffer has no file", vim.log.levels.ERROR)
    return
  end
  if vim.fn.executable "code" ~= 1 then
    vim.notify("VS Code CLI not found", vim.log.levels.ERROR)
    return
  end

  vim.cmd.update()
  local cursor = vim.api.nvim_win_get_cursor(0)
  vim.system(
    { "code", "--reuse-window", "--goto", ("%s:%d:%d"):format(path, cursor[1], cursor[2] + 1) },
    { detach = true }
  )
end, { desc = "Open the current buffer in VS Code" })
