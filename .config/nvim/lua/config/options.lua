-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Números de línea normales, no relativos.
vim.opt.relativenumber = false
-- Las líneas largas se ajustan a la ventana y se parten por palabras.
vim.opt.wrap = true
vim.opt.linebreak = true
-- Ventanas flotantes un poco translúcidas, a juego con el cristal del escritorio.
vim.opt.winblend = 10
-- Sin la guía animada del bloque de sangría (mini.indentscope).
vim.g.miniindentscope_disable = true
