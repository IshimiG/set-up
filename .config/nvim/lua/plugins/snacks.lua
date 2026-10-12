-- snacks.nvim: sin animación al hacer scroll y sin resaltar las demás apariciones
-- de la palabra bajo el cursor (el documentHighlight del LSP, que en LazyVim hace
-- snacks.words).
return {
  "folke/snacks.nvim",
  opts = {
    scroll = { enabled = false },
    words = { enabled = false },
  },
}
