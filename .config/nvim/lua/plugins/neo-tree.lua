-- neo-tree: enseña los ficheros ocultos (.env, .gitignore...) y los que ignora git
-- (data/, node_modules/...), atenuados. La carpeta .git no aparece nunca.
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
        never_show = { ".git" },
      },
    },
  },
}
