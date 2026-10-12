-- The repo uses Vitest for testing. Wire up the neotest-vitest adapter so the
-- LazyVim `<leader>t*` keymaps (test.core extra) work with Vitest.
return {
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "marilari88/neotest-vitest" },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(opts.adapters, "neotest-vitest")
    end,
  },
}