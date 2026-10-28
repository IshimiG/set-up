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

Lo que cambia de una máquina a otra vive en ficheros que sólo existen en las
ramas de cada máquina, así que `main` nunca los toca:

- `.config/hypr/equipo.lua`: monitores y lo que sólo arranca en una máquina.
  `hyprland.lua` lo carga al final, así que puede sobrescribir lo común.
- `.config/quickshell/bar/equipo/`: los módulos de la barra que sólo tiene una
  máquina (la wifi y la batería en el portátil; la GPU, el ratón Razer y el
  loopback del micrófono en la torre). `shell.qml` carga `equipo/Equipo.qml` si
  existe, y la barra le deja dos huecos (antes del volumen y detrás de la
  memoria) y el desplegable del bloque de la derecha. Cada módulo es un
  `Modulo` (`bar/Modulo.qml`).

El sensor de temperatura se busca por nombre, así que vale para cualquier
máquina.

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
  aviso de actualizaciones.
- `.config/ghostty/config.ghostty`: la terminal, con el mismo cristal.
- `.config/fish/`: fish, la shell de todas las máquinas: Starship, zoxide, eza,
  las abreviaturas de git, el saludo y `ms` (SSH al homelab).
- `.config/nvim/`: Neovim con LazyVim, el tema Horizon con el fondo transparente
  y los lenguajes que se usan (TypeScript, SQL, Docker, Java, Angular…).
- `.config/quickshell/`: `bar` (barra, isla, notificaciones y el calendario,
  que marca las tareas con fecha y las entregas de Aules: se las deja el cajón
  del homelab en `$XDG_RUNTIME_DIR/escritorio-agenda.json`), `launcher`
  (SUPER+SPACE), `reminder` (SUPER+R), `updates`, `homelab` (el panel del
  homelab: el cajón que sale del centro del borde derecho, o con SUPER+H, con
  los datos del panel del NUC; cada equipo entra con su usuario, y la contraseña
  va en el llavero: `secret-tool store --label="Panel del homelab" servicio
  homelab-panel usuario <equipo>`; secciones: Inicio con los hábitos de hoy,
  Tareas al estilo Foco, editables y con los atajos de la web, Clase con el
  botón «Actualizar Aules», Proyectos con sus subproyectos (estado, prioridad,
  progreso y siguiente paso editables; las PR e issues, solo para leer),
  Servidor con los contenedores en vivo, las acciones de Docker (escribiendo el
  nombre cuando hace falta), los logs y el consumo, el Registro, y Notas: las
  notas del vault como página, sólo para leer, con un Markdown propio, los
  `[[enlaces]]` navegables y atrás y adelante) y `shared` (la paleta).
- `.config/systemd/user/notificaciones.*`: el latido de los recordatorios.
- `.local/bin/launch-or-focus`: enfoca una ventana o lanza la app.
- `.local/bin/actualizar-equipo` (sólo en la rama de un equipo, si lo quiere):
  lo que el botón «Actualizar ahora» del aviso hace después de `paru -Syu`.
- `sddm/`: el tema "cristal" de la pantalla de login (`sudo sddm/install.sh`).
- `pruebas/homelab/`: pruebas sin pantalla del cajón del homelab. `prueba.sh`
  prueba la interfaz (el cajón, Inicio, tareas con sus atajos, hábitos, Aules,
  proyectos, servidor, registro y notas) con una API falsa con estado
  (`ApiFalsa.qml`; `--guardar` deja las capturas; con `PRUEBA_NOTA_REAL`, Notas
  abre también esa nota del vault de verdad, sólo para leer),
  y `api/prueba-api.sh`, la conexión y las escrituras (`Api.qml`) contra un panel
  local (`panel-local.sh`, el panel del repo `homelab` con un Docker y un Caddy
  falsos, en Docker, y un vault falso), con un llavero de usar y tirar. Ninguna
  toca el NUC ni el llavero de verdad.
- `pruebas/calendario/prueba.sh`: prueba sin pantalla de la agenda del
  calendario: el formato (`shared/AgendaFormato.js`), el fichero que escribe el
  cajón y lee la barra (en un `$XDG_RUNTIME_DIR` de prueba) y el
  `CalendarPanel.qml` con sus puntos, la lista del día y los clics
  (`--guardar` deja las capturas). Levanta un panel falso
  (`panel-falso.py`), así que necesita `python3`.

## Instalación

Con el repo clonado en `~/Projects/set-up`:

```sh
~/Projects/set-up/setup.sh --comprobar   # qué haría, sin tocar nada
~/Projects/set-up/setup.sh               # lo hace (pide sudo para los paquetes)
```

Lo primero que pregunta es si la máquina es una torre o un portátil (o
`--torre`, `--portatil`). Si el repo no está en la rama de ese equipo, cambia a
ella y vuelve a empezar desde allí, así que basta con clonar y ejecutarlo: monta
lo común y lo del equipo juntos.

`setup.sh` instala los paquetes que falten (la lista está en el propio script;
los del AUR, con `yay` o `paru`), enlaza `~/.config` y `~/.local/bin` al repo
(así un `git pull` se nota al momento), descarga el fondo si la máquina no
tiene `~/.config/hypr/hyprpaper.conf`, activa los servicios de usuario y pone
fish como shell. Lo que hubiera en el sitio de un enlace se aparta a
`~/.local/share/set-up-apartado/<fecha>/`, no se borra. Se puede repetir
cuando se quiera. Al final ejecuta `equipo.sh` si la rama lo trae: lo que sólo
necesita esa máquina.

Fuera del repo, en cada máquina: `~/.config/hypr/hyprpaper.conf` (el fondo) y
lo que escriben los programas junto a su configuración (`fish_variables`,
`lazy-lock.json`). La pantalla de login va aparte: `sudo sddm/install.sh`.

Opcional: `gcalcli` (avisos de Google Calendar), del AUR.
