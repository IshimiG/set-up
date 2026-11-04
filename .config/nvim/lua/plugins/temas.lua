-- Horizon colorscheme.
-- NOTE: the original repo `nyngwang/horizon.nvim` no longer exists (404), which
-- blocked startup. Switched to the maintained LunarVim port of the same theme.
-- The user's previous opts are preserved where possible:
--   * transparent        -> already handled globally by `config/autocmds.lua`
--                             (Normal/NormalFloat background cleared)
--   * italic_comments    -> re-applied below on ColorScheme
return {
  {
    "LunarVim/horizon.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("horizon").setup()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("horizon_italic_comments", { clear = true }),
        pattern = "horizon",
        callback = function()
          vim.api.nvim_set_hl(0, "Comment", { italic = true })
        end,
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "horizon",
    },
  },
}