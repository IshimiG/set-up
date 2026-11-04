-- El tema del escritorio en Neovim (ver «Temas» en el README del set-up).
--
-- hypr/scripts/tema-apps.sh deja el colorscheme del tema activo en
-- ${XDG_STATE_HOME:-~/.local/state}/escritorio/nvim.lua. Al arrancar se pone
-- ése (horizon si no hay fichero o no se puede), y un vigilante de la carpeta lo
-- vuelve a poner, en caliente y en cada Neovim abierto, cada vez que cambia. El
-- fondo transparente lo sigue quitando config/autocmds.lua en cada ColorScheme.
--
-- Los plugins de los temas (lua/plugins/temas.lua) van con lazy = true: lazy.nvim
-- carga el de un colorscheme al pedirlo. Los que no trae LazyVim (gruvbox y
-- kanagawa) no se descargan hasta que su tema se usa: al arrancar, sólo si es el
-- activo (cond); con Neovim abierto, M.instalar los clona en la carpeta de
-- lazy.nvim, que desde el siguiente arranque los lleva como a los demás.
local M = {}

local uv = vim.uv or vim.loop

local estado = vim.env.XDG_STATE_HOME
if estado == nil or estado == "" then
  estado = vim.env.HOME .. "/.local/state"
end
M.carpeta = estado .. "/escritorio"
M.fichero = M.carpeta .. "/nvim.lua"
M.reserva = "horizon"

-- Los colorschemes de plugins que no trae LazyVim, con lo que hace falta para
-- instalarlos y configurarlos sin lazy.nvim. `opts` es lo mismo que recibe el
-- plugin en lua/plugins/temas.lua.
M.plugins = {
  {
    repo = "ellisonleao/gruvbox.nvim",
    modulo = "gruvbox",
    colores = { "gruvbox" },
    opts = { contrast = "hard", transparent_mode = true },
  },
  {
    repo = "rebelot/kanagawa.nvim",
    modulo = "kanagawa",
    colores = { "kanagawa", "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus" },
    opts = { theme = "wave", transparent = true },
  },
}

local function nombre(p)
  return p.repo:match("[^/]+$")
end

local function carpeta_de(p)
  return require("lazy.core.config").options.root .. "/" .. nombre(p)
end

local function instalado(p)
  return uv.fs_stat(carpeta_de(p) .. "/colors") ~= nil
end

local function plugin_de(colorscheme)
  for _, p in ipairs(M.plugins) do
    if vim.tbl_contains(p.colores, colorscheme) then
      return p
    end
  end
end

local function avisar(msg, nivel)
  vim.notify(msg, nivel or vim.log.levels.INFO, { title = "Tema" })
end

--- El colorscheme que dice el fichero, o nil si no hay o no se entiende.
function M.leer()
  local trozo = loadfile(M.fichero)
  if not trozo then
    return nil
  end
  setfenv(trozo, {}) -- sólo una tabla: sin acceso a nada
  local ok, t = pcall(trozo)
  if ok and type(t) == "table" and type(t.colorscheme) == "string" and t.colorscheme:match("^[%w_.-]+$") then
    return t.colorscheme
  end
end

--- Para el `cond` de un plugin de M.plugins: si está instalado o es el del tema
--- activo (y entonces lazy.nvim lo instala al arrancar).
function M.hace_falta(repo)
  return function()
    for _, p in ipairs(M.plugins) do
      if p.repo == repo then
        return instalado(p) or vim.tbl_contains(p.colores, M.leer() or "")
      end
    end
    return true
  end
end

-- Un plugin que lazy.nvim no lleva en esta sesión (su cond era falso al
-- arrancar): a mano, al runtimepath y su setup.
local function cargar(p)
  local dir = carpeta_de(p)
  if not vim.tbl_contains(vim.opt.rtp:get(), dir) then
    vim.opt.rtp:append(dir)
  end
  local ok, modulo = pcall(require, p.modulo)
  if ok and type(modulo) == "table" and type(modulo.setup) == "function" then
    pcall(modulo.setup, vim.deepcopy(p.opts))
  end
end

local instalando = {}

--- Clona el plugin p en la carpeta de lazy.nvim y llama a `listo(ok)`. Clona en
--- una carpeta temporal y la renombra: si otro Neovim lo instala a la vez, gana
--- el primero y el otro tira lo suyo.
function M.instalar(p, listo)
  local dir = carpeta_de(p)
  if instalando[dir] then
    return
  end
  instalando[dir] = true
  local tmp = dir .. ".tema-" .. uv.os_getpid()
  vim.fn.delete(tmp, "rf")
  avisar("Instalando " .. p.repo .. "…")
  vim.system(
    { "git", "clone", "--filter=blob:none", "https://github.com/" .. p.repo .. ".git", tmp },
    { text = true },
    vim.schedule_wrap(function(r)
      instalando[dir] = nil
      if r.code == 0 and not uv.fs_stat(dir) then
        uv.fs_rename(tmp, dir)
      end
      vim.fn.delete(tmp, "rf")
      if not instalado(p) then
        avisar("No se pudo instalar " .. p.repo .. ": " .. vim.trim(r.stderr or ""), vim.log.levels.WARN)
      end
      listo(instalado(p))
    end)
  )
end

--- Pone el colorscheme cs. Devuelve true si lo puso, false si no puede y
--- "pendiente" si lo está instalando (lo pone él al acabar).
function M.poner(cs)
  if pcall(vim.cmd.colorscheme, cs) then
    return true
  end
  local p = plugin_de(cs)
  if not p then
    return false
  end
  if instalado(p) then
    cargar(p)
    return (pcall(vim.cmd.colorscheme, cs))
  end
  M.instalar(p, function(ok)
    -- Si mientras se instalaba el tema volvió a cambiar, manda el de ahora.
    if (M.leer() or M.reserva) ~= cs then
      return
    end
    if ok then
      cargar(p)
      if pcall(vim.cmd.colorscheme, cs) then
        M.actual = cs
        return
      end
    end
    pcall(vim.cmd.colorscheme, M.reserva)
  end)
  return "pendiente"
end

--- Pone el colorscheme del fichero (o el de reserva). Si es el que ya se puso,
--- nada, salvo con `forzar`. Se compara con el último que se pidió y no con
--- vim.g.colors_name, que no siempre es el nombre pedido (kanagawa-wave se
--- llama kanagawa).
function M.aplicar(forzar)
  local cs = M.leer() or M.reserva
  if cs == M.actual and not forzar then
    return
  end
  M.actual = nil
  vim.o.background = "dark"
  local r = M.poner(cs)
  if r == true then
    M.actual = cs
  elseif r == false then
    if cs ~= M.reserva then
      avisar("No puedo poner «" .. cs .. "»; va " .. M.reserva, vim.log.levels.WARN)
    end
    pcall(vim.cmd.colorscheme, M.reserva)
  end
end

--- Vigila la carpeta del estado: tema-apps.sh renombra nvim.lua encima, así que
--- se vigila la carpeta y no el fichero (el que se vigila es el que se va).
function M.vigilar()
  if M.vigilante or not uv.fs_stat(M.carpeta) then
    return
  end
  local w = uv.new_fs_event()
  if not w then
    return
  end
  local pendiente = false
  local ok = w:start(M.carpeta, {}, function(err, fichero)
    if err or fichero ~= "nvim.lua" or pendiente then
      return
    end
    -- Un renombrado da varios avisos seguidos: uno solo, un poco después.
    pendiente = true
    vim.defer_fn(function()
      pendiente = false
      M.aplicar()
    end, 100)
  end)
  if ok then
    M.vigilante = w
  else
    w:close()
  end
end

--- Para LazyVim (opts.colorscheme): el del tema al arrancar, y a vigilar.
function M.arrancar()
  M.aplicar(true)
  M.vigilar()
end

return M
