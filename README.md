# set-up

El escritorio Hyprland + Quickshell: barra de cristal con isla central,
notificaciones propias, lanzador, recordatorios, capturas y la pantalla de
login a juego.

## Ramas

| Rama | Qué es |
|---|---|
| `main` | La parte común. Todo lo que es igual en cualquier máquina. |
| `setup/torre` | `main` + lo de la torre (CachyOS, AMD + NVIDIA, dos monitores). |
| `setup/portatil` | `main` + lo del portátil (Arch, Intel, batería, pantalla HiDPI). |

Lo que cambia de una máquina a otra vive en `.config/hypr/equipo.lua`, que sólo
existe en las ramas de cada máquina. `hyprland.lua` lo carga al final, así que
puede sobrescribir lo común. Lo demás se adapta solo: la barra busca el
sensor de temperatura por nombre y sólo enseña la GPU de NVIDIA, la batería,
el ratón Razer o el loopback del micrófono si la máquina los tiene.

Un cambio común va por PR a `main`, y cada máquina lo recoge con:

```sh
git merge main
```

Como `main` nunca toca `equipo.lua` ni lo propio de cada rama, ese merge no
choca.

## Qué hay

- `.config/hypr/hyprland.lua`: Hyprland, en Lua (0.56+).
- `.config/hypr/hyprlock.conf`: la pantalla de bloqueo.
- `.config/hypr/scripts/`: barra, capturas, notificaciones, recordatorios,
  loopback, aviso de actualizaciones.
- `.config/ghostty/config.ghostty`: la terminal, con el mismo cristal.
- `.config/fish/`: fish, la shell de todas las máquinas: Starship, zoxide, eza,
  las abreviaturas de git, el saludo y `ms` (SSH al homelab).
- `.config/nvim/`: Neovim con LazyVim, el tema Horizon con el fondo transparente
  y los lenguajes que se usan (TypeScript, SQL, Docker, Java, Angular…).
- `.config/quickshell/`: `bar` (barra, isla, notificaciones), `launcher`
  (SUPER+SPACE), `reminder` (SUPER+R), `updates` y `shared` (la paleta).
- `.config/systemd/user/notificaciones.*`: el latido de los recordatorios.
- `.local/bin/launch-or-focus`: enfoca una ventana o lanza la app.
- `sddm/`: el tema "cristal" de la pantalla de login (`sudo sddm/install.sh`).

## Instalación

`~/.config` apunta al repo con enlaces, así que un `git pull` se nota al
momento:

```sh
ln -s ~/Projects/set-up/.config/hypr/hyprland.lua  ~/.config/hypr/
ln -s ~/Projects/set-up/.config/hypr/hyprlock.conf ~/.config/hypr/
ln -s ~/Projects/set-up/.config/hypr/scripts       ~/.config/hypr/
ln -s ~/Projects/set-up/.config/quickshell         ~/.config/
ln -s ~/Projects/set-up/.config/ghostty/config.ghostty ~/.config/ghostty/
ln -s ~/Projects/set-up/.config/nvim              ~/.config/
ln -s ~/Projects/set-up/.config/fish/config.fish ~/.config/fish/
ln -s ~/Projects/set-up/.config/fish/functions/{fish_greeting,ms}.fish ~/.config/fish/functions/
chsh -s /usr/bin/fish
ln -s ~/Projects/set-up/.config/systemd/user/notificaciones.{service,timer} ~/.config/systemd/user/
ln -s ~/Projects/set-up/.local/bin/launch-or-focus ~/.local/bin/
systemctl --user enable --now notificaciones.timer
```

Fuera del repo, en cada máquina: `~/.config/hypr/hyprpaper.conf` (el fondo).

Paquetes: `hyprland` (0.56+), `quickshell`, `ghostty`, `hyprpaper`,
`hyprlock`, `hyprpicker`, `hyprshutdown`, `grim`, `slurp`, `satty`,
`wl-clipboard`, `jq`, `libnotify`, `pacman-contrib`, `pavucontrol`,
`playerctl`, `brightnessctl`, `btop`, `ttf-jetbrains-mono-nerd`, `neovim`,
`tree-sitter-cli`, `nodejs`, `npm`, `fish`, `starship`, `zoxide`, `eza`, `direnv`,
`fastfetch` y `paru` o `yay`. Opcional: `gcalcli` (avisos de Google Calendar).
