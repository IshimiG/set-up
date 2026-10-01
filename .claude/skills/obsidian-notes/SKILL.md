---
name: obsidian-notes
description: >
  Gestión de notas en Obsidian. Se activa cuando el usuario menciona
  "obsidian", "notas", "nota", "apuntes", "documentación". Conoce la
  estructura completa del vault de Obsidian en ~/Documents/notes/ y
  sabe dónde crear y organizar archivos .md.
license: MIT
compatibility: opencode
metadata:
  vault: "/home/ishimimain/Documents/notes"
---

## Estructura del Vault de Obsidian

La raíz es `/home/ishimimain/Documents/notes/`. Toda nota nueva debe crearse dentro de esta jerarquía.

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

1. **Todas las notas se crean dentro de `/home/ishimimain/Documents/notes/`**
2. Usar formato Markdown con extensión `.md`
3. Si el usuario no especifica la carpeta, preguntar o inferir por contexto
4. Para el servidor homelab, usar `30 Áreas/Servidor/`. Actualizar `index.md` si se añade un archivo nuevo y apuntar los cambios en `13-historial.md`.
5. Para proyectos personales, usar `10 Proyectos/<nombre-proyecto>/`; una idea suelta, `10 Proyectos/Ideas/`. Si no está claro dónde va, `01 Bandeja/`
6. Para trabajo (empleos, clientes, encargos), usar `20 Trabajo/`
7. Para estudio DAW, usar `40 Aprendizaje/Clase/DAW/<curso>/<asignatura>/`; la estructura de DAW y Bachillerato por asignaturas es del usuario y no se reorganiza
8. Lo que ya no está vigente no se borra: se mueve a `90 Archivo/` con un aviso arriba diciendo de qué época es y dónde está lo actual
9. Al mover notas fuera de Obsidian (con `git mv`), reescribir los enlaces con ruta (`[[Carpeta/nota]]`) y comprobar que no queda ninguno roto; dentro de Obsidian se actualizan solos
10. Preferir nombres de archivo descriptivos, en español o inglés según el contexto

## Carpetas prohibidas

Dos carpetas del vault **no se leen, ni se editan, ni se listan**, bajo ningún
concepto y por ningún motivo:

- `~/Documents/notes/MentalHealth`
- `~/Documents/notes/That's me`

No se proponen como destino de una nota nueva ni se incluyen en búsquedas.

## El vault es un repositorio git: fetch antes, commit después

`~/Documents/notes` es un repositorio git (`origin` en
`git@github.com:IshimiG/notes.git`, rama `main`) que también se edita desde
otros dispositivos, por ejemplo desde la app de Obsidian sincronizando contra
GitHub. El orden importa y no es negociable:

1. **Antes de tocar nada**, `git fetch` y poner la rama local al día
   (`git pull`, o `git fetch && git merge origin/main`). Saltarse este paso es
   arriesgarse a un conflicto o a pisar cambios hechos en otro sitio.
2. Hacer el cambio.
3. **Comprobar que está bien** antes de dar nada por terminado: que lo que se
   documenta se corresponde con la realidad, que el enlace o la ruta existe,
   que lo que se ha construido funciona de verdad.
4. `git commit` con un mensaje que explique qué cambió, **sin esperar a que lo
   pidan**.
5. `git push` a `origin`, porque un cambio sin publicar es exactamente la
   pérdida contra la que esto protege.

**Trabajos de varios pasos (desde el 2026-10-01): rama y PR, `main` limpio.**
Cuando el trabajo en el vault tiene varios pasos (por ejemplo, una
reorganización), no se llena `main` de commits. Se trabaja en una rama
(`vault/<tema>`, creada desde `main` recién actualizado); **dentro de la rama se
hacen todos los commits que haga falta** y se suben (`git push`) para no perder
nada. Se abre una **pull request** contra `main` con `gh pr create` y, al
terminar, el usuario la fusiona con *squash*, de modo que en `main` queda un
solo commit. `main` no se toca hasta entonces. Fetch antes de empezar (y
rebasar la rama sobre `origin/main` si avanzó) y comprobar que todo está bien
siguen valiendo. Un cambio suelto y pequeño sigue el flujo de arriba.

**La configuración de Obsidian (`.obsidian/`) está en git** (plugins, ajustes,
temas), para que todos los dispositivos tengan lo mismo. Quedan fuera solo los
ficheros de estado de cada dispositivo (`workspace.json`,
`workspace-mobile.json`, `workspaces.json`, `cache`), que cambian en cada
arranque y provocarían conflictos. Obsidian reescribe su configuración desde
memoria: si se edita un fichero de `.obsidian/` con Obsidian abierto, el usuario
tiene que recargar (`Ctrl+P` → «Reload app without saving») para que lo lea.

Si el fetch saca a la luz un conflicto de verdad (no un avance rápido), **hay
que parar y decirlo**, no resolverlo por cuenta propia: significa que las notas
divergieron de una forma que necesita una decisión humana.

> Esta regla no es sólo del vault. En **cualquier** repositorio de esta máquina
> —`~/Projects/set-up` incluido— se hace `fetch` y se comprueba que todo está
> bien *antes* de hacer commit, no después. Lo que sí es exclusivo del vault es
> el `push` automático: en los demás repos no se publica nada sin pedirlo.

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
