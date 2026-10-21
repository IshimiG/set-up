import QtQuick

// Una Api.qml falsa para la prueba: cumple el contrato de la fase 2 y de la 3
// entero (propiedades, señales y funciones) con datos inventados. La prueba
// cambia las propiedades a mano, y las llamadas a refrescar/marcarVista y las
// escrituras de tareas, hábitos y Aules quedan apuntadas.
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
            acciones_docker: false,
            login_traderepublic: false
        })
    property var alertas: [
        {
            id: "a1",
            nivel: "error",
            titulo: "Contenedor caído: caddy",
            detalle: "caddy lleva 3 minutos parado",
            desde: new Date(Date.now() - 12 * 60000),
            vista: false
        },
        {
            id: "a2",
            nivel: "warn",
            titulo: "Disco al 85 % en /srv",
            detalle: "Quedan 40 GB libres",
            desde: new Date(Date.now() - 3 * 3600000),
            vista: false
        },
        {
            id: "a3",
            nivel: "warn",
            titulo: "Copia de seguridad lenta",
            detalle: "",
            desde: new Date(Date.now() - 2 * 86400000),
            vista: true
        }
    ]
    property string nivelAlertas: "error"
    property var servidor: ({
            enMarcha: 8,
            total: 9,
            problemas: 1
        })
    property var inicio: ({
            hoy: "martes 20 de octubre",
            semana: "semana 43",
            metaPorcentaje: 34,
            tareas: [
                {
                    texto: "Entrega de prueba con fecha",
                    seccion: "Clase",
                    color: "#b48cff",
                    prioridad: "maxima",
                    cuando: "vencida hace 2 días",
                    vencida: true
                },
                {
                    texto: "Revisar la copia de seguridad",
                    seccion: "Homelab",
                    color: "#6aa8ff",
                    prioridad: "alta",
                    cuando: "hoy",
                    vencida: false
                },
                {
                    texto: "Una tarea sin proyecto",
                    seccion: "General",
                    color: "",
                    prioridad: "media",
                    cuando: "mañana",
                    vencida: false
                }
            ]
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
                        api.nueva("Leer el tema 4", "baja", 12)
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
}
