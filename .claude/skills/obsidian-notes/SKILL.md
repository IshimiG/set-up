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

### Árbol de directorios

```
notes/
├── Books/                           # Resúmenes y análisis de libros
├── ContextIA/                       # Contexto para IA, configuraciones
│   ├── learning/class/arch/         # Configuraciones de Arch/Omarchy
├── Empresa/                         # Notas relacionadas con empresas
├── Languages/Russian/               # Aprendizaje de ruso
├── Learning/                        # Estudios y formación
│   ├── CiberSeguridad/
│   ├── Ciencias/
│   │   ├── Fisica/
│   │   └── Mathematics/            # Matemáticas (00 a 23)
│   ├── Class/
│   │   ├── Bachillerato/
│   │   └── DAW/                    # Ciclo DAW
│   │       ├── 1er/                # Primer año DAW
│   │       │   ├── Data Base/
│   │       │   ├── ED/             # Entornos de Desarrollo
│   │       │   ├── English/
│   │       │   ├── IPE/            # Formación y Orientación
│   │       │   ├── Markup Language/ # HTML, CSS, JS, Angular
│   │       │   ├── Programming/    # Java
│   │       │   ├── Proyecto/       # Proyecto de curso
│   │       │   └── Sistemas/       # Linux, Windows, Docker, Redes
│   │       └── 2do/                # Segundo año DAW
│   │           ├── Arch/
│   │           ├── Desarrollo Web en entorno Servidor/
│   │           ├── Despliegue de Aplicaciones Web/
│   │           ├── IPE/
│   │           └── Proyecto/
│   ├── Piano/                      # Partituras y aprendizaje
│   │   └── Scores/
│   └── Programacion/               # Lenguajes varios
│       ├── C++/
│       ├── C Sharp/
│       ├── Godot/
│       └── Java/
├── MentalHealth/                    # Notas personales de salud mental
├── Projects/                        # Proyectos personales
│   ├── JBH/                        # Suplementos y salud
│   │   └── Suplementos-KB/
│   ├── MACidification/
├── Servidor/                        # Documentación del servidor homelab
│   ├── nh/                         # Notas nuevas del servidor (AQUÍ)
│   │   ├── index.md               # Índice general
│   │   ├── 01-hardware.md         # Hardware Intel NUC
│   │   ├── 02-sistema.md          # SO, kernel, particionado
│   │   ├── 03-red.md              # Red local y VPN
│   │   ├── 04-usuarios.md         # Usuarios y grupos
│   │   ├── 05-ssh.md              # SSH hardening
│   │   ├── 06-wireguard.md        # WireGuard (documentación detallada)
│   │   ├── 07-firewall.md         # nftables
│   │   ├── 08-fail2ban.md         # Fail2ban
│   │   ├── 09-unattended-upgrades.md
│   │   ├── 10-servicios.md        # Servicios activos
│   │   ├── 11-acceso.md           # Guías de conexión
│   │   ├── 12-comandos.md         # Comandos útiles
│   │   └── 13-historial.md        # Historial de cambios
│   └── viejo/                      # Notas antiguas del servidor
├── That's me/                       # Diario personal, assessments, hábitos
│   ├── Assessment/
│   ├── hardware/
│   ├── Illuminations/
│   ├── Journal/
│   │   ├── Habit/
│   │   └── Reminder/
│   └── notes/
│       ├── Oldones/
│       └── People/
├── Work/                            # Trabajo
│   ├── Exaequatio/
│   ├── JJ/
│   ├── Pizzeria Oceanografic/
├── zHiden/                          # Notas ocultas/templates
│   └── Templates/
```

## Reglas para crear notas

1. **Todas las notas se crean dentro de `/home/ishimimain/Documents/notes/`**
2. Usar formato Markdown con extensión `.md`
3. Si el usuario no especifica la carpeta, preguntar o inferir por contexto
4. Para el servidor homelab, usar `Servidor/nh/`. Actualizar `index.md` si se añade un archivo nuevo. WireGuard tiene documentación detallada en `06-wireguard.md`.
5. Para proyectos personales, usar `Projects/<nombre-proyecto>/`
6. Para estudio DAW, usar `Learning/Class/DAW/<curso>/<asignatura>/`
7. Para notas personales, usar `That's me/`
8. Preferir nombres de archivo descriptivos, en español o inglés según el contexto

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
