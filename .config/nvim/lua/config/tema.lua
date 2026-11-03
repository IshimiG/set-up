-- El tema del escritorio (default o liquido) decide el colorscheme de Neovim:
--   default -> horizon (como siempre)
--   liquido -> aurora  (colors/aurora.lua, con la paleta del tema liquido)
-- Lo lee del mismo fichero que Hyprland y Quickshell, que escribe
-- ~/.config/hypr/scripts/tema.sh: ${XDG_STATE_HOME:-~/.local/state}/escritorio/tema.
-- Si falta o dice otra cosa, default.
--
-- Cambia en caliente, sin reiniciar: vigila la carpeta del estado con un
-- vim.uv fs_event (tema.sh renombra un temporal encima, así que se mira la
-- carpeta y se filtra por nombre) y, por si el vigilante no sirve, reaplica
-- también al volver el foco (FocusGained).
local M = {}

local uv = vim.uv or vim.loop

function M.dir()
  local base = vim.env.XDG_STATE_HOME
  if not base or base == "" then
    base = vim.fn.expand("~") .. "/.local/state"
  end
  return base .. "/escritorio"
end

function M.actual()
  local f = io.open(M.dir() .. "/tema", "r")
  if not f then
    return "default"
  end
  local texto = f:read("a") or ""
  f:close()
  local nombre = texto:match("^%s*(%S+)%s*$")
  if nombre == "liquido" then
    return nombre
  end
  return "default"
end

function M.colorscheme()
  return M.actual() == "liquido" and "aurora" or "horizon"
end

-- Pone el colorscheme del tema si no es ya el que está. LazyVim la llama al
-- arrancar (opts.colorscheme); el vigilante, cada vez que cambia el fichero.
function M.aplicar()
  local cs = M.colorscheme()
  if vim.g.colors_name ~= cs then
    pcall(vim.cmd.colorscheme, cs)
  end
end

local vigilante
function M.vigilar()
  vim.api.nvim_create_autocmd("FocusGained", {
    group = vim.api.nvim_create_augroup("tema_escritorio", { clear = true }),
    callback = M.aplicar,
  })
  if vigilante then
    return
  end
  local ev = uv.new_fs_event()
  if not ev then
    return
  end
  local ok = ev:start(M.dir(), {}, function(err, nombre)
    if err or (nombre and nombre ~= "tema") then
      return
    end
    vim.schedule(M.aplicar)
  end)
  if ok == 0 then
    vigilante = ev
  else
    ev:close() -- la carpeta no existe aún: queda FocusGained
  end
end

return M
