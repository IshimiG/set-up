import QtQuick

// Una Api.qml falsa para la prueba: cumple el contrato de las fases 2, 3 y 4
// entero (propiedades, señales y funciones) con datos inventados. La prueba
// cambia las propiedades a mano, y las llamadas a refrescar/marcarVista, las
// escrituras de tareas, hábitos, Aules y proyectos, y las acciones de Docker
// quedan apuntadas.
//
// Las tareas, los hábitos y Aules son un «servidor» de mentira con estado: una
// escritura cambia el documento, le pone otra versión y contesta con la lista
// nueva, como el NUC (los id llevan la línea y un contador, así que cambian al
// escribir). Con conflictoPendiente, la próxima escritura es un 409: cambia
// algo «desde fuera», recarga y avisa sin escribir nada.
QtObject {
    id: api

    property string conexion: "conectado"
    property string usuario: "portatil"
    property var permisos: ({
            acciones_docker: true,
            login_traderepublic: true
        })
    property var alertas: [
        {
            id: "a1",
            nivel: "error",
            titulo: "Contenedor caído: caddy",
            detalle: "caddy lleva 3 minutos parado",
            desde: new Date(Date.now() - 12 * 60000),
            vista: false,
            // Su línea del Registro, en la segunda página (fase 4).
            entrada: 1
        },
        {
            id: "a2",
            nivel: "warn",
            titulo: "Disco al 85 % en /srv",
            detalle: "Quedan 40 GB libres",
            desde: new Date(Date.now() - 3 * 3600000),
            vista: false,
            entrada: 7
        },
        {
            id: "a3",
            nivel: "warn",
            titulo: "Copia de seguridad lenta",
            detalle: "",
            desde: new Date(Date.now() - 2 * 86400000),
            vista: true,
            entrada: 0
        }
    ]
    property string nivelAlertas: "error"
    property var servidor: ({
            enMarcha: 8,
            total: 9,
            problemas: 1
        })
    // Las tareas de Inicio salen del «servidor» de tareas de abajo (publicar),
    // como en Api.qml, para que marcarlas desde Inicio cambie lo que se ve.
    property var inicio: ({
            hoy: "martes 20 de octubre",
            semana: "semana 43",
            metaPorcentaje: 34,
            tareas: []
        })
    property var inicioCargado: new Date()
    property string error: ""
    property string baseUrl: "https://panel.prueba.invalid"

    signal alertaNueva(var alerta)

    // Lo que ha pasado, para que la prueba lo mire.
    property int refrescos: 0
    property var vistas: []
    property var abiertas: []

    function refrescar() {
        api.refrescos++;
    }

    function marcarVista(id) {
        api.vistas = api.vistas.concat([id]);
    }

    function urlWeb(ruta) {
        return api.baseUrl + "/" + ruta;
    }


    // --- Fase 3 ---------------------------------------------------------------

    signal aviso(string texto, bool error)

    property var tareas: null
    property var tareasCargadas: null
    property string tareasError: ""
    property bool tareasOcupado: false
    property bool editandoTarea: false
    property bool tareasObsoletas: false
    property var habitos: null
    property var clase: null

    // Lo que ha pasado.
    property var escrituras: []
    property int lecturasTareas: 0
    property int lecturasHabitos: 0
    property int lecturasClase: 0
    property bool conflictoPendiente: false

    // El «servidor»: secciones con sus tareas tal como están en la nota.
    property var doc: ({})
    property int version: 1
    property string versionCargada: ""
    property int contador: 1
    readonly property string hoy: "2026-10-20"

    function fecha(dias) {
        const d = new Date(Date.UTC(2026, 9, 20 + dias));
        return d.toISOString().slice(0, 10);
    }

    function nueva(texto, prioridad, dias, extra) {
        return Object.assign({
            texto: texto,
            area: "",
            prioridad: prioridad,
            dias: dias,
            hecha: false,
            hechaEl: "",
            empieza: "",
            programada: "",
            noEmpezada: false,
            subida: "",
            detalles: [],
            subtareas: [],
            fijada: false,
            h: 1
        }, extra || {});
    }

    // La prioridad de hoy: sube cerca de la fecha, como en el NUC.
    function efectiva(t) {
        if (t.dias === null)
            return t.prioridad;
        const suelo = t.dias <= 1 ? "maxima" : t.dias <= 3 ? "alta" : t.dias <= 7 ? "media" : "";
        const r = ["maxima", "alta", "media", "baja", "minima", ""];
        return suelo && r.indexOf(suelo) < r.indexOf(t.prioridad) ? suelo : t.prioridad;
    }

    function arrancar() {
        api.doc = {
            secciones: [
                {
                    id: "homelab",
                    titulo: "Homelab",
                    color: "#6aa8ff",
                    pausa: false,
                    tareas: [
                        api.nueva("Revisar la copia de seguridad", "alta", 0, {
                            area: "Casa",
                            detalles: ["**Hecho**: lo de ayer", "Comprobar restic"],
                            subtareas: [
                                {
                                    texto: "Mirar el log",
                                    hecha: true
                                },
                                {
                                    texto: "Probar una restauración",
                                    hecha: false
                                }
                            ]
                        }),
                        api.nueva("Cambiar los discos del NAS", "media", 5),
                        api.nueva("Empieza la semana que viene", "maxima", 6, {
                            empieza: api.fecha(5),
                            noEmpezada: true
                        })
                    ]
                },
                {
                    id: "clase",
                    titulo: "Clase",
                    color: "#b48cff",
                    pausa: false,
                    tareas: [
                        api.nueva("Entrega de prueba con fecha", "alta", -2),
                        api.nueva("Leer el tema 4", "baja", 12, {
                            programada: api.fecha(3)
                        })
                    ]
                },
                {
                    id: "general",
                    titulo: "General",
                    color: "",
                    pausa: false,
                    tareas: [
                        api.nueva("Una tarea sin proyecto", "media", null),
                        api.nueva("Fijada a mano sin fecha", "minima", null, {
                            fijada: true
                        }),
                        api.nueva("Ya hecha", "media", -1, {
                            hecha: true,
                            hechaEl: api.fecha(-1)
                        })
                    ]
                },
                {
                    id: "en-pausa",
                    titulo: "En pausa",
                    color: "",
                    pausa: true,
                    tareas: [api.nueva("Pausada que venció", "baja", -3)]
                }
            ]
        };
        api.publicar();
        api.habitos = {
            habilitado: true,
            error: "",
            semana: "2026-S43",
            existe: true,
            ruta: "Revisiones/Semanas/2026-S43.md",
            hoy: {
                fecha: "2026-10-20",
                gym: true,
                lectura: null,
                programar: false,
                energia: 7
            },
            totales: {
                gym: "3/7",
                lectura: "2/7",
                programar: "4/7",
                energia: "6,5"
            }
        };
        api.clase = {
            estado: "ok",
            ejecutando: false,
            terminado: new Date(Date.now() - 2 * 3600000),
            error: "",
            tareas: {
                anadidas: 2,
                fechas: 1,
                completadas: 0,
                error: ""
            },
            calendario: {
                creados: 1,
                cambiados: 0,
                borrados: 0,
                error: ""
            },
            calendarioConectado: true,
            calendarioPersonalError: ""
        };
    }

    Component.onCompleted: api.arrancar()

    // Lo que ve la interfaz: el documento normalizado, con líneas y id nuevos.
    function publicar() {
        let linea = 10;
        const secciones = api.doc.secciones.map(s => ({
                    id: s.id,
                    titulo: s.titulo,
                    color: s.color,
                    pausa: s.pausa,
                    tareas: s.tareas.map(t => {
                        const l = linea;
                        linea += 1 + t.detalles.length + t.subtareas.length;
                        return {
                            id: l + "-" + t.h,
                            linea: l,
                            hecha: t.hecha,
                            area: t.area,
                            texto: t.texto,
                            plano: t.texto.replace(/\*\*/g, ""),
                            prioridad: t.prioridad,
                            efectiva: api.efectiva(t),
                            subida: api.efectiva(t) !== t.prioridad ? "vence pronto" : "",
                            vence: t.dias === null ? "" : api.fecha(t.dias),
                            dias: t.dias,
                            empieza: t.empieza,
                            programada: t.programada,
                            noEmpezada: t.noEmpezada,
                            hechaEl: t.hechaEl,
                            vencida: t.dias !== null && t.dias < 0 && !t.hecha,
                            venceHoy: t.dias === 0,
                            detalles: t.detalles.slice(),
                            subtareas: t.subtareas.map(x => Object.assign({}, x)),
                            fijada: t.fijada
                        };
                    })
                }));
        api.tareas = {
            habilitado: true,
            error: "",
            version: String(api.version),
            hoy: api.hoy,
            areas: ["Casa"],
            secciones: secciones
        };
        api.versionCargada = String(api.version);
        api.tareasCargadas = new Date();
        api.inicio = Object.assign({}, api.inicio, {
            tareas: api.tareasDeInicio(secciones)
        });
    }

    // Las tareas de Inicio, con el mismo contrato que Api.qml: las abiertas
    // vencidas o de hoy (como mucho 5) y, en su sitio, las hechas hoy, para
    // poder desmarcarlas. Las de la nota llevan su id; la de otra nota, ""
    // (no se marca desde el cajón). El orden es más sencillo que el de
    // Api.qml (ese lo mira prueba-api.sh): lo que no está en pausa delante, y
    // después por fecha.
    function tareasDeInicio(secciones) {
        const cuando = n => n === 0 ? "hoy" : n === -1 ? "vencida ayer" : "vencida hace " + -n + " días";
        const l = [
            {
                orden: [0, -1, 0],
                tarea: {
                    id: "",
                    hecha: false,
                    texto: "Tarea en otra nota",
                    seccion: "Proyecto de prueba",
                    color: "",
                    prioridad: "maxima",
                    cuando: "vencida ayer",
                    vencida: true
                }
            }
        ];
        for (const s of secciones)
            for (const t of s.tareas) {
                if (t.dias === null || t.dias > 0 || (t.hecha && t.hechaEl !== api.hoy))
                    continue;
                l.push({
                    orden: [s.pausa ? 1 : 0, t.dias, t.linea],
                    tarea: {
                        id: t.id,
                        hecha: t.hecha,
                        texto: t.plano,
                        seccion: s.titulo,
                        color: s.color,
                        prioridad: s.pausa ? "pausa" : t.efectiva || "minima",
                        cuando: t.hecha ? "hecha hoy" : cuando(t.dias),
                        vencida: !t.hecha && t.dias < 0
                    }
                });
            }
        l.sort((a, b) => a.orden[0] - b.orden[0] || a.orden[1] - b.orden[1] || a.orden[2] - b.orden[2]);
        const r = [];
        let abiertas = 0;
        for (const x of l) {
            if (abiertas === 5)
                break;
            if (!x.tarea.hecha)
                abiertas++;
            r.push(x.tarea);
        }
        return r;
    }

    function buscar(id) {
        for (const s of api.doc.secciones)
            for (const t of s.tareas)
                if (api.idDe(t) === id)
                    return [s, t];
        return null;
    }

    function idDe(t) {
        const juntar = (a, s) => a.concat(s.tareas);
        const p = api.tareas ? api.tareas.secciones.reduce(juntar, []) : [];
        // El id publicado de esta tarea: la misma posición que en el documento.
        const todas = api.doc.secciones.reduce(juntar, []);
        const i = todas.indexOf(t);
        return i >= 0 && p[i] ? p[i].id : "";
    }

    // El «servidor» escribe. cambiar(s, t) hace el cambio; devuelve false si
    // no lo hace. Con conflictoPendiente, no escribe: algo cambia «desde fuera».
    function escribir(op, id, cuerpo, que, cambiar, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        api.escrituras = api.escrituras.concat([
            {
                op: op,
                id: id,
                cuerpo: cuerpo
            }
        ]);
        if (api.conflictoPendiente) {
            api.conflictoPendiente = false;
            api.doc.secciones[0].tareas[0].texto = "Cambiada desde Obsidian";
            api.doc.secciones[0].tareas[0].h++;
            api.version++;
            api.publicar();
            api.aviso("La nota cambió en tus notas; he recargado las tareas y no he cambiado nada.", true);
            fin(false);
            return;
        }
        const r = id === "" ? [api.doc.secciones[0], null] : api.buscar(id);
        if (!r) {
            api.aviso(que + ": esa tarea ya no está", true);
            fin(false);
            return;
        }
        cambiar(r[0], r[1]);
        api.version++;
        api.publicar();
        fin(true);
    }

    function anadirTarea(datos, alAcabar) {
        api.escribir("anadir", "", datos, "No se pudo añadir la tarea", (s, t) => {
            const sec = api.doc.secciones.find(x => x.id === datos.seccion) || s;
            const dias = datos.fecha ? Math.round((Date.UTC(+datos.fecha.slice(0, 4), +datos.fecha.slice(5, 7) - 1, +datos.fecha.slice(8, 10)) - Date.UTC(2026, 9, 20)) / 86400000) : null;
            sec.tareas.push(api.nueva(datos.texto, datos.prioridad || "", dias, {
                area: datos.area || ""
            }));
        }, alAcabar);
    }

    function marcarTarea(id, hecha, alAcabar) {
        api.escribir("hecha", id, {
            hecha: hecha
        }, "No se pudo marcar", (s, t) => {
            t.hecha = hecha;
            t.hechaEl = hecha ? api.hoy : "";
            t.h++;
        }, alAcabar);
    }

    function editarTarea(id, cambios, alAcabar) {
        api.escribir("editar", id, cambios, "No se pudo guardar la tarea", (s, t) => {
            if ("texto" in cambios)
                t.texto = cambios.texto;
            if ("area" in cambios)
                t.area = cambios.area;
            if ("fecha" in cambios)
                t.dias = cambios.fecha === "" ? null : Math.round((Date.UTC(+cambios.fecha.slice(0, 4), +cambios.fecha.slice(5, 7) - 1, +cambios.fecha.slice(8, 10)) - Date.UTC(2026, 9, 20)) / 86400000);
            if ("prioridad" in cambios)
                t.prioridad = cambios.prioridad;
            if ("detalles" in cambios)
                t.detalles = cambios.detalles;
            if ("subtareas" in cambios)
                t.subtareas = cambios.subtareas.map(x => ({
                            texto: x.texto,
                            hecha: x.hecha
                        }));
            if ("fijada" in cambios)
                t.fijada = cambios.fijada;
            t.h++;
            if ("seccion" in cambios && cambios.seccion !== s.id) {
                s.tareas.splice(s.tareas.indexOf(t), 1);
                api.doc.secciones.find(x => x.id === cambios.seccion).tareas.push(t);
            }
        }, alAcabar);
    }

    // Algo cambia fuera del cajón (Obsidian, la web): el documento cambia y
    // la versión sube, pero el cajón no lo sabe hasta que llega el evento.
    function cambioExterno(texto) {
        api.doc.secciones[1].tareas[1].texto = texto;
        api.doc.secciones[1].tareas[1].h++;
        api.version++;
        return String(api.version);
    }

    // El evento «tareas», como lo trata Api.qml.
    function eventoTareas(version) {
        if (version === api.versionCargada)
            return;
        if (api.editandoTarea)
            api.tareasObsoletas = true;
        else
            api.cargarTareas();
    }

    onEditandoTareaChanged: if (!api.editandoTarea && api.tareasObsoletas) {
        api.tareasObsoletas = false;
        api.cargarTareas();
    }

    function cargarTareas() {
        api.lecturasTareas++;
        api.publicar();
    }

    function cargarHabitos() {
        api.lecturasHabitos++;
    }

    function cargarClase() {
        api.lecturasClase++;
    }

    function anotarHabito(campo, valor) {
        api.escrituras = api.escrituras.concat([
            {
                op: "habito",
                id: campo,
                cuerpo: {
                    valor: valor
                }
            }
        ]);
        const h = Object.assign({}, api.habitos);
        h.hoy = Object.assign({}, h.hoy);
        h.hoy[campo] = valor === "" ? null : campo === "energia" ? +valor : valor === "si";
        api.habitos = h;
    }

    function actualizarAules() {
        api.escrituras = api.escrituras.concat([
            {
                op: "aules",
                id: "",
                cuerpo: {}
            }
        ]);
        api.clase = Object.assign({}, api.clase, {
            estado: "ejecutando",
            ejecutando: true
        });
    }

    // El evento «clase»: el estado nuevo; si acaba una en marcha, se vuelven
    // a leer las tareas (como Api.qml).
    function eventoClase(estado) {
        const estaba = api.clase && api.clase.ejecutando;
        api.clase = estado;
        if (estaba && !estado.ejecutando)
            api.cargarTareas();
    }

    // --- Fase 4 ---------------------------------------------------------------
    // Un servidor con estado, como el del NUC: una acción aceptada pone el
    // contenedor (o el stack) en «ocupado» y, un momento después, llega su
    // «result» (resultado y aviso) y su línea en el Registro. La palabra de
    // confirmación se comprueba aquí también.

    signal resultado(var r)

    readonly property bool puedeDocker: api.permisos !== null && api.permisos.acciones_docker === true
    property string dockerError: ""
    readonly property var nombresAccion: ({
            start: "Arrancar",
            stop: "Parar",
            restart: "Reiniciar",
            up: "Levantar",
            update: "Actualizar",
            down: "Bajar"
        })

    function cont(nombre, servicio, stack, estado, extra) {
        return Object.assign({
            nombre: nombre,
            servicio: servicio,
            stack: stack,
            imagen: "prueba/" + nombre + ":latest",
            estado: estado,
            salud: "",
            desde: estado === "running" ? new Date(Date.now() - 3 * 3600000) : null,
            hasta: estado === "running" ? null : new Date(Date.now() - 2 * 86400000),
            codigo: 0,
            reinicios: 0,
            unUso: false,
            puertos: [],
            critico: false,
            ocupado: "",
            acciones: {
                start: "",
                stop: "",
                restart: ""
            }
        }, extra || {});
    }

    readonly property var stacksBase: [
        {
            nombre: "homelab",
            gestionado: true,
            protegido: false,
            ocupado: "",
            acciones: {
                up: "",
                stop: "homelab",
                down: "homelab",
                update: "homelab"
            },
            contenedores: [api.cont("caddy", "caddy", "homelab", "running", {
                    salud: "healthy",
                    critico: true,
                    acciones: {
                        start: "",
                        stop: "caddy",
                        restart: ""
                    }
                }), api.cont("vaultwarden", "vaultwarden", "homelab", "exited", {
                    codigo: 1
                })]
        },
        {
            nombre: "sync",
            gestionado: true,
            protegido: false,
            ocupado: "",
            acciones: {
                up: "",
                stop: "",
                down: "sync",
                update: "sync"
            },
            contenedores: [api.cont("syncthing", "syncthing", "sync", "running"), api.cont("syncthing-relay", "relay", "sync", "exited")]
        },
        {
            nombre: "immich",
            gestionado: true,
            protegido: true,
            ocupado: "",
            acciones: {
                up: "immich",
                stop: "immich"
            },
            contenedores: [api.cont("immich_server", "immich-server", "immich", "running", {
                    salud: "unhealthy",
                    acciones: {
                        start: "immich",
                        stop: "immich",
                        restart: "immich"
                    }
                })]
        },
        {
            nombre: "",
            gestionado: false,
            protegido: false,
            ocupado: "",
            acciones: {},
            contenedores: [api.cont("pdftotext-prueba", "pdftotext-prueba", "", "running", {
                    unUso: true,
                    acciones: {}
                })]
        }
    ]
    // Lo que está en marcha: { "contenedor:caddy": "restart" }.
    property var ocupados: ({})
    readonly property var stacks: api.stacksBase.map(st => Object.assign({}, st, {
                ocupado: api.ocupados["stack:" + st.nombre] || "",
                acciones: api.puedeDocker ? st.acciones : {},
                contenedores: st.contenedores.map(c => Object.assign({}, c, {
                            ocupado: api.ocupados["contenedor:" + c.nombre] || api.ocupados["stack:" + st.nombre] || "",
                            acciones: api.puedeDocker ? c.acciones : {}
                        }))
            }))

    property var acciones: []
    property var pendiente: null

    function accionDocker(tipo, nombre, accion, confirmacion, alAcabar) {
        const que = api.nombresAccion[accion] + " · " + nombre;
        if (!api.puedeDocker) {
            api.aviso(que + ": el usuario " + api.usuario + " no tiene acciones de Docker", true);
            alAcabar(false);
            return;
        }
        api.acciones = api.acciones.concat([
            {
                tipo: tipo,
                nombre: nombre,
                accion: accion,
                confirmacion: confirmacion
            }
        ]);
        let palabra = "";
        for (const st of api.stacksBase) {
            if (tipo === "stack" && st.nombre === nombre)
                palabra = st.acciones[accion] || "";
            for (const c of st.contenedores)
                if (tipo === "contenedor" && c.nombre === nombre)
                    palabra = c.acciones[accion] || "";
        }
        if (palabra !== "" && confirmacion !== palabra) {
            api.aviso(que + ": hay que escribir «" + palabra + "» para confirmarla", true);
            alAcabar(false);
            return;
        }
        const o = Object.assign({}, api.ocupados);
        o[tipo + ":" + nombre] = accion;
        api.ocupados = o;
        api.pendiente = {
            tipo: tipo,
            objetivo: nombre,
            accion: accion
        };
        acabarAccion.restart();
        alAcabar(true);
    }

    property Timer acabarAccion: Timer {
        interval: 600
        onTriggered: {
            const r = api.pendiente;
            api.pendiente = null;
            api.ocupados = ({});
            api.resultado({
                tipo: r.tipo,
                objetivo: r.objetivo,
                accion: r.accion,
                ok: true,
                error: "",
                salida: ""
            });
            api.aviso(api.nombresAccion[r.accion] + " · " + r.objetivo + ": hecho", false);
            api.nuevaEntrada({
                fuente: "panel",
                nivel: "info",
                objetivo: r.objetivo,
                titulo: (r.accion === "restart" ? "Reiniciar" : api.nombresAccion[r.accion]) + (r.tipo === "stack" ? " stack · " : " contenedor · ") + r.objetivo,
                conDetalle: true
            });
        }
    }

    // Los logs: tres líneas al abrir, y las que añada la prueba.
    property var logs: null
    property int maxLineasLog: 1000
    property int vecesLogs: 0

    function abrirLogs(nombre) {
        api.vecesLogs++;
        api.logs = {
            contenedor: nombre,
            vez: api.vecesLogs,
            estado: "abierto",
            error: "",
            lineas: [
                {
                    hora: "08:00:00",
                    texto: "arranca " + nombre,
                    nota: false
                },
                {
                    hora: "08:00:01",
                    texto: "línea de prueba del contenedor",
                    nota: false
                },
                {
                    hora: "08:00:02",
                    texto: "escuchando en :443",
                    nota: false
                }
            ],
            total: 3
        };
    }

    function lineaLog(texto) {
        if (!api.logs)
            return;
        api.logs = Object.assign({}, api.logs, {
            lineas: api.logs.lineas.concat([
                {
                    hora: "08:00:09",
                    texto: texto,
                    nota: false
                }
            ]),
            total: api.logs.total + 1
        });
    }

    function cerrarLogs() {
        api.logs = null;
    }

    property bool verConsumo: false
    readonly property var consumo: api.verConsumo ? {
        host: {
            cpu: 12.4,
            memUsada: 6 * 1073741824,
            memTotal: 16 * 1073741824,
            carga: 0.52,
            discos: [
                {
                    ruta: "/",
                    montado: true,
                    usado: 400 * 1073741824,
                    total: 500 * 1073741824
                },
                {
                    ruta: "/mnt/toshiba",
                    montado: false,
                    usado: 0,
                    total: 0
                }
            ]
        },
        contenedores: {
            caddy: {
                cpu: 3,
                mem: 120 * 1048576,
                memLimite: 0
            }
        },
        cuando: new Date()
    } : null

    // El Registro: un diario de mentira, de lo más nuevo a lo más viejo; la
    // primera página son las que no son «viejas».
    property var diario: []
    property int idDiario: 100
    property var registro: null
    property var lecturasRegistro: []
    property int masPedidas: 0
    property var detallesPedidos: []

    function entrada(id, horas, fuente, nivel, titulo, conDetalle) {
        return {
            id: id,
            hora: new Date(Date.now() - horas * 3600000),
            fuente: fuente,
            nivel: nivel,
            objetivo: "",
            titulo: titulo,
            conDetalle: conDetalle
        };
    }

    function arrancarDiario() {
        // Hoy (a las 00:30 no hay «hace 1 h» que siga siendo hoy: se cuenta
        // desde ahora, y la prueba mira solo que haya cabecera de día).
        api.diario = [api.entrada(9, 0.1, "container", "error", "Contenedor caído · vaultwarden", true), api.entrada(8, 0.2, "apt", "info", "Paquetes actualizados", true), api.entrada(7, 26, "disk", "warn", "Disco casi lleno · /", true), api.entrada(6, 27, "system", "info", "NUC arrancado", false), api.entrada(2, 24 * 9, "panel", "info", "Viejo · parar contenedor · relay", true), api.entrada(1, 24 * 10, "container", "error", "Caído hace días · caddy", true)];
    }

    function pasaFiltro(e, filtro) {
        if (!filtro)
            return true;
        if (filtro === "level:warn")
            return e.nivel !== "info";
        return e.fuente === filtro;
    }

    function cargarRegistro(filtro) {
        if (api.diario.length === 0)
            api.arrancarDiario();
        const f = filtro === undefined || filtro === null ? (api.registro ? api.registro.filtro : "") : String(filtro);
        api.lecturasRegistro = api.lecturasRegistro.concat([f]);
        const todas = api.diario.filter(e => api.pasaFiltro(e, f));
        const primera = todas.filter(e => e.id > 2);
        api.registro = {
            filtro: f,
            cargando: false,
            error: "",
            entradas: primera,
            mas: primera.length < todas.length,
            siguiente: primera.length < todas.length ? "cursor" : "",
            notas: ["Sin permiso para leer el journal del sistema: el usuario lab tiene que estar en el grupo systemd-journal."]
        };
    }

    function masRegistro() {
        api.masPedidas++;
        const todas = api.diario.filter(e => api.pasaFiltro(e, api.registro.filtro));
        api.registro = Object.assign({}, api.registro, {
            entradas: todas,
            mas: false,
            siguiente: ""
        });
    }

    function detalleRegistro(id, alAcabar) {
        api.detallesPedidos = api.detallesPedidos.concat([id]);
        alAcabar("Por: portatil\nDuración: 1.2s\n<b>no es html</b>", "");
    }

    // Una línea nueva, como el evento «journal».
    function nuevaEntrada(o) {
        if (api.diario.length === 0)
            api.arrancarDiario();
        const e = Object.assign({
            id: ++api.idDiario,
            hora: new Date(),
            objetivo: ""
        }, o);
        api.diario = [e].concat(api.diario);
        if (api.registro && api.pasaFiltro(e, api.registro.filtro))
            api.registro = Object.assign({}, api.registro, {
                entradas: [e].concat(api.registro.entradas)
            });
    }

    // Los proyectos, como /api/personal: Homelab con dos subproyectos, uno
    // pausado, una idea y uno archivado (en «Otros»).
    function proyecto(ruta, titulo, estado, extra) {
        return Object.assign({
            ruta: ruta,
            titulo: titulo,
            tipo: "proyecto",
            padre: "",
            estado: estado,
            prioridad: "",
            actualizado: "2026-10-19",
            siguiente: [],
            siguientePanel: false,
            repo: "",
            progreso: null
        }, extra || {});
    }

    property var proyectos: [api.proyecto("30 Áreas/Servidor/22-ecosistema.md", "Homelab", "activo", {
            prioridad: "alta",
            progreso: 60,
            repo: "IshimiG/homelab",
            siguiente: ["Fase 4 del **panel** en el escritorio", "Los hashes de Caddy"],
            siguientePanel: true
        }), api.proyecto("30 Áreas/Servidor/26-panel-escritorio.md", "Panel en el escritorio", "activo", {
            tipo: "subproyecto",
            padre: "30 Áreas/Servidor/22-ecosistema.md",
            prioridad: "media",
            progreso: 15,
            siguiente: ["Fusionar la [[PR 7|fase 2]]"]
        }), api.proyecto("30 Áreas/Servidor/24-finanzas.md", "Finanzas", "hecho", {
            tipo: "subproyecto",
            padre: "30 Áreas/Servidor/22-ecosistema.md",
            progreso: 100
        }), api.proyecto("10 Proyectos/Supplementum.md", "Supplementum", "pausado", {
            prioridad: "media"
        }), api.proyecto("10 Proyectos/Idea suelta.md", "Idea suelta", "idea"), api.proyecto("10 Proyectos/Viejo.md", "Viejo", "archivado")]
    property bool proyectosOcupado: false
    property var edicionesProyecto: []
    property bool conflictoProyecto: false

    function editarProyecto(ruta, cambios, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        // Como Api.qml: lo que ya está así no se manda.
        const ya = api.proyectos.find(x => x.ruta === ruta);
        const comoTexto = {
            estado: ya.estado,
            prioridad: ya.prioridad,
            progreso: ya.progreso === null ? "" : String(ya.progreso),
            siguiente: ya.siguientePanel ? ya.siguiente.join("\n") : ""
        };
        if (Object.keys(cambios).every(k => comoTexto[k] === String(cambios[k] ?? ""))) {
            fin(true);
            return;
        }
        api.edicionesProyecto = api.edicionesProyecto.concat([
            {
                ruta: ruta,
                cambios: cambios
            }
        ]);
        const i = api.proyectos.findIndex(x => x.ruta === ruta);
        const lista = api.proyectos.slice();
        if (api.conflictoProyecto) {
            api.conflictoProyecto = false;
            lista[i] = Object.assign({}, lista[i], {
                progreso: 70
            });
            api.proyectos = lista;
            api.aviso("El proyecto cambió en tus notas; lo he recargado y no he cambiado nada.", true);
            fin(false);
            return;
        }
        const p = Object.assign({}, lista[i]);
        if ("estado" in cambios)
            p.estado = cambios.estado;
        if ("prioridad" in cambios)
            p.prioridad = cambios.prioridad;
        if ("progreso" in cambios)
            p.progreso = cambios.progreso === null || cambios.progreso === "" ? null : +cambios.progreso;
        if ("siguiente" in cambios) {
            p.siguiente = String(cambios.siguiente).split("\n").map(x => x.trim()).filter(x => x !== "");
            p.siguientePanel = p.siguiente.length > 0;
        }
        lista[i] = p;
        api.proyectos = lista;
        fin(true);
    }

    property var github: ({
            habilitado: true,
            usuario: "IshimiG",
            error: "",
            repos: {
                "ishimig/homelab": {
                    repo: "IshimiG/homelab",
                    url: "https://github.com/IshimiG/homelab",
                    descripcion: "",
                    prs: 2,
                    issues: 1,
                    privado: false
                }
            }
        })
    property int lecturasGithub: 0
    property var repos: ({})
    property var reposPedidos: []

    function cargarGithub(fresco) {
        api.lecturasGithub++;
    }

    function cargarRepo(repo, fresco) {
        api.reposPedidos = api.reposPedidos.concat([repo]);
        const r = Object.assign({}, api.repos);
        r[repo.toLowerCase()] = {
            cargando: false,
            error: "",
            url: "https://github.com/" + repo,
            cuando: new Date(),
            pulls: [
                {
                    numero: 7,
                    titulo: "Panel del homelab en el escritorio, fase 2",
                    autor: "IshimiG",
                    borrador: false,
                    actualizada: new Date(Date.now() - 2 * 86400000),
                    url: "https://github.com/" + repo + "/pull/7",
                    ramas: "panel-fase2 → main",
                    etiquetas: ["escritorio"],
                    comentarios: 3
                },
                {
                    numero: 9,
                    titulo: "Un borrador",
                    autor: "IshimiG",
                    borrador: true,
                    actualizada: new Date(Date.now() - 3600000),
                    url: "https://github.com/" + repo + "/pull/9",
                    ramas: "borrador → main",
                    etiquetas: [],
                    comentarios: 0
                }
            ],
            issues: [
                {
                    numero: 12,
                    titulo: "Una issue abierta",
                    autor: "IshimiG",
                    borrador: false,
                    actualizada: new Date(Date.now() - 5 * 86400000),
                    url: "https://github.com/" + repo + "/issues/12",
                    ramas: "",
                    etiquetas: [],
                    comentarios: 1
                }
            ]
        };
        api.repos = r;
    }

    // --- Fase 5: notas como página -------------------------------------------------
    // Un vault de mentira para leerNota (GET /api/nota): las notas de
    // notasFalsas, con todo lo que pinta el renderizador, HTML que no se tiene
    // que interpretar y euros, que se tapan con el cajón a medio sacar. Con
    // lectorReal (lo pone PasosNotas.qml cuando se pide una nota de verdad con
    // PRUEBA_NOTA_REAL), las demás salen del vault de verdad, sólo de las
    // carpetas que abre el NUC. Con retenerNotas, las respuestas esperan a
    // soltarNotas().

    property var notasPermitidas: ["00 Inicio.md", "10 Proyectos", "20 Trabajo", "30 Áreas", "40 Aprendizaje/Libros", "40 Aprendizaje/Clase"]
    property var notasRecientes: [
        {
            ruta: "30 Áreas/Servidor/Prueba.md",
            titulo: "Prueba",
            modificada: new Date(Date.now() - 2 * 3600000)
        },
        {
            ruta: "30 Áreas/Servidor/Otra nota.md",
            titulo: "Otra nota",
            modificada: new Date(Date.now() - 3 * 86400000)
        }
    ]
    property var notasPedidas: []
    property bool retenerNotas: false
    property var notasPendientes: []
    // (ruta) => { titulo, texto } o null: una nota del vault de verdad.
    property var lectorReal: null

    readonly property string relleno: "Un párrafo de relleno para que la página tenga que desplazarse: el cajón es alto, pero no tanto. Lleva bastantes palabras para ocupar varias líneas en una columna estrecha como la del cajón.\n\n"

    readonly property var notasFalsas: ({
            "30 Áreas/Servidor/Prueba.md": {
                titulo: "Prueba",
                texto: "# Una nota de prueba\n\n" + "Un párrafo con **negrita**, *cursiva*, ~~tachado~~ y `código <b>`.\n" + "Segunda línea, con [la web](https://example.org/web) y https://example.org/suelta.\n\n" + "<b>no es html</b> <img src=\"http://127.0.0.1:9/x.png\"> &amp; <a href=\"https://example.org/mal\">tampoco</a>\n\n" + "Enlaces: [[30 Áreas/Servidor/Otra nota|la otra nota]], [[30 Áreas/Servidor/Otra nota#Segunda parte]], [[Sin carpeta]], [[MentalHealth/Diario]], [[30 Áreas/../MentalHealth/Diario|escapada]] y [[#Tabla]].\n\n" + "%% un comentario que no sale %%\n\n" + "Gasto del mes: 1.234,56 € y 300€.\n\n" + "## Listas\n\n" + "- Uno\n  - Dos, dentro\n- [ ] Una tarea\n- [x] Una hecha\n\n" + "1. Primero\n2. Segundo\n\n" + api.relleno + api.relleno + api.relleno + "## Tabla\n\n" + "| Qué | Enlace | Nota |\n|---|:---:|---|\n" + "| Fila uno | [[30 Áreas/Servidor/Otra nota\\|otra]] | corta |\n" + "| Fila dos, con un texto bastante más largo que no cabe en una columna estrecha del cajón | — | 12 € |\n\n" + "> Una cita\n> con dos líneas\n\n" + "> [!warning] Cuidado\n> Dentro del aviso, una lista:\n> - a\n> - b\n\n" + "---\n\n" + "```sh\necho \"<script>alert(1)</script>\"\n```\n\n" + "### Relleno\n\n" + api.relleno + api.relleno + api.relleno + api.relleno
            },
            "30 Áreas/Servidor/Otra nota.md": {
                titulo: "Otra nota",
                texto: "Texto de la otra nota. Vuelve a [[30 Áreas/Servidor/Prueba|la de prueba]].\n\n" + api.relleno + api.relleno + api.relleno + api.relleno + api.relleno + "## Segunda parte\n\n" + api.relleno + api.relleno + api.relleno + api.relleno + api.relleno
            }
        })

    // Como AllowedNote del NUC: un .md de las carpetas permitidas, sin «..» ni
    // partes ocultas.
    function notaPermitida(ruta) {
        if (!/\.md$/i.test(ruta) || ruta.split("/").some(x => x === "" || x === "." || x === ".." || x[0] === "."))
            return false;
        return api.notasPermitidas.some(e => ruta === e || ruta.indexOf(e + "/") === 0);
    }

    function leerNota(ruta, alAcabar) {
        api.notasPedidas = api.notasPedidas.concat([ruta]);
        const responder = () => {
            if (!api.notaPermitida(ruta)) {
                alAcabar(null, "No se puede abrir la nota: esa nota no está en las carpetas que muestra el panel");
                return;
            }
            const n = api.notasFalsas[ruta] || (api.lectorReal ? api.lectorReal(ruta) : null);
            if (!n) {
                alAcabar(null, "No se puede abrir la nota: no encuentro esa nota");
                return;
            }
            alAcabar({
                ruta: ruta,
                titulo: n.titulo,
                modificada: new Date(Date.now() - 2 * 3600000),
                texto: n.texto
            }, "");
        };
        if (api.retenerNotas)
            api.notasPendientes = api.notasPendientes.concat([responder]);
        else
            Qt.callLater(responder);
    }

    function soltarNotas() {
        const l = api.notasPendientes;
        api.notasPendientes = [];
        for (const f of l)
            f();
    }

    // --- Fase 5: finanzas -----------------------------------------------------
    // Un «NUC» de mentira con estado: octubre con 7 movimientos (3 en la
    // primera página), el resumen del mes y Trade Republic. apuntarEfectivo
    // añade un movimiento; con conflictoEfectivo contesta como un 409 y con
    // errorEfectivo como una validación (sin cambiar nada).
    property var finanzas: null
    property var traderepublic: null
    property int paginaFinanzas: 3
    property int lecturasFinanzas: 0
    property int masFinanzasPedidas: 0
    property int lecturasTR: 0
    property var efectivos: []
    property bool conflictoEfectivo: false
    property string errorEfectivo: ""
    property bool trCaducada: true
    property var movsFinanzas: []

    function finanzasViejas() {
        return api.finanzas === null;
    }

    function arrancarFinanzas() {
        if (api.movsFinanzas.length > 0)
            return;
        const m = (id, fecha, concepto, importe, categoria) => ({
                id: id,
                fecha: fecha,
                concepto: concepto,
                importe: importe,
                categoria: categoria,
                cuenta: "CaixaBank"
            });
        api.movsFinanzas = [m(7, "2026-10-20", "Mercadona", -4523, "Supermercado"), m(6, "2026-10-19", "Nómina octubre", 185000, "Nómina"), m(5, "2026-10-18", "Cine", -1200, "Ocio"), m(4, "2026-10-12", "Gasolina", -6010, ""), m(3, "2026-10-10", "Panadería", -310, "Supermercado"), m(2, "2026-10-05", "Alquiler", -55000, "Vivienda"), m(1, "2026-10-01", "Seguro", -9999, "Vivienda")];
    }

    function resumenFinanzas() {
        const gasto = api.movsFinanzas.filter(x => x.importe < 0);
        return {
            total: -gasto.reduce((a, x) => a + x.importe, 0),
            anterior: 100000,
            mesAnterior: "2026-09",
            sinCategoria: 1,
            porCategoria: [
                {
                    id: 3,
                    nombre: "Vivienda",
                    total: 64999,
                    n: 2
                },
                {
                    id: 1,
                    nombre: "Supermercado",
                    total: 4833,
                    n: 2
                }
            ]
        };
    }

    function ponerFinanzas(conservar) {
        const p = conservar ? api.finanzas.movimientos.length : api.paginaFinanzas;
        const movs = api.movsFinanzas.slice(0, Math.max(p, api.paginaFinanzas));
        api.finanzas = {
            cargando: false,
            cargandoMas: false,
            error: "",
            cargado: new Date(),
            habilitado: true,
            listo: true,
            motivo: "",
            mes: "2026-10",
            hoy: "2026-10-21",
            categorias: [
                {
                    id: 1,
                    nombre: "Supermercado"
                },
                {
                    id: 2,
                    nombre: "Ocio"
                }
            ],
            gastos: api.resumenFinanzas(),
            ingresos: 185000,
            patrimonio: 1234567,
            meta: 3000000,
            porcentaje: 41.2,
            sinCategoria: 1,
            movimientos: movs,
            mas: movs.length < api.movsFinanzas.length,
            siguiente: "cursor",
            ocupado: false
        };
    }

    function cargarFinanzas(alAcabar) {
        api.arrancarFinanzas();
        api.lecturasFinanzas++;
        api.ponerFinanzas(false);
        if (alAcabar)
            alAcabar(true);
    }

    function masFinanzas() {
        api.masFinanzasPedidas++;
        api.finanzas = Object.assign({}, api.finanzas, {
            movimientos: api.movsFinanzas,
            mas: false,
            siguiente: ""
        });
    }

    function apuntarEfectivo(importe, concepto, categoria, fecha, alAcabar) {
        api.efectivos = api.efectivos.concat([
            {
                importe: importe,
                concepto: concepto,
                categoria: categoria,
                fecha: fecha
            }
        ]);
        if (api.conflictoEfectivo) {
            api.conflictoEfectivo = false;
            api.aviso("Finanzas no pudo apuntarlo: No hay ninguna cuenta de efectivo.; la he recargado.", true);
            alAcabar(false, "No hay ninguna cuenta de efectivo.");
            return;
        }
        if (api.errorEfectivo !== "") {
            alAcabar(false, api.errorEfectivo);
            return;
        }
        api.movsFinanzas = [
            {
                id: 100 + api.efectivos.length,
                fecha: "2026-10-21",
                concepto: concepto,
                importe: -importe,
                categoria: categoria === 1 ? "Supermercado" : "Ocio",
                cuenta: "Efectivo"
            }
        ].concat(api.movsFinanzas);
        api.aviso("Gasto en efectivo apuntado", false);
        api.ponerFinanzas(false);
        alAcabar(true, "");
    }

    function cargarTradeRepublic() {
        api.lecturasTR++;
        api.traderepublic = {
            configurado: true,
            caducada: api.trCaducada,
            iniciando: false,
            comprobando: false,
            ultimoOk: null
        };
    }

    // --- Fase 5: Revisiones -----------------------------------------------------
    // Un «servidor» de revisiones con estado: la semana 43 es la de hoy (la 42
    // y la 44 existen, vacías). Cada escritura comprueba «antes» como el NUC:
    // si no coincide (o con revConflicto, que cambia algo «desde fuera»), no
    // escribe y recarga. Lo que ha pasado queda en escriturasRev y
    // lecturasRevisiones.

    property var revisiones: null
    property var revisionesCargadas: null
    property string revisionesError: ""
    property bool revisionesOcupado: false
    property string revisionesPedida: ""
    property var lecturasRevisiones: []
    property var escriturasRev: []
    property bool revConflicto: false
    property bool revEditables: true
    // Lo que hay en las «notas»: texto por día, y por semana las secciones de
    // la retro y del planning (null si no existe la nota).
    property var notasRev: ({
            dias: {
                "2026-10-19": "Lunes tranquilo.\n\n- gym\n- leído",
                "2026-10-20": ""
            },
            retro: {
                "2026-S43": [
                    {
                        i: 0,
                        nivel: 2,
                        titulo: "Qué ha ido bien",
                        cuerpo: "Acabé el cajón."
                    },
                    {
                        i: 1,
                        nivel: 2,
                        titulo: "Qué mejorar",
                        cuerpo: ""
                    }
                ]
            },
            planning: {}
        })

    readonly property var plantillaRev: ["Prioridades", "Riesgos"]

    function lunesRev(id) {
        return api.fecha(7 * (+id.slice(6) - 43) - 1);
    }

    function semanaRev(id) {
        const lunes = api.lunesRev(id);
        const dias = [];
        for (let k = 0; k < 7; k++) {
            const d = new Date(Date.UTC(+lunes.slice(0, 4), +lunes.slice(5, 7) - 1, +lunes.slice(8, 10) + k)).toISOString().slice(0, 10);
            const t = api.notasRev.dias[d];
            dias.push({
                fecha: d,
                existe: t !== undefined,
                editable: api.revEditables,
                texto: t || ""
            });
        }
        const nota = tipo => {
            const s = api.notasRev[tipo][id];
            return {
                existe: !!s,
                ruta: "30 Áreas/Revisiones/" + tipo + "/" + id + ".md",
                secciones: s || []
            };
        };
        const num = +id.slice(6);
        return {
            habilitado: true,
            error: "",
            semana: id,
            etiqueta: "S" + num,
            lunes: lunes,
            domingo: api.fecha(7 * (num - 43) + 5),
            hoy: api.hoy,
            actual: id === "2026-S43",
            semanaActual: "2026-S43",
            anterior: "2026-S" + (num - 1),
            siguiente: "2026-S" + (num + 1),
            semanas: ["2026-S42", "2026-S43"],
            reminders: dias,
            planning: nota("planning"),
            retro: nota("retro")
        };
    }

    function cargarRevisiones(semana) {
        const pedida = semana === undefined ? api.revisionesPedida : semana;
        api.revisionesPedida = pedida;
        api.lecturasRevisiones = api.lecturasRevisiones.concat([pedida]);
        api.revisiones = api.semanaRev(pedida === "" ? "2026-S43" : pedida);
        api.revisionesCargadas = new Date();
    }

    // La escritura: cambiar(semanaId) devuelve false si «antes» no coincide.
    function escribirRev(op, cuerpo, semanaId, textoActual, cambiar, alAcabar) {
        api.escriturasRev = api.escriturasRev.concat([
            {
                op: op,
                cuerpo: cuerpo
            }
        ]);
        if (api.revConflicto) {
            api.revConflicto = false;
            api.notasRev.dias[api.hoy] = "Escrito desde Obsidian";
        }
        if (cuerpo.antes !== undefined && cuerpo.antes !== textoActual()) {
            api.revisiones = api.semanaRev(semanaId);
            api.revisionesCargadas = new Date();
            api.aviso("Tus notas han cambiado; las he recargado. Revisa lo que escribías.", true);
            alAcabar("obsoleta");
            return;
        }
        cambiar();
        api.revisiones = api.semanaRev(semanaId);
        api.revisionesCargadas = new Date();
        alAcabar("ok");
    }

    function guardarRecordatorio(fecha, antes, texto, alAcabar) {
        const semanaId = api.revisiones.semana;
        api.escribirRev("reminder", {
            fecha: fecha,
            antes: antes,
            texto: texto
        }, semanaId, () => api.notasRev.dias[fecha] || "", () => {
            api.notasRev.dias[fecha] = texto;
        }, alAcabar);
    }

    function guardarApartado(tipo, semana, i, titulo, antes, cuerpo, alAcabar) {
        api.escribirRev("nota", {
            tipo: tipo,
            semana: semana,
            i: i,
            titulo: titulo,
            antes: antes,
            cuerpo: cuerpo
        }, semana, () => api.notasRev[tipo][semana][i].cuerpo, () => {
            api.notasRev[tipo][semana][i].cuerpo = cuerpo;
        }, alAcabar);
    }

    function crearNotaRevision(tipo, semana, alAcabar) {
        api.escribirRev("nota", {
            tipo: tipo,
            semana: semana,
            crear: true
        }, semana, () => "", () => {
            api.notasRev[tipo][semana] = api.plantillaRev.map((t, i) => ({
                        i: i,
                        nivel: 2,
                        titulo: t,
                        cuerpo: ""
                    }));
        }, alAcabar);
    }
}
