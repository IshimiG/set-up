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
  aviso de actualizaciones, `tema.sh` y `aberracion.sh` (ver [Temas](#temas))
  y `paquetes.sh` (lista los paquetes instalados a
  propósito y los desinstala con `sudo pacman -Rns`; se niega con los
  protegidos: núcleo, arranque, pacman, sudo, Hyprland, Quickshell, Ghostty…).
- `.config/ghostty/config.ghostty`: la terminal, con el mismo cristal (y
  `temas/`, sus fragmentos por tema).
- `.config/fish/`: fish, la shell de todas las máquinas: Starship, zoxide, eza,
  las abreviaturas de git, el saludo y `ms` (SSH al homelab).
- `.config/nvim/`: Neovim con LazyVim, el tema Horizon con el fondo transparente
  y los lenguajes que se usan (TypeScript, SQL, Docker, Java, Angular…).
- `.config/quickshell/`: `bar` (barra, isla, notificaciones, el menú de sesión
  con «Desinstalar», que cambia la isla a un panel de paquetes con buscador,
  selección múltiple y confirmación, y abre la terminal con `paquetes.sh`;
  también por IPC: `qs -c bar ipc call bar togglePaquetes`; y el calendario,
  que marca las tareas con fecha y las entregas de Aules: se las deja el cajón
  del homelab en `$XDG_RUNTIME_DIR/escritorio-agenda.json`; con el panel al
  alcance, una hoja crea una tarea con doble clic en un día y la edita al
  pulsar su título: título, todo el día o de una hora a otra, prioridad y
  🚫🤖; la hoja de editar tiene «Eliminar», con confirmación de dos pulsaciones
  y sin él en las tareas de Aules. Cada fila de la lista del día lleva una
  barrita con el color de su categoría (la sección de la tarea; «Clase», en un
  violeta fijo, para Aules) y a la derecha el nombre de esa categoría; el punto
  es la prioridad), `launcher`
  (SUPER+SPACE), `reminder` (SUPER+R), `temas` (SUPER+SHIFT+T, el selector de tema), `updates`, `homelab` (el panel del
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
  `[[enlaces]]` navegables y atrás y adelante) y `shared` (la paleta, con los
  temas: ver [Temas](#temas)).
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
  `CalendarPanel.qml` con sus puntos, la lista del día, los clics y la hoja
  de crear, editar, eliminar tareas y el color por categoría (`--guardar` deja las capturas). Levanta un panel
  falso (`panel-falso.py`, con las horas, el color de cada sección y el
  borrado del contrato de `/api/tareas`), así que necesita `python3`.
- `pruebas/temas/panel.sh`: prueba sin pantalla del selector de tema, en los
  dos temas (carga, lista, marca el activo, ↑/↓, Enter, clic y Escape, sin
  ejecutar el `tema.sh` real; `--guardar` deja las capturas).
- `pruebas/updates/prueba.sh`: prueba sin pantalla del aviso de
  actualizaciones: que la máscara de clics cubre la tarjeta entera (los dos
  botones, no sólo su canto de arriba), el cristal, la flecha de esconder, la
  pestaña y los botones «Más tarde» y «Actualizar ahora», sin lanzar ninguna
  terminal (`--guardar` deja las capturas).
- `pruebas/paquetes/`: `script.sh` prueba `paquetes.sh` con un `pacman -Qie`
  falso (campos, AUR, protegidos, requeridos) y `desinstalar` con
  `PAQUETES_PACMAN=echo`, y lee la lista real sólo para contarla. `prueba.sh`
  prueba sin pantalla el panel de paquetes y la isla de verdad con él: carga,
  buscador, teclado, clics en toda la fila, protegidos, confirmación, la orden
  exacta de la terminal, el reinicio al cerrar y el estado de error, con
  ghostty, pacman y sudo de mentira en el `PATH` (`--guardar` deja las
  capturas). Ninguna desinstala nada.
- `pruebas/temas/prueba.sh`: prueba sin pantalla de los temas: `tema.sh` (con
  un `$XDG_STATE_HOME` de prueba), `tema.sh` y `aberracion.sh` en una sesión
  de mentira (`hyprctl`, `notify-send` y `sleep` falsos: recarga, aviso, el
  demonio que pulsa, no se duplica y se para), `aberracion.sh --en-seco` con
  sus tiempos, `hyprland.lua` con un Hyprland de mentira
  (`hypr-simulado.lua`: default da los valores de siempre y los dos temas las
  mismas claves, y liquido con las mismas medidas) y con `Hyprland
  --verify-config`, los fragmentos de Ghostty (`ghostty +validate-config`, colores
  iguales a default), hyprlock (sus variables) y Neovim (`nvim --headless`
  en cada tema, siempre Horizon), y `shared/Theme.qml` con `qs`, en caliente y al arrancar. Necesita `qs` y `lua` (`--guardar` deja
  los registros).

## Temas

El escritorio tiene temas intercambiables:

- `default`: el de siempre, cristal negro esmerilado con un filo blanco.
- `liquido`: cristal neutro y translúcido, a la manera del Liquid Glass de
  iOS 26: el fondo colorido se transparenta y no hay colores en el cristal. Cambia
  el material de TODO el escritorio, no las medidas: huecos, grosor del borde,
  redondeo, tamaño de letra y márgenes son los de `default`. Por componente:
  - Quickshell: láminas de cristal translúcidas con canto fino blanco
    (`shared/Theme.qml`).
  - Hyprland: borde activo blanco con alfa (neutro), inactivo blanco tenue,
    blur con mucha vibrancy (0,8) y contraste y brillo neutros (1,0) para que
    los colores del fondo traspasen sin oscurecer ni emblanquecer, sombra
    neutra. El único color es la aberración cromática: franjas roja `#ff3b6b`
    y cian `#3be8ff` en el borde, sólo durante los pulsos aleatorios.
  - Ghostty: los mismos colores que `default`, sólo más translúcida (0,70 en
    vez de 0,85) (`.config/ghostty/temas/liquido.ghostty`).
  - hyprlock: fondo desenfocado más vivo y campo de contraseña con borde
    blanco translúcido (`.config/hypr/temas/hyprlock-liquido.conf`).
  - Neovim: no depende del tema (Horizon transparente en los dos).
  - SDDM no cambia con el tema (instalarlo pide sudo: `sddm/install.sh`).

### Cambiar de tema

SUPER+SHIFT+T abre el selector (`quickshell/temas`: una tarjeta con los
temas, su vista previa y el activo marcado; ↑/↓ y Enter, o un clic; Escape
cierra) y SUPER+SHIFT+CTRL+T alterna sin abrirlo. Desde la terminal:

```sh
~/.config/hypr/scripts/tema.sh            # el activo
~/.config/hypr/scripts/tema.sh lista      # los que hay; el activo, con *
~/.config/hypr/scripts/tema.sh liquido    # o default
~/.config/hypr/scripts/tema.sh alternar   # el siguiente de la lista
```

El tema activo es una palabra en `${XDG_STATE_HOME:-~/.local/state}/escritorio/tema`,
de cada máquina: no va en el repo. Si falta o dice algo que no es un tema,
vale `default`. `tema.sh` lo escribe de una vez (un temporal que renombra
encima) y, dentro de la sesión:

1. Para la aberración cromática si estaba en marcha.
2. `hyprctl reload config-only`: `hyprland.lua` vuelve a leer el tema y pone
   el borde, el redondeo, la sombra, el blur, los huecos, la velocidad del
   borde y el `ignore_alpha` de las superficies de Quickshell de ese tema.
3. Arranca la aberración si el tema la tiene.
4. Avisa con una notificación.

Y `tema.sh` deja en esa misma carpeta los fragmentos del tema para lo que no
sabe leer la palabra (los copia del repo; `tema.sh aplicar` los vuelve a
copiar sin cambiar nada, y `setup.sh` lo hace):

- `ghostty-tema`: lo incluye `config.ghostty` con `config-file = ?~/.local/state/escritorio/ghostty-tema`
  (opcional: sin él, Ghostty es el de `default`), antes de `equipo.ghostty`,
  que sigue mandando. `tema.sh` recarga las terminales abiertas con la acción
  `reload-config` de Ghostty por D-Bus (`gdbus`), sin señales ni matar nada;
  si no se recargara alguna, basta con abrir una nueva. El fragmento de
  `default` está vacío: la terminal es la de `config.ghostty`.
- `hyprlock-tema.conf`: lo lee `hyprlock.conf` con `source` y redefine las
  variables de color y blur (`$campo_borde`, `$fondo_pasadas`…) que éste trae
  con los valores de `default`. Se aplica la próxima vez que se bloquea.

Neovim no usa nada de esto: Horizon en los dos temas.

Quickshell no necesita nada: `shared/Theme.qml` vigila el fichero y la
barra, la isla, el cajón del homelab y lo demás cambian en caliente. Fuera
de una sesión, `tema.sh` sólo escribe el estado, que vale al entrar. La
carpeta la crea `setup.sh` (paso 3); si Quickshell arrancó cuando no
existía, no ve el primer cambio hasta que se reinicia (tema.sh lo avisa).

### Aberración cromática

Sólo en `liquido`. Hyprland no tiene aberración cromática en los bordes, así
que es el mismo borde en degradado con una franja roja y otra cian a los
lados del blanco, puesto a pulsos por `scripts/aberracion.sh`: cada 4 a 25 s
al azar, y cuatro de cada diez veces nada; cada pulso dura de 150 a 600 ms,
con uno o dos parpadeos (el segundo con las franjas al revés), y vuelve al
borde normal. Los colores están en `hyprland.lua` (`temas.liquido.aberracion`)
y el demonio los pone con `hyprctl eval 'escritorio.aberracion(n)'` (`hyprctl
keyword` no funciona con la configuración en Lua; 0 es el borde normal).

Arranca con la sesión si el tema es `liquido` y lo arranca y para `tema.sh`;
se para solo en cuanto el tema deja de ser `liquido` y no se duplica (cerrojo
con el PID en `$XDG_RUNTIME_DIR/escritorio-aberracion.lock`). Para apagarlo:
`ABERRACION=0` en el entorno (en una máquina, `hl.env("ABERRACION", "0")` en
su `equipo.lua`), o pararlo a mano con `aberracion.sh --parar`.
`aberracion.sh --en-seco` no toca nada: imprime las órdenes y las esperas
(`ABERRACION_TURNOS` y `ABERRACION_SEMILLA` lo hacen corto y repetible).
`--parar` espera a que el demonio recién arrancado escriba su PID, éste
instala su `trap` antes de escribirlo y, si sale solo porque el tema ya no es
`liquido`, también deja el borde normal: así tema.sh nunca recarga con un
borde de aberración puesto.

### El contrato de `Theme`

Todos los QML usan la paleta por `Theme.<propiedad>`; las de la tabla
cambian con el tema, en caliente. Lo que no está en la tabla (las
prioridades y `colorPrioridad`, `font`, `cardWidth`, `pad`, `gap`, `dropTop`,
`dropSide`, `slideRoom`, `minTimeout` y `timeoutFor`) es igual en todos.

| Propiedad | Tipo | `default` | `liquido` | Qué es |
|---|---|---|---|---|
| `nombreTema` | string | `"default"` | `"liquido"` | El tema activo |
| `liquido` | bool | `false` | `true` | Atajo para `nombreTema === "liquido"` |
| `temas` | var | `["default", "liquido"]` | igual | Los que hay |
| `rutaEstado` | string | `…/escritorio/tema` | igual | El fichero que se vigila |
| `glassTop`, `glassBottom` | color | negro al 0,76 / 0,64 | blanco azulado al 0,34 / 0,26 | El cuerpo, en degradado |
| `glassClear` | color | negro al 0,64 | blanco azulado al 0,18 | Variante *clear*: sobre algo con mucho color, con el texto en `strong` |
| `glassDense` | color | negro al 0,92 | pizarra fría al 0,90 | Lo que flota sobre el contenido: casi opaco, nunca cristal |
| `ignoreAlpha` | real | 0,5 | 0,15 | El `ignore_alpha` de `hyprland.lua` en el tema |
| `edgeTop`, `edgeBottom` | color | blanco al 0,30 / 0,08 | blanco al 0,55 / 0,14 | El canto |
| `bordeAnchura` | real | 1 | 1,5 | El grueso del canto |
| `specular` | color | transparente | blanco al 0,30 | El brillo de la cara, de arriba hacia abajo |
| `specularHeight` | real (0-1) | 0 | 0,33 | Lo que cubre ese brillo |
| `tint` | color | transparente | azul al 0,08 | Tinte sobre el cuerpo |
| `shadowColor` | color | transparente | azul noche al 0,35 | La sombra de la lámina |
| `shadowRadius` | real | 0 | 24 | Su difuminado |
| `aberracion` | bool | `false` | `true` | Si el tema tiene aberración cromática |
| `franjaRoja`, `franjaCian` | color | transparente | `#ff3b6b`, `#3be8ff` al 0,6 | Sus colores, los del borde de Hyprland |
| `text` | color | blanco al 0,78 | blanco | Texto |
| `strong` | color | blanco | blanco | Texto que manda |
| `muted`, `faint` | color | blanco al 0,55 / 0,35 | blanco al 0,75 / 0,52 | Atenuados |
| `rule` | color | blanco al 0,12 | blanco al 0,22 | Separadores |
| `accent` | color | blanco | blanco | Resalte |
| `ok`, `warn`, `danger` | color | `#6dc89e`, `#e59625`, `#e90b25` | `#30d158`, `#ff9f0a`, `#ff453a` | Estados |
| `radius` | int | 16 | 24 | Radio de una lámina |
| `radiusSmall` | int | 8 | 14 | Radio de lo de dentro (botón, campo, fila) |
| `radiusPill` | int | 999 | 999 | Cápsula |
| `animIn`, `animOut` | int (ms) | 420, 300 | 460, 300 | Duración de entrar y salir |
| `overshootIn`, `overshootOut` | real | 1,9, 1,5 | 1,5, 1,3 | Rebote de entrar y salir |

Reglas de cualquier tema, traducidas del Liquid Glass:

- El cristal es para la capa de navegación (la barra, la isla, el cajón, el
  lanzador, los avisos), nunca para el contenido.
- El cristal no se pone encima de otro cristal: lo que flota sobre una
  lámina va en `glassDense`.
- El alfa del cristal va por encima de `ignoreAlpha` (si no, Hyprland no lo
  desenfoca), y lo que no deba desenfocarse, por debajo: en `liquido`, el velo
  del lanzador (0,32) también se desenfoca.
- `default` es exactamente lo de antes de haber temas: lo comprueba
  `pruebas/temas/prueba.sh`.

### Añadir un tema

1. `shared/Theme.qml`: una `Paleta { id: paletaX; nombre: "x" … }` con sólo
   lo que cambia (lo demás sale de `default`), metida en `paletas`.
2. `hyprland.lua`: su tabla en `temas`, con las mismas claves que `default`
   (la prueba lo exige; así al volver de un tema no se queda nada puesto).
   Con `aberracion` (una lista de bordes) tiene aberración, y entonces su
   nombre va también en `CON_ABERRACION` de `scripts/aberracion.sh`.
3. `scripts/tema.sh`: su nombre en `TEMAS`, que es el orden de `lista` y de
   `alternar`.
4. `pruebas/temas/`: lo que el tema nuevo no pueda romper.

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
(así un `git pull` se nota al momento), crea la carpeta del tema
(`~/.local/state/escritorio`, ver [Temas](#temas); el tema no lo toca),
descarga el fondo si la máquina no
tiene `~/.config/hypr/hyprpaper.conf`, activa los servicios de usuario, ajusta
la memoria y pone fish como shell. De la memoria se ocupan tres cosas: earlyoom
(si se agota la RAM mata antes el navegador y las apps Electron que Hyprland;
`/etc/default/earlyoom`), `/etc/sysctl.d/99-zram.conf` (swappiness 180 y el
resto de valores de la Arch Wiki para zram, sólo si la máquina usa zram) y
`.config/zen/user.js`, que se enlaza en el perfil por defecto de Zen (procesos
de contenido, descarga de pestañas, cachés; sin tocar `prefs.js`) y vale al
reiniciar Zen. Lo que hubiera en el sitio de un enlace se aparta a
`~/.local/share/set-up-apartado/<fecha>/`, no se borra. Se puede repetir
cuando se quiera. Al final ejecuta `equipo.sh` si la rama lo trae: lo que sólo
necesita esa máquina.

Fuera del repo, en cada máquina: `~/.config/hypr/hyprpaper.conf` (el fondo) y
lo que escriben los programas junto a su configuración (`fish_variables`,
`lazy-lock.json`). La pantalla de login va aparte: `sudo sddm/install.sh`.

Opcional: `gcalcli` (avisos de Google Calendar), del AUR.
