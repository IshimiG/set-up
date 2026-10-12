-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Fondo transparente: deja ver el cristal de Ghostty. Se quita el fondo de cada
-- grupo conservando el resto de sus colores, y se repite cada vez que cambia el
-- tema, porque al cargar un tema los grupos vuelven a tener fondo.
local transparent = {
  "Normal", "NormalFloat", "NormalNC", "FloatBorder", "Pmenu", "Terminal",
  "EndOfBuffer", "FoldColumn", "Folded", "SignColumn", "LineNr", "CursorLineNr",
  "WhichKeyFloat",
  "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeVertSplit", "NeoTreeWinSeparator", "NeoTreeEndOfBuffer",
  "NotifyINFOBody", "NotifyERRORBody", "NotifyWARNBody", "NotifyTRACEBody", "NotifyDEBUGBody",
  "NotifyINFOTitle", "NotifyERRORTitle", "NotifyWARNTitle", "NotifyTRACETitle", "NotifyDEBUGTitle",
  "NotifyINFOBorder", "NotifyERRORBorder", "NotifyWARNBorder", "NotifyTRACEBorder", "NotifyDEBUGBorder",
}

local function clear_backgrounds()
  for _, name in ipairs(transparent) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if ok then
      hl.bg = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("transparent_bg", { clear = true }),
  callback = clear_backgrounds,
})
clear_backgrounds()
