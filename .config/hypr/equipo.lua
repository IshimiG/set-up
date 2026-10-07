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
