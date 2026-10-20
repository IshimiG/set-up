# set-up: reglas para Claude Code

El escritorio Hyprland + Quickshell de todas las máquinas del usuario (la torre,
el portátil y cualquier otro equipo que se añada). La estructura, en el README.

## Todo cambio del escritorio se guarda aquí

Regla del usuario (2026-10-12): **cualquier cambio en el escritorio de cualquier
máquina se añade a este repo y se sube**. Nada se queda sólo en el `~/.config`
de una máquina.

- Lo que vale para todas va en lo común (`main`, a través de la rama `general` y
  su PR). Lo de un solo equipo va en su rama (`setup/torre`, `setup/portatil`),
  en los ficheros que sólo existen allí: `.config/hypr/equipo.lua`,
  `.config/quickshell/bar/equipo/`, `.config/ghostty/equipo.ghostty`,
  `.local/bin/actualizar-equipo`, `equipo.sh`. Lo común nunca nombra nada de un
  equipo.
- Si el cambio necesita un paquete, un enlace o un servicio, también va en
  `setup.sh` (lo común) o en el `equipo.sh` de la rama, para que `setup.sh` deje
  cualquier máquina igual. `setup.sh --comprobar` en las dos máquinas tiene que
  salir limpio después del cambio.
- Después de un cambio común: `git merge general` (o `main`) en cada rama de
  equipo y `git pull` en cada máquina, que tienen `~/.config` enlazado al repo.
- Antes de cada commit, `git fetch` y comprobar que todo está bien. Los commits
  van en español, como el resto del repo.
- La terminal (Ghostty: Horizon con los colores de caelestia, `#131317` al 85 %,
  Noto Sans Mono) la eligió el usuario: no se cambia sin preguntar.
- Se documenta en el vault, en `30 Áreas/Escritorio/set-up-comun-y-por-equipo.md`.
