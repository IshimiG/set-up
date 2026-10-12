-- La torre (ishimimain, CachyOS, AMD + NVIDIA). Lo carga hyprland.lua al
-- final, así que lo de aquí puede sobrescribir lo común.

------------------
---- MONITORS ----
------------------

-- Monitor principal (WAM OZDSP27IPS, 27" 1440p). Su EDID anuncia 144 Hz a
-- resolución nativa, que es el máximo real del panel.
hl.monitor({
	output = "DP-1",
	mode = "2560x1440@144",
	position = "2560x0",
	scale = 1,
})

-- Panorámica (LG ULTRAWIDE, 2560x1080 por HDMI). El EDID solo ofrece 59.98 y
-- 74.99 Hz a resolución nativa, así que 75 Hz es el tope alcanzable aquí;
-- no existe un modo de 90 Hz. Si el panel admitiera más, sería por DisplayPort.
hl.monitor({
	output = "HDMI-A-1",
	mode = "2560x1080@74.99",
	position = "0x0",
	scale = 1,
})

-----------------------
---- DOTFILES SYNC ----
-----------------------

-- Pulls github.com/IshimiG/set-up on every Hyprland start so the
-- symlinked configs in ~/.config stay in sync with the git repo.
hl.on("hyprland.start", function()
	hl.exec_cmd("~/.local/bin/dotfiles-sync.sh")
end)

-----------------------------------
---- LOOPBACK DEL MICRÓFONO ----
-----------------------------------

-- Repone el loopback del micrófono si quedó encendido en la sesión anterior.
-- Sustituye al autostart de GNOME (~/.config/autostart/loopback-restore.desktop),
-- que Hyprland no lee. El comando `restore` descarga primero cualquier
-- module-loopback huérfano: dos cargados a la vez suenan con eco metálico
-- (comb filtering), que fue el fallo original de este montaje en GNOME.
hl.on("hyprland.start", function()
	hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/loopback.sh restore")
end)

-- Loopback del micrófono a los auriculares: escucharte a ti mismo en directo.
-- Es el mismo toggle que el glifo del micro en la barra. L de loopback.
hl.bind(
	"SUPER + SHIFT + L",
	hl.dsp.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/loopback.sh toggle")
)
