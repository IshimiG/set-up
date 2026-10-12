-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- `jj` en modo insertar vuelve a modo normal.
vim.keymap.set("i", "jj", "<Esc>", { desc = "Salir de insertar" })
