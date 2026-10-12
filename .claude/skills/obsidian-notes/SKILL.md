---
name: obsidian-notes
description: >
  Gestión de notas en Obsidian. Se activa cuando el usuario menciona
  "obsidian", "notas", "nota", "apuntes", "documentación". Conoce la
  estructura completa del vault de Obsidian en ~/Notes/ y
  sabe dónde crear y organizar archivos .md.
license: MIT
compatibility: opencode
metadata:
  vault: "/home/ishimimain/Notes"
---

## Estructura del Vault de Obsidian

La raíz es `/home/ishimimain/Notes/` (desde el 2026-10-07; antes, `~/Documents/notes`). Toda nota nueva debe crearse dentro de esta jerarquía.

Desde el 2026-10-01 el vault está organizado con carpetas numeradas (PARA:
proyectos, áreas, recursos, archivo). La estructura, el porqué y las
convenciones están en `99 Sistema/Organización del vault.md`.

### Árbol de directorios

```
notes/
├── 00 Inicio.md                 # Página principal (se abre al arrancar; plugin Homepage)
├── 01 Bandeja/                  # Lo que entra sin sitio; las notas nuevas se crean aquí por defecto
├── 10 Proyectos/                # Cosas con final
│   ├── 00 - Index.md
│   ├── ListacAI/ · JBH/ (Supplementum, Suplementos-KB) · MACidification/
│   └── Ideas/                   # Assatio, Exaequatio, IA Apuntes, Temperamentum, Godot…
├── 20 Trabajo/                  # Registro de todo el trabajo hecho
│   ├── 00 - Index.md
│   ├── Empleos/                 # Adding Technology (actual), Pizzeria Oceanografic (anterior)
│   ├── Clientes/                # Encargos: JJ (autorizaciones AAI, SGS), Alfredo
│   ├── Shinobi Innovations/ · Exaequatio/
│   ├── Empresa/                 # La empresa propia futura
│   └── Yo/                      # Rutina, quién soy, From 0 to 1k
├── 30 Áreas/                    # Lo que se mantiene, sin final
│   ├── 00 - Index.md
│   ├── Servidor/                # Documentación del homelab NUC (antes Servidor/nh)
│   │   ├── index.md             # Índice: actualizarlo al añadir una nota
│   │   ├── 01-hardware.md … 21-cloudflare-tunnel.md
│   │   ├── 13-historial.md      # Registro de cambios del servidor
│   │   ├── 19-panel-homelab.md  # Plan del panel de Docker
│   │   └── 22-ecosistema.md     # Mapa del ecosistema personal (todos los bloques)
│   ├── Escritorio/              # CachyOS + Hyprland: escritorio-torre, atajos-de-teclado, docker-en-cachyos, mirroring-movil
│   └── IA/                      # Contexto para IA: me.md, skills-de-la-torre, documentacion
├── 40 Aprendizaje/              # Todo lo estudiado
│   ├── 00 - Index.md
│   ├── Clase/                   # DAW (1er, 2do, con sus asignaturas) y Bachillerato: estructura del usuario, no reordenar
│   ├── Ciencias/                # Fisica, Mathematics (00 a 23)
│   ├── Programación/            # C++, C Sharp, Godot, Java, Python
│   ├── Docker/ · Ciberseguridad/ · Piano/
│   ├── Idiomas/                 # Russian
│   └── Libros/                  # Resúmenes de libros, con 00 - Index
├── 90 Archivo/                  # Notas de etapas anteriores, cada una con aviso de su época
│   ├── 00 - Index.md
│   ├── Homelab antiguo/         # Planes de mayo–julio 2026 (pfSense, AdGuard, RAG, n8n)
│   ├── Escritorio Omarchy/
│   └── Varios/
├── 99 Sistema/
│   ├── Organización del vault.md
│   ├── Plantillas/              # Carpeta de plantillas de Obsidian
│   └── Adjuntos/                # Imágenes y PDF; Obsidian guarda aquí lo pegado
├── MentalHealth/                # PROHIBIDA (ver abajo)
└── That's me/                   # PROHIBIDA (ver abajo); las notas diarias del usuario van a That's me/Journal
```

Propiedades que usa la página de inicio (solo en las notas principales):
`nombre`, `tipo` (proyecto | area | cliente | libro | guia | idea),
`estado` (activo | pausado | idea | hecho | archivado) y `actualizado` (fecha).

## Reglas para crear notas

1. **Todas las notas se crean dentro de `/home/ishimimain/Notes/`**
2. Usar formato Markdown con extensión `.md`
3. Si el usuario no especifica la carpeta, preguntar o inferir por contexto
4. Para el servidor homelab, usar `30 Áreas/Servidor/`. Actualizar `index.md` si se añade un archivo nuevo y apuntar los cambios en `13-historial.md`.
5. Para proyectos personales, usar `10 Proyectos/<nombre-proyecto>/`; una idea suelta, `10 Proyectos/Ideas/`. Si no está claro dónde va, `01 Bandeja/`
6. Para trabajo (empleos, clientes, encargos), usar `20 Trabajo/`
7. Para estudio DAW, usar `40 Aprendizaje/Clase/DAW/<curso>/<asignatura>/`; la estructura de DAW y Bachillerato por asignaturas es del usuario y no se reorganiza
   - Desde el 2026-10-05 el homelab es una extensión de las notas: lo nuevo de clase (Aules y los apuntes que pase el usuario) lo trae el bloque `personal/clase` del repo `~/Projects/homelab` y se **añade** a `Clase/`; las notas que ya existen ahí **no se tocan**. Detalle en `30 Áreas/Servidor/23-personal-clase.md`
8. Lo que ya no está vigente no se borra: se mueve a `90 Archivo/` con un aviso arriba diciendo de qué época es y dónde está lo actual
9. Al mover notas fuera de Obsidian (con `mv`), reescribir los enlaces con ruta (`[[Carpeta/nota]]`) y comprobar que no queda ninguno roto; dentro de Obsidian se actualizan solos
10. Preferir nombres de archivo descriptivos, en español o inglés según el contexto

## Carpetas prohibidas

Dos carpetas del vault **no se leen, ni se editan, ni se listan**, bajo ningún
concepto y por ningún motivo:

- `~/Notes/MentalHealth`
- `~/Notes/That's me`

No se proponen como destino de una nota nueva ni se incluyen en búsquedas. Lo
mismo vale para sus copias: en el NUC (`/srv/sync/notes/…`) y en el vault viejo
archivado (`~/.local/share/notes-git-archive/`, bloqueado entero). En la torre, los
permisos deniegan cualquier comando que las nombre, así que no se lanzan comandos
recursivos sobre la raíz del vault: se trabaja dentro de la carpeta concreta. En el
NUC no hay permisos ni *sandbox* que lo impidan, así que todo comando recursivo
sobre `/srv/sync/notes` (`find`, `grep -r`, `du`, `rsync`…) las excluye a mano
(`-prune`, `--exclude-dir`).

## El vault se sincroniza con Syncthing; git solo en el NUC

Desde el 2026-10-07, `~/Notes` **no es un repositorio git**. Es una carpeta de
Syncthing (ID `notes`) que se sincroniza en vivo con el NUC (`/srv/sync/notes`),
que es el centro y la fuente de verdad, y desde allí con el portátil y el móvil.
Se acabaron en el vault `git pull`, las ramas `vault/<tema>` y las PR. El plan y
el porqué están en `30 Áreas/Servidor/31-plan-syncthing-y-copias.md`.

1. **Antes de tocar nada**, comprobar que Syncthing tiene la carpeta al día y
   sin conflictos:
   ```sh
   key=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' ~/.local/state/syncthing/config.xml)
   curl -s -H "X-API-Key: $key" 'http://127.0.0.1:8384/rest/db/status?folder=notes'
   ```
   Tiene que salir `"state": "idle"` y `"needFiles": 0`. No se rastrea el vault
   buscando conflictos: los permisos deniegan cualquier comando que nombre las
   carpetas prohibidas, aunque sea para excluirlas. Los conflictos salen en el
   mensaje del commit automático del NUC.
2. Hacer el cambio. Syncthing lo lleva al NUC en unos segundos.
3. **Comprobar que está bien** antes de dar nada por terminado: que lo que se
   documenta se corresponde con la realidad, que el enlace o la ruta existe,
   que lo que se ha construido funciona de verdad.
4. **El commit lo hace el NUC.** `vault-snapshot` lo hace solo a las 03:00 y a las
   15:00. Al terminar un trabajo, se deja un commit con nombre. El mensaje (asunto,
   cuerpo y los *trailers* de atribución, en inglés) se escribe en un fichero
   temporal y se pasa por la entrada estándar, que es lo seguro por SSH:
   ```sh
   ssh lab@192.168.1.174 vault-commit - < /ruta/al/mensaje.txt
   ```
   Espera a que Syncthing esté en reposo, hace commit de **todo** lo pendiente en el
   vault y lo sube a GitHub. Si el push falla, sale con código 3 y el commit se queda
   para la siguiente pasada. Antes de hacer commit, comprueba que la torre está al
   día (paso 1), para que tus cambios ya estén en el NUC.

Nunca se crea un `.git` dentro de `~/Notes`: un repositorio que se sincroniza en
vivo entre máquinas se corrompe.

**La configuración de Obsidian (`.obsidian/`) también se sincroniza** (plugins,
ajustes, temas), para que todos los dispositivos tengan lo mismo. Quedan fuera
solo los ficheros de estado de cada dispositivo: `workspace.json`,
`workspace-mobile.json`, `workspaces.json`, `cache` y `graph.json`. Están en
`.stignore-shared`, en la raíz del vault, que todos los `.stignore` incluyen.
Obsidian reescribe su configuración desde memoria: si se edita un fichero de
`.obsidian/` con Obsidian abierto, el usuario tiene que recargar (`Ctrl+P` →
«Reload app without saving») para que lo lea.

Si aparece un `*.sync-conflict-*` (la misma nota cambiada en dos sitios antes de
sincronizarse), en el commit del NUC o en una carpeta en la que se está
trabajando, **hay que parar y decirlo**, no resolverlo por cuenta propia.

> La regla de hacer `fetch` y comprobar que todo está bien *antes* de hacer commit
> sigue valiendo en **cualquier** otro repositorio de esta máquina, `~/Projects/set-up`
> incluido. En esos repos no se publica nada sin pedirlo.

## Documentar es parte del trabajo, no un extra

Todo lo que se construya o se cambie en esta máquina —configuración del
escritorio, scripts, servicios, herramientas— se escribe en el vault como parte
del mismo trabajo, no cuando alguien lo pide. El texto es para leerlo meses
después sin la conversación delante: nombra las rutas reales de los ficheros y
explica **por qué** se hizo así, no sólo qué se tocó.

Las notas existentes envejecen. Cuando una describe una época anterior del mismo
sistema, se escribe el estado actual y se deja un aviso en la vieja diciendo a
qué periodo corresponde, en vez de dejar que alguien se fíe de algo que ya no es
cierto.
