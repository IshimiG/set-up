-- Los colorschemes del tema del escritorio (SUPER+SHIFT+T). Cuál se pone lo
-- decide config/tema.lua, que lee el del tema activo y lo cambia en caliente;
-- los datos de cada tema están en .config/escritorio/temas/<tema>.conf.
--
--   default, liquido  horizon            (LunarVim/horizon.nvim)
--   catppuccin        catppuccin-mocha   (catppuccin/nvim, ya en LazyVim)
--   tokyonight        tokyonight-night   (folke/tokyonight.nvim, ya en LazyVim)
--   gruvbox           gruvbox, hard      (ellisonleao/gruvbox.nvim)
--   kanagawa          kanagawa-wave      (rebelot/kanagawa.nvim)
--   phosphor          phosphor           (propio: colors/phosphor.lua)
--
-- Todos con lazy = true: lazy.nvim carga el plugin de un colorscheme al pedirlo,
-- así que sólo se carga el del tema activo. gruvbox y kanagawa, además, sólo se
-- descargan cuando su tema se usa (cond: si ya están o si es el activo; con
-- Neovim abierto los instala config/tema.lua). El fondo transparente lo pone
-- config/autocmds.lua en cada ColorScheme; las opciones de transparencia de cada
-- plugin van en el mismo sentido.
local tema = require("config.tema")

local function opts_de(repo)
  for _, p in ipairs(tema.plugins) do
    if p.repo == repo then
      return vim.deepcopy(p.opts)
    end
  end
end

return {
  -- Horizon, el de siempre (default y liquido).
  -- NOTE: the original repo `nyngwang/horizon.nvim` no longer exists (404), which
  -- blocked startup. Switched to the maintained LunarVim port of the same theme.
  -- The user's previous opts are preserved where possible:
  --   * transparent        -> already handled globally by `config/autocmds.lua`
  --                             (Normal/NormalFloat background cleared)
  --   * italic_comments    -> re-applied below on ColorScheme
  {
    "LunarVim/horizon.nvim",
    lazy = true,
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
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    opts = { flavour = "mocha", transparent_background = true },
  },
  {
    "folke/tokyonight.nvim",
    lazy = true,
    opts = { style = "night", transparent = true },
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    cond = tema.hace_falta("ellisonleao/gruvbox.nvim"),
    opts = opts_de("ellisonleao/gruvbox.nvim"),
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = true,
    cond = tema.hace_falta("rebelot/kanagawa.nvim"),
    opts = opts_de("rebelot/kanagawa.nvim"),
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = tema.arrancar,
    },
  },
}
