-- Biome is the repo's single lint + format tool (no ESLint/Prettier).
-- Prefer the workspace-local Biome binary when available (the version is
-- pinned by the project's package.json) and fall back to the mason-installed one.
local function local_biome(ctx)
  local file = vim.fs.find({ "node_modules/.bin/biome" }, { path = ctx.filename, upward = true })[1]
  if file and vim.fn.executable(file) == 1 then
    return file
  end
  return "biome"
end

-- Never run Prettier on top of Biome (e.g. if the prettier extra gets enabled later).
vim.g.lazyvim_prettier_needs_config = true

return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters = opts.formatters or {}
      local f = opts.formatters["biome-check"]
      if type(f) == "table" then
        f.command = local_biome
      end
    end,
  },
}