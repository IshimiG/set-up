# El portátil

Rama `setup/portatil`: `main` (la parte común) más lo propio del portátil.

- Torre: `/home/ishimimain/Projects/set-up` (rama `setup/torre`)
- Portátil: `/home/ishimi/Projects/set-up` (rama `setup/portatil`)

## Estado

Aplicado el 2026-10-07 sobre Omarchy 3.8.5. La copia para volver atrás está en
`~/Templates/omarchy-respaldo/` (`restaurar.sh`).

## Lo que sólo tiene el portátil

- `.config/hypr/equipo.lua`: monitores desde `~/.config/hypr/monitors.lua`
  (nwg-displays), el agente de polkit e hypridle.
- `.config/hypr/hypridle.conf`: atenúa a 2,5 min, bloquea a 5 y apaga la
  pantalla a 5,5. No suspende solo: de eso se encarga cerrar la tapa.
- La wifi en la barra, contra iwd (aquí no hay NetworkManager, así que
  `Quickshell.Networking` no sirve):
  - `.config/hypr/scripts/wifi.sh`: habla con iwd por D-Bus. Estado, escaneo,
    conectar, olvidar y la radio.
  - `.config/quickshell/bar/Wifi.qml`: el estado y las acciones, una vez para
    todos los monitores.
  - `.config/quickshell/bar/WifiPanel.qml`: el desplegable del bloque de la
    derecha. La radio, la red actual y las demás; las guardadas se pueden
    olvidar (con confirmación) y las de empresa editar. Si la red pide datos,
    sale el formulario: contraseña en una WPA, usuario y contraseña en una
    802.1X (WIFI_EDU, eduroam), que pide polkit porque se guarda en
    `/var/lib/iwd`.
  - Toca tres ficheros comunes: `TelemetryBlock.qml` (el módulo, antes del
    volumen; clic despliega, clic derecho abre `impala`), `shell.qml`
    (`Wifi { }` y la orden `toggleWifi`: `qs -c bar ipc call bar toggleWifi`) y
    `qmldir`. Así se queda hasta que la barra tenga un punto de enganche por
    equipo (issue #3).
  - Paquetes: `iwd` e `impala`.
- `portatil/`: lo que se usó para pasar de Omarchy a este setup.
  - `paquetes.sh` (sudo): quickshell, ghostty, hyprpaper, pavucontrol,
    hyprshutdown, dolphin.
  - `aplicar.sh`: copia de Omarchy, lo aparta y enlaza `~/.config` al repo.

El resto (touchpad, batería en la barra, sensor Intel, yay, pantalla de
bloqueo) está en `main`, porque se adapta solo a la máquina.

## Fuera del repo

- `~/.config/hypr/monitors.lua`: lo escribe nwg-displays.
- `~/.config/hypr/hyprpaper.conf`: el fondo (`~/Wallpapers/wallhaven-rd3pjw.jpg`).
- `~/.config/hypr/xdph.conf`: el selector al compartir pantalla, de Omarchy.

## Restos de Omarchy

Siguen instalados y ya no los usa el escritorio. Quitarlos es opcional:

- Sin uso: `waybar`, `mako`, `walker` y los 13 `elephant-*`, `swayosd`,
  `swaybg`, `hyprsunset`, `omarchy-walker`. `mako` es el único que puede
  molestar: D-Bus lo arranca solo si alguien manda una notificación antes de
  que la barra esté en pie, y entonces se queda con ellas.
- `~/.local/bin/hyprdots-sync`, `launch-waybar-multimonitor`,
  `omarchy-float-tidy` y el repo `~/.local/share/hypr-dotfiles.git`
  (seguía la waybar del primer commit de `main`).
- Todavía en uso: `~/.config/uwsm` (la sesión arranca con uwsm), el autologin
  de SDDM, el aviso de batería baja (`omarchy-battery-monitor.timer`) y
  `~/.config/omarchy` (los temas de nvim, btop y alacritty leen de ahí).
- `xdg-terminal-exec` sigue abriendo Alacritty (`~/.config/xdg-terminals.list`)
  en las apps de terminal del lanzador: btop, nvim, las TUI de Omarchy.
