-- phosphor: fósforo verde sobre negro, el colorscheme del tema phosphor del
-- escritorio (.config/escritorio/temas/phosphor.conf, de donde salen el fondo,
-- el texto, el cursor, la selección y la paleta de la terminal). No hay uno
-- oficial: es propio. Todo es verde, de una sola tinta, y lo que hay que
-- distinguir va por intensidad, negrita o subrayado; sólo los errores y los
-- avisos se salen del verde (el rojo y el amarillo de la paleta), para que se
-- vean. El fondo lo deja transparente config/autocmds.lua, como en los demás.

vim.cmd("highlight clear")
if vim.g.syntax_on then
  vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.g.colors_name = "phosphor"

-- Del más apagado al más vivo.
local c = {
  negro = "#000000",
  fondo2 = "#020a02", -- bg_alt
  capa = "#0a1a0a", -- surface: lo que flota
  linea = "#0a3a0a", -- separadores, la línea del cursor
  seleccion = "#083905",
  tenue = "#0a5a0a", -- lo que casi no se ve
  apagado = "#00a600", -- fg_dim
  medio = "#00d900",
  verde = "#00ff00", -- el texto
  vivo = "#23ff18", -- el cursor, el acento
  blanco = "#b0ffb0", -- el verde saturado, lo que más resalta
  rojo = "#e50000",
  amarillo = "#e5e500",
}

local grupos = {
  Normal = { fg = c.verde, bg = c.negro },
  NormalNC = { fg = c.verde, bg = c.negro },
  NormalFloat = { fg = c.verde, bg = c.capa },
  FloatBorder = { fg = c.apagado, bg = c.capa },
  FloatTitle = { fg = c.vivo, bg = c.capa, bold = true },
  Cursor = { fg = c.negro, bg = c.vivo },
  lCursor = { link = "Cursor" },
  CursorIM = { link = "Cursor" },
  TermCursor = { link = "Cursor" },
  CursorLine = { bg = c.fondo2 },
  CursorColumn = { bg = c.fondo2 },
  ColorColumn = { bg = c.capa },
  CursorLineNr = { fg = c.vivo, bold = true },
  LineNr = { fg = c.tenue },
  LineNrAbove = { link = "LineNr" },
  LineNrBelow = { link = "LineNr" },
  SignColumn = { fg = c.apagado },
  FoldColumn = { fg = c.tenue },
  Folded = { fg = c.apagado, bg = c.capa },
  WinSeparator = { fg = c.linea },
  VertSplit = { link = "WinSeparator" },
  StatusLine = { fg = c.verde, bg = c.capa },
  StatusLineNC = { fg = c.apagado, bg = c.fondo2 },
  TabLine = { fg = c.apagado, bg = c.capa },
  TabLineFill = { bg = c.fondo2 },
  TabLineSel = { fg = c.negro, bg = c.verde, bold = true },
  WinBar = { fg = c.verde, bold = true },
  WinBarNC = { fg = c.apagado },
  Pmenu = { fg = c.verde, bg = c.capa },
  PmenuSel = { fg = c.negro, bg = c.verde, bold = true },
  PmenuSbar = { bg = c.capa },
  PmenuThumb = { bg = c.apagado },
  PmenuKind = { fg = c.medio, bg = c.capa },
  PmenuExtra = { fg = c.apagado, bg = c.capa },
  Visual = { bg = c.seleccion },
  VisualNOS = { link = "Visual" },
  Search = { fg = c.negro, bg = c.apagado },
  IncSearch = { fg = c.negro, bg = c.vivo, bold = true },
  CurSearch = { link = "IncSearch" },
  Substitute = { link = "IncSearch" },
  MatchParen = { fg = c.blanco, bold = true, underline = true },
  NonText = { fg = c.tenue },
  Whitespace = { fg = c.linea },
  SpecialKey = { fg = c.tenue },
  EndOfBuffer = { fg = c.negro },
  Conceal = { fg = c.apagado },
  Directory = { fg = c.vivo, bold = true },
  Title = { fg = c.blanco, bold = true },
  Question = { fg = c.vivo },
  MoreMsg = { fg = c.vivo },
  ModeMsg = { fg = c.verde, bold = true },
  MsgArea = { fg = c.verde },
  ErrorMsg = { fg = c.rojo, bold = true },
  WarningMsg = { fg = c.amarillo },
  QuickFixLine = { bg = c.seleccion, bold = true },
  WildMenu = { link = "PmenuSel" },
  SpellBad = { sp = c.rojo, undercurl = true },
  SpellCap = { sp = c.amarillo, undercurl = true },
  SpellLocal = { sp = c.medio, undercurl = true },
  SpellRare = { sp = c.medio, undercurl = true },

  -- La sintaxis: por intensidad.
  Comment = { fg = c.apagado, italic = true },
  Constant = { fg = c.blanco },
  String = { fg = c.medio },
  Character = { link = "String" },
  Number = { fg = c.blanco },
  Boolean = { fg = c.blanco, bold = true },
  Float = { link = "Number" },
  Identifier = { fg = c.verde },
  Function = { fg = c.vivo, bold = true },
  Statement = { fg = c.blanco, bold = true },
  Conditional = { link = "Statement" },
  Repeat = { link = "Statement" },
  Label = { link = "Statement" },
  Keyword = { link = "Statement" },
  Exception = { link = "Statement" },
  Operator = { fg = c.medio },
  PreProc = { fg = c.medio, bold = true },
  Include = { link = "PreProc" },
  Define = { link = "PreProc" },
  Macro = { link = "PreProc" },
  PreCondit = { link = "PreProc" },
  Type = { fg = c.vivo },
  StorageClass = { link = "Type" },
  Structure = { link = "Type" },
  Typedef = { link = "Type" },
  Special = { fg = c.blanco },
  SpecialChar = { link = "Special" },
  Tag = { link = "Special" },
  Delimiter = { fg = c.apagado },
  SpecialComment = { fg = c.medio, italic = true },
  Debug = { link = "Special" },
  Underlined = { fg = c.vivo, underline = true },
  Ignore = { fg = c.tenue },
  Error = { fg = c.rojo, bold = true },
  Todo = { fg = c.negro, bg = c.vivo, bold = true },

  -- Treesitter y LSP: casi todo enlaza solo a lo de arriba; esto lo matiza.
  ["@variable"] = { fg = c.verde },
  ["@variable.builtin"] = { fg = c.blanco, italic = true },
  ["@variable.parameter"] = { fg = c.verde, italic = true },
  ["@variable.member"] = { fg = c.verde },
  ["@property"] = { fg = c.verde },
  ["@constant.builtin"] = { fg = c.blanco, bold = true },
  ["@module"] = { fg = c.medio },
  ["@string.escape"] = { fg = c.blanco, bold = true },
  ["@punctuation"] = { link = "Delimiter" },
  ["@tag"] = { fg = c.vivo },
  ["@tag.attribute"] = { fg = c.medio },
  ["@tag.delimiter"] = { link = "Delimiter" },
  ["@markup.heading"] = { link = "Title" },
  ["@markup.strong"] = { bold = true },
  ["@markup.italic"] = { italic = true },
  ["@markup.link"] = { fg = c.vivo, underline = true },
  ["@markup.raw"] = { fg = c.medio },
  ["@comment.todo"] = { link = "Todo" },
  ["@comment.error"] = { fg = c.rojo, bold = true },
  ["@comment.warning"] = { fg = c.amarillo, bold = true },
  LspReferenceText = { bg = c.capa },
  LspReferenceRead = { bg = c.capa },
  LspReferenceWrite = { bg = c.capa, underline = true },
  LspInlayHint = { fg = c.tenue, italic = true },
  LspSignatureActiveParameter = { fg = c.blanco, bold = true, underline = true },

  -- Diagnósticos: errores en rojo y avisos en amarillo; lo demás, verde.
  DiagnosticError = { fg = c.rojo },
  DiagnosticWarn = { fg = c.amarillo },
  DiagnosticInfo = { fg = c.medio },
  DiagnosticHint = { fg = c.apagado },
  DiagnosticOk = { fg = c.vivo },
  DiagnosticUnderlineError = { sp = c.rojo, undercurl = true },
  DiagnosticUnderlineWarn = { sp = c.amarillo, undercurl = true },
  DiagnosticUnderlineInfo = { sp = c.medio, undercurl = true },
  DiagnosticUnderlineHint = { sp = c.apagado, undercurl = true },
  DiagnosticUnderlineOk = { sp = c.vivo, undercurl = true },
  DiagnosticVirtualTextError = { fg = c.rojo, bg = c.fondo2 },
  DiagnosticVirtualTextWarn = { fg = c.amarillo, bg = c.fondo2 },
  DiagnosticVirtualTextInfo = { fg = c.medio, bg = c.fondo2 },
  DiagnosticVirtualTextHint = { fg = c.apagado, bg = c.fondo2 },
  DiagnosticUnnecessary = { fg = c.tenue },
  DiagnosticDeprecated = { strikethrough = true },

  -- Diferencias y git: por intensidad (+ vivo, ~ medio, - tenue tachado).
  DiffAdd = { fg = c.vivo, bg = c.capa },
  DiffChange = { fg = c.medio, bg = c.fondo2 },
  DiffDelete = { fg = c.tenue, bg = c.fondo2 },
  DiffText = { fg = c.blanco, bg = c.seleccion, bold = true },
  Added = { fg = c.vivo },
  Changed = { fg = c.medio },
  Removed = { fg = c.tenue },
  GitSignsAdd = { fg = c.vivo },
  GitSignsChange = { fg = c.medio },
  GitSignsDelete = { fg = c.apagado },

  -- Lo de los plugins de LazyVim que no enlaza solo.
  SnacksIndent = { fg = c.linea },
  SnacksIndentScope = { fg = c.apagado },
  SnacksPickerMatch = { fg = c.blanco, bold = true },
  SnacksPickerDir = { fg = c.apagado },
  WhichKey = { fg = c.vivo },
  WhichKeyGroup = { fg = c.medio },
  WhichKeyDesc = { fg = c.verde },
  WhichKeySeparator = { fg = c.tenue },
  FlashLabel = { fg = c.negro, bg = c.blanco, bold = true },
  FlashMatch = { fg = c.vivo, underline = true },
  NeoTreeDirectoryName = { fg = c.vivo },
  NeoTreeDirectoryIcon = { fg = c.vivo },
  NeoTreeRootName = { fg = c.blanco, bold = true },
  NeoTreeGitModified = { fg = c.medio },
  NeoTreeGitUntracked = { fg = c.apagado, italic = true },
  BlinkCmpMenu = { link = "Pmenu" },
  BlinkCmpMenuSelection = { link = "PmenuSel" },
  BlinkCmpMenuBorder = { link = "FloatBorder" },
  BlinkCmpLabelMatch = { fg = c.blanco, bold = true },
  NoiceCmdlinePopupBorder = { link = "FloatBorder" },
  BufferLineFill = { bg = c.fondo2 },
  MiniIconsGreen = { fg = c.verde },
  MiniIconsAzure = { fg = c.medio },
  MiniIconsBlue = { fg = c.medio },
  MiniIconsCyan = { fg = c.medio },
  MiniIconsGrey = { fg = c.apagado },
  MiniIconsOrange = { fg = c.blanco },
  MiniIconsPurple = { fg = c.vivo },
  MiniIconsRed = { fg = c.blanco },
  MiniIconsYellow = { fg = c.blanco },
}

for nombre, hl in pairs(grupos) do
  vim.api.nvim_set_hl(0, nombre, hl)
end

-- La terminal de dentro, con la paleta ANSI de phosphor.conf.
local ansi = {
  "#000000", "#990000", "#00a600", "#999900", "#0d0dbf", "#b200b2", "#00a6b2", "#bfbfbf",
  "#666666", "#e50000", "#00d900", "#e5e500", "#0000ff", "#e500e5", "#00e5e5", "#e5e5e5",
}
for i, color in ipairs(ansi) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
