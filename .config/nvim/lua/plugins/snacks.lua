-- snacks.nvim: sin animación al hacer scroll y sin resaltar las demás apariciones
-- de la palabra bajo el cursor (el documentHighlight del LSP, que en LazyVim hace
-- snacks.words). Los buscadores de ficheros y de texto incluyen los ocultos (.git
-- lo excluye snacks).
return {
  "folke/snacks.nvim",
  opts = {
    scroll = { enabled = false },
    words = { enabled = false },
    picker = {
      sources = {
        files = { hidden = true },
        grep = { hidden = true },
      },
    },
  },
}
