-- El portátil (ishimi, Arch con Omarchy debajo, Intel Iris Xe, pantalla
-- 2880x1800 a 90 Hz). Lo carga hyprland.lua al final, así que lo de aquí puede
-- sobrescribir lo común.

------------------
---- MONITORS ----
------------------

-- Los escribe nwg-displays en ~/.config/hypr/monitors.lua (la pantalla
-- interna a escala 2 y, cuando está enchufado, el WAM de 27"), y por eso no
-- van en el repo: cambian según dónde esté el portátil. Esa carpeta no está en
-- el package.path, que Hyprland arma desde la del repo, así que se añade.
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path
if package.searchpath("monitors", package.path) then
	require("monitors")
else
	hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
end

-------------------
---- AUTOSTART ----
-------------------

-- Lo que en Omarchy arrancaba su autostart y aquí sigue haciendo falta. El
-- agente de polkit es el que pide la contraseña cuando una app gráfica
-- necesita permisos (sin él, esas peticiones fallan en silencio), e hypridle
-- atenúa, bloquea y apaga la pantalla en reposo (hypridle.conf).
hl.on("hyprland.start", function()
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
	hl.exec_cmd("hypridle")
end)
