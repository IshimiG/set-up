import QtQuick
import Quickshell
import Quickshell.Io
import "homelab"

// Prueba sin pantalla de Api.qml (la lanza prueba-api.sh, al lado): el Api.qml
// del repo contra el panel local de panel-local.sh, detrás de su Caddy falso,
// con un llavero de usar y tirar. Cada comprobación imprime OK o FALLO; al
// final, el recuento. Va por fases: la conexión y lo de Inicio (fase 2), las
// tareas, los hábitos y Aules (fase 3), y el servidor, el Registro, los
// proyectos y lo que no puede hacer el usuario movil (fase 4).
ShellRoot {
    id: prueba

    readonly property string dir: Quickshell.env("PRUEBA_DIR")
    readonly property string panelLocal: Quickshell.env("PANEL_LOCAL")
    readonly property string usuarioPrueba: "equipo-prueba"

    property int hechas: 0
    property var fallos: []

    function comprobar(ok, que, extra) {
        console.log((ok ? "OK     " : "FALLO  ") + que + (extra !== undefined && extra !== "" ? "  (" + extra + ")" : ""));
        prueba.hechas++;
        if (!ok)
            prueba.fallos.push(que);
    }

    function igual(a, b) {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    // --- Esperar a que algo pase, sin bloquear -------------------------------

    property var condicion: null
    property var luego: null
    property double limite: 0

    function esperar(ms, cond, luego) {
        prueba.condicion = cond;
        prueba.luego = luego;
        prueba.limite = Date.now() + ms;
        sondeo.restart();
    }

    function dormir(ms, luego) {
        prueba.esperar(ms, () => false, () => luego());
    }

    Timer {
        id: sondeo
        interval: 100
        repeat: true
        onTriggered: {
            const ok = prueba.condicion();
            if (ok || Date.now() > prueba.limite) {
                sondeo.stop();
                // Una excepción en un paso es un fallo, y acaba la prueba con su
                // recuento en vez de dejarla colgada hasta el tiempo máximo.
                try {
                    prueba.luego(ok);
                } catch (e) {
                    prueba.comprobar(false, "excepción en un paso: " + e);
                    prueba.fin();
                }
            }
        }
    }

    // Una orden de shell, y luego(codigo).
    Component {
        id: ordenes
        Process {}
    }

    function sh(orden, luego) {
        const o = ordenes.createObject(prueba, {
            command: ["sh", "-c", orden]
        });
        o.exited.connect(c => {
            o.destroy();
            luego(c);
        });
        o.running = true;
    }

    function guardarClave(fichero, luego) {
        prueba.sh("secret-tool store --label='Panel del homelab' servicio homelab-panel usuario " + prueba.usuarioPrueba + " < '" + fichero + "'", luego);
    }

    // --- Los cajones de prueba -----------------------------------------------

    // «a» arranca con el llavero vacío; después se le da la contraseña buena.
    Api {
        id: a
    }

    property var nuevas: []
    // Si cada alerta de alertaNueva estaba en «alertas» al emitirse, con los
    // mismos datos (después puede llegar otra lista). Con los mismos datos y
    // no el mismo objeto: desde Qt 6.12, un objeto de JS que pasa por una
    // señal llega copiado (como un QVariantMap), con las claves en otro
    // orden; por eso se compara con igualObj y no con JSON.stringify.
    property var enLista: []
    property var tiempos: []
    // Cuándo pasó «a» a "sin-conexion" por última vez.
    property double tCorte: 0
    // Los valores de nivelAlertas de «a», en orden.
    property var niveles: []

    Connections {
        target: a
        function onAlertaNueva(alerta) {
            prueba.nuevas.push(alerta);
            prueba.enLista.push(a.alertas.some(x => x.id === alerta.id && prueba.igualObj(x, alerta)));
        }
        function onIntentosChanged() {
            prueba.tiempos.push(Date.now());
        }
        function onNivelAlertasChanged() {
            prueba.niveles.push(a.nivelAlertas);
        }
        function onConexionChanged() {
            if (a.conexion === "sin-conexion" && prueba.tCorte === 0)
                prueba.tCorte = Date.now();
        }
    }

    // Los avisos de «a» (fase 3): conflictos y fallos de escritura.
    property var avisos: []

    Connections {
        target: a
        function onAviso(texto, error) {
            prueba.avisos.push({
                texto: texto,
                error: error
            });
        }
    }

    // «b», con una contraseña que el Caddy falso no acepta.
    Component {
        id: otroApi
        Api {}
    }
    property var b: null
    // «c», con el vigía a 6 s en vez de 70.
    property var c: null

    // --- Lo que se espera del panel local ------------------------------------

    function hoyEsperado() {
        const t = Qt.locale("es_ES").toString(new Date(), "dddd d 'de' MMMM");
        return t.charAt(0).toUpperCase() + t.slice(1);
    }

    function semanaEsperada() {
        const d = new Date();
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return "Semana " + Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    // El vault falso de panel-local.sh: 6 vencidas o de hoy, se enseñan 5. Las
    // de 00 Inicio llevan su id de /api/tareas (que cambia con cada
    // escritura: aquí basta con saber que lo llevan); la de otra nota, "".
    readonly property var tareasEsperadas: [
        {
            id: "id",
            hecha: false,
            texto: "Otra vencida",
            seccion: "General",
            color: "",
            prioridad: "maxima",
            cuando: "vencida hace 11 días",
            vencida: true
        },
        {
            id: "",
            hecha: false,
            texto: "Tarea en otra nota",
            seccion: "Proyecto de prueba",
            color: "",
            prioridad: "maxima",
            cuando: "vencida hace 2 días",
            vencida: true
        },
        {
            id: "id",
            hecha: false,
            texto: "Entrega de prueba",
            seccion: "Clase",
            color: "#b48cff",
            prioridad: "maxima",
            cuando: "vencida ayer",
            vencida: true
        },
        {
            id: "id",
            hecha: false,
            texto: "Cambiar el filtro del agua",
            seccion: "Homelab · Casa",
            color: "#6aa8ff",
            prioridad: "maxima",
            cuando: "hoy",
            vencida: false
        },
        {
            id: "id",
            hecha: false,
            texto: "Pausada que venció",
            seccion: "En pausa",
            color: "",
            prioridad: "pausa",
            cuando: "vencida hace 3 días",
            vencida: true
        }
    ]

    function conIdONo(l) {
        return (l || []).map(t => Object.assign({}, t, {
                    id: t.id === "" ? "" : "id"
                }));
    }

    // --- La prueba, paso a paso ---------------------------------------------

    Component.onCompleted: {
        prueba.niveles = [a.nivelAlertas];
        prueba.sinCredenciales();
    }

    function sinCredenciales() {
        prueba.esperar(10000, () => a.conexion === "sin-credenciales", ok => {
            prueba.comprobar(ok, "Sin elemento en el llavero: \"sin-credenciales\"", a.conexion);
            prueba.comprobar(a.error.indexOf("llavero") >= 0, "  y el error lo dice", a.error);
            prueba.comprobar(a.nivelAlertas === "desconocido", "  nivelAlertas \"desconocido\"", a.nivelAlertas);
            prueba.dormir(3000, () => {
                prueba.comprobar(a.conexion === "sin-credenciales" && a.intentos === 0 && a.esperaMs === 0, "  3 s después, sigue igual y sin ningún intento (no reintenta en bucle)", "intentos " + a.intentos);
                prueba.conectar();
            });
        });
    }

    function conectar() {
        prueba.guardarClave(prueba.dir + "/clave", c => {
            const t0 = Date.now();
            a.refrescar();
            prueba.esperar(15000, () => a.conexion === "conectado", ok => {
                prueba.comprobar(ok, "Con la contraseña en el llavero, refrescar() conecta: \"conectado\"", a.conexion + " en " + (Date.now() - t0) + " ms; error «" + a.error + "»");
                prueba.esperar(10000, () => a.usuario !== "" && a.inicio !== null, () => prueba.datos());
            });
        });
    }

    function datos() {
        prueba.comprobar(a.usuario === prueba.usuarioPrueba, "usuario, de /api/yo", a.usuario);
        prueba.comprobar(prueba.igual(a.permisos, {
            acciones_docker: true,
            login_traderepublic: true
        }), "permisos, de /api/yo", JSON.stringify(a.permisos));
        prueba.comprobar(prueba.igual(a.servidor, {
            enMarcha: 3,
            total: 6,
            problemas: 3
        }), "servidor: 3 de 6 en marcha y 3 problemas (sin los de un solo uso)", JSON.stringify(a.servidor));
        const ids = a.alertas.map(x => x.id);
        prueba.comprobar(prueba.igual(ids, ["state:immich_server", "disk:/"]), "alertas: la de error delante", JSON.stringify(ids));
        const al = a.alertas[0];
        prueba.comprobar(al && al.nivel === "error" && al.titulo.indexOf("immich_server") >= 0 && al.desde instanceof Date && !isNaN(al.desde) && al.vista === false && typeof al.detalle === "string", "  normalizadas: nivel, titulo, detalle, desde (Date), vista", al ? JSON.stringify(al) : "");
        prueba.comprobar(a.nivelAlertas === "error", "nivelAlertas \"error\"", a.nivelAlertas);
        prueba.comprobar(prueba.igual(prueba.niveles, ["desconocido", "error"]), "  sin pasar por \"ok\" al conectar", prueba.niveles.join(" → "));
        prueba.comprobar(prueba.nuevas.length === 0, "La primera lista no emite alertaNueva", prueba.nuevas.length);
        const i = a.inicio || {};
        prueba.comprobar(i.hoy === prueba.hoyEsperado(), "inicio.hoy", i.hoy);
        prueba.comprobar(i.semana === prueba.semanaEsperada(), "inicio.semana", i.semana);
        prueba.comprobar(i.metaPorcentaje === null, "inicio.metaPorcentaje null sin la base de datos de finanzas", i.metaPorcentaje);
        prueba.comprobar(prueba.igual(prueba.conIdONo(i.tareas), prueba.tareasEsperadas), "inicio.tareas: vencidas y de hoy, 5, por urgencia, la de pausa al final; las de la nota con id", JSON.stringify(i.tareas));
        prueba.comprobar(a.inicioCargado instanceof Date && Date.now() - a.inicioCargado < 30000, "inicioCargado", String(a.inicioCargado));
        prueba.comprobar(a.urlWeb("#/servidor") === a.baseUrl + "/#/servidor", "urlWeb(\"#/servidor\")", a.urlWeb("#/servidor"));
        prueba.comprobar(a.error === "", "error vacío", a.error);
        prueba.alertaNueva();
    }

    function alertaNueva() {
        prueba.sh("'" + prueba.panelLocal + "' alerta", () => {
            prueba.esperar(15000, () => prueba.nuevas.length > 0, ok => {
                const n = prueba.nuevas[0];
                prueba.comprobar(ok && n.id.indexOf("apt:") === 0 && n.nivel === "error", "Una alerta nueva con el cajón conectado emite alertaNueva", n ? n.id : "nada");
                prueba.comprobar(!!n && prueba.enLista[0] === true, "  con los mismos datos que en alertas");
                prueba.marcarVistas(n ? n.id : "");
            });
        });
    }

    function marcarVistas(idApt) {
        const t0 = Date.now();
        a.marcarVista(idApt);
        // Es de las que se van al verlas (un suceso, no una condición).
        prueba.esperar(5000, () => !a.alertas.some(x => x.id === idApt && !x.vista), ok => {
            prueba.comprobar(ok, "marcarVista de la alerta nueva: queda vista o se va", (Date.now() - t0) + " ms");
            a.marcarVista("state:immich_server");
            prueba.esperar(5000, () => a.nivelAlertas === "warn", ok2 => {
                const s = a.alertas.find(x => x.id === "state:immich_server");
                prueba.comprobar(ok2 && s && s.vista, "marcarVista de la de error: vista, y nivelAlertas baja a \"warn\"", a.nivelAlertas);
                a.marcarVista("disk:/");
                prueba.esperar(5000, () => a.nivelAlertas === "ok", ok3 => {
                    prueba.comprobar(ok3, "marcarVista de la última sin ver: nivelAlertas \"ok\"", a.nivelAlertas);
                    prueba.dormir(1500, () => {
                        prueba.comprobar(prueba.nuevas.length === 1, "alertaNueva salió una sola vez (las listas siguientes no la repiten)", prueba.nuevas.length);
                        prueba.corte();
                    });
                });
            });
        });
    }

    // El panel se para: el Caddy falso responde 502, como el de verdad.
    function corte() {
        prueba.tCorte = 0;
        const desde = prueba.tiempos.length;
        prueba.sh("'" + prueba.panelLocal + "' parar-panel", () => {
            prueba.esperar(15000, () => a.conexion === "sin-conexion", ok => {
                const t0 = prueba.tCorte;
                prueba.comprobar(ok, "Se para el panel: \"sin-conexion\"", a.conexion + "; error «" + a.error + "»");
                prueba.comprobar(a.nivelAlertas === "desconocido", "  nivelAlertas \"desconocido\"", a.nivelAlertas);
                prueba.comprobar(a.alertas.length === 0 && a.servidor === null, "  sin alertas ni servidor (no se sabe)", a.alertas.length + ", " + JSON.stringify(a.servidor));
                // Una alerta mientras el panel está parado: al volver, es nueva.
                prueba.sh("'" + prueba.panelLocal + "' alerta", () => {});
                prueba.dormir(15500, () => {
                    const t = [t0].concat(prueba.tiempos.slice(desde));
                    const pasos = [];
                    for (let i = 1; i < t.length; i++)
                        pasos.push(t[i] - t[i - 1]);
                    let crecen = pasos.length >= 3 && pasos[0] >= 1900;
                    for (let i = 1; i < pasos.length; i++)
                        crecen = crecen && pasos[i] >= 1.6 * pasos[i - 1];
                    prueba.comprobar(crecen && pasos.length <= 4, "  reintentos espaciados, de 2 s hacia arriba", "ms entre intentos: " + pasos.join(", "));
                    prueba.vuelve();
                });
            });
        });
    }

    function vuelve() {
        const nuevasAntes = prueba.nuevas.length;
        const espera = a.esperaMs;
        prueba.sh("'" + prueba.panelLocal + "' seguir-panel", () => {
            const t0 = Date.now();
            prueba.esperar(espera + 8000, () => a.conexion === "conectado", ok => {
                prueba.comprobar(ok, "Vuelve el panel: reconecta solo, sin refrescar()", "en " + (Date.now() - t0) + " ms, con " + espera + " ms de espera pendiente");
                prueba.esperar(10000, () => prueba.nuevas.length > nuevasAntes, ok2 => {
                    const n = prueba.nuevas[prueba.nuevas.length - 1];
                    prueba.comprobar(ok2 && prueba.nuevas.length === nuevasAntes + 1 && n.id.indexOf("apt:") === 0, "  alertaNueva para la que apareció durante el corte, y solo para esa", prueba.nuevas.slice(nuevasAntes).map(x => x.id).join(", "));
                    prueba.dormir(1000, () => prueba.refrescarYa());
                });
            });
        });
    }

    function refrescarYa() {
        prueba.sh("'" + prueba.panelLocal + "' parar-panel", () => {
            prueba.esperar(30000, () => a.conexion === "sin-conexion" && a.esperaMs >= 8000, ok => {
                const tFallo = Date.now();
                const espera = a.esperaMs;
                prueba.sh("'" + prueba.panelLocal + "' seguir-panel", () => {
                    const antes = a.intentos;
                    const t0 = Date.now();
                    a.refrescar();
                    const yaIntenta = a.intentos === antes + 1;
                    prueba.esperar(5000, () => a.conexion === "conectado", ok2 => {
                        const tarda = Date.now() - t0;
                        const quedaba = espera - (t0 - tFallo);
                        prueba.comprobar(ok && ok2 && yaIntenta && tarda < 3000 && quedaba > tarda + 1000, "refrescar() con los eventos cortados reconecta al momento", "en " + tarda + " ms; al intento automático le quedaban " + quedaba + " ms");
                        prueba.noAutorizado();
                    });
                });
            });
        });
    }

    // Otra contraseña en el llavero: un cajón nuevo la lee y Caddy dice 401.
    // El que ya estaba sigue con la suya, leída una vez al conectar.
    function noAutorizado() {
        prueba.sh("printf 'esta-no-es' > '" + prueba.dir + "/mala'", () => {
            prueba.guardarClave(prueba.dir + "/mala", () => {
                prueba.b = otroApi.createObject(prueba);
                prueba.esperar(10000, () => prueba.b.conexion === "no-autorizado", ok => {
                    prueba.comprobar(ok, "Con una contraseña que Caddy no acepta: \"no-autorizado\"", prueba.b.conexion + "; error «" + prueba.b.error + "»");
                    const intentos = prueba.b.intentos;
                    prueba.dormir(4000, () => {
                        prueba.comprobar(prueba.b.conexion === "no-autorizado" && prueba.b.intentos === intentos && prueba.b.esperaMs === 0, "  y no reintenta solo", "intentos " + prueba.b.intentos);
                        prueba.comprobar(a.conexion === "conectado", "El cajón que ya estaba sigue conectado con la contraseña que leyó", a.conexion);
                        prueba.inicioViejo();
                    });
                });
            });
        });
    }

    // Inicio se vuelve a leer al abrir el cajón solo si tiene más de
    // inicioVale (60 s; aquí se baja a medio segundo).
    function inicioViejo() {
        const antes = a.inicioCargado;
        a.refrescar();
        prueba.dormir(1500, () => {
            prueba.comprobar(a.inicioCargado === antes, "refrescar() con Inicio de menos de 60 s no lo vuelve a leer", String(a.inicioCargado));
            // Una tarea nueva en el vault, en la última sección (En pausa).
            prueba.sh("printf '%s\\n' \"- [ ] Pausada nueva 📅 $(date -d '-20 days' +%F)\" >> \"$PANEL_LOCAL_DIR/vault/00 Inicio.md\"", () => {
                a.inicioVale = 500;
                prueba.dormir(700, () => {
                    a.refrescar();
                    prueba.esperar(5000, () => a.inicioCargado !== antes, ok => {
                        const t = a.inicio ? a.inicio.tareas : [];
                        prueba.comprobar(ok && t.length === 5 && t[4].texto === "Pausada nueva" && t[4].cuando === "vencida hace 20 días", "refrescar() con Inicio viejo lo vuelve a leer (y trae la tarea nueva)", t.length ? t[4].texto + ", " + t[4].cuando : "");
                        a.inicioVale = 60000;
                        prueba.vigia();
                    });
                });
            });
        });
    }

    // Una conexión que calla: el panel congelado (docker pause) no manda ni
    // los «: ping». refrescar() la da por cortada pasado medio vigía, y el
    // vigía la corta a los silencioMax.
    function vigia() {
        prueba.guardarClave(prueba.dir + "/clave", () => {
            prueba.c = otroApi.createObject(prueba, {
                silencioMax: 6000
            });
            prueba.esperar(10000, () => prueba.c.conexion === "conectado", ok => {
                prueba.comprobar(ok, "Otro cajón, con el vigía a 6 s, conecta", prueba.c.conexion);
                prueba.sh("'" + prueba.panelLocal + "' congelar", () => {
                    prueba.dormir(3500, () => {
                        const antes = prueba.c.intentos;
                        prueba.c.refrescar();
                        prueba.esperar(2000, () => prueba.c.intentos === antes + 1, ok2 => {
                            prueba.comprobar(ok2 && prueba.c.conexion === "conectando", "refrescar() con la conexión callada más de medio vigía vuelve a conectar ya", prueba.c.conexion + ", intentos " + prueba.c.intentos);
                            const t0 = Date.now();
                            prueba.esperar(9000, () => prueba.c.conexion === "sin-conexion", ok3 => {
                                prueba.comprobar(ok3 && prueba.c.error.indexOf("Sin noticias") === 0, "Con el panel congelado, el vigía corta la conexión callada: \"sin-conexion\"", "en " + (Date.now() - t0) + " ms; error «" + prueba.c.error + "»");
                                prueba.sh("'" + prueba.panelLocal + "' descongelar", () => {
                                    prueba.esperar(prueba.c.esperaMs + 6000, () => prueba.c.conexion === "conectado", ok4 => {
                                        prueba.comprobar(ok4, "Descongelado, reconecta solo", prueba.c.conexion);
                                        prueba.comprobar(a.conexion === "conectado", "  y el primer cajón (vigía de 70 s) ni se ha enterado", a.conexion);
                                        prueba.fase3();
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    }


    // =========================================================================
    // Fase 3: tareas, hábitos y Aules, contra los endpoints de verdad del
    // panel local. Las escrituras van al vault falso, nunca a otro sitio.
    // =========================================================================

    // Una tras otra: cada paso recibe «sig» y lo llama cuando acaba.
    function serie(lista) {
        let i = 0;
        const sig = () => {
            if (i < lista.length) {
                try {
                    lista[i++](sig);
                } catch (e) {
                    prueba.comprobar(false, "excepción en un paso: " + e);
                    prueba.fin();
                }
            }
        };
        sig();
    }

    // ¿Sale ese texto en una línea de 00 Inicio.md del vault falso?
    function enNota(fragmento, luego) {
        prueba.sh("grep -q -F -- '" + fragmento + "' \"$PANEL_LOCAL_DIR/vault/00 Inicio.md\"", c => luego(c === 0));
    }

    function tarea(texto) {
        for (const s of a.tareas ? a.tareas.secciones : [])
            for (const t of s.tareas)
                if (t.texto === texto)
                    return t;
        return null;
    }

    function fechaMas(n) {
        const d = new Date();
        d.setDate(d.getDate() + n);
        const dos = x => (x < 10 ? "0" : "") + x;
        return d.getFullYear() + "-" + dos(d.getMonth() + 1) + "-" + dos(d.getDate());
    }

    // Una escritura de tareas y su resultado.
    function escribe(f, luego) {
        prueba.res = undefined;
        f(ok => {
            prueba.res = ok;
        });
        prueba.esperar(8000, () => prueba.res !== undefined, () => luego(prueba.res));
    }

    property var res: undefined

    function fase3() {
        prueba.serie([
            // --- Lo que se lee al conectar ---
            sig => prueba.esperar(8000, () => a.tareas !== null && a.habitos !== null && a.clase !== null, ok => {
                    prueba.comprobar(ok, "Al conectar se leen las tareas, los hábitos y lo de Aules", String(a.tareas !== null) + String(a.habitos !== null) + String(a.clase !== null));
                    const t = a.tareas;
                    prueba.comprobar(t && t.habilitado && t.error === "" && prueba.igual(t.secciones.map(s => s.id), ["homelab", "clase", "general", "en-pausa"]), "tareas: las cuatro secciones de la nota", t ? JSON.stringify(t.secciones.map(s => s.id)) : "");
                    prueba.comprobar(t && t.secciones[0].color === "#6aa8ff" && t.secciones[1].color === "#b48cff" && t.secciones[2].color === "" && t.secciones[3].pausa === true, "  con el color de cada proyecto y la de En pausa marcada", t ? JSON.stringify(t.secciones.map(s => s.color)) : "");
                    prueba.comprobar(t && /^[0-9a-f]{64}$/.test(t.version) && /^\d{4}-\d\d-\d\d$/.test(t.hoy) && a.tareasCargadas instanceof Date, "  la versión, el día de hoy y cuándo se leyeron", t ? t.version.slice(0, 8) + " " + t.hoy : "");
                    const f = prueba.tarea("Cambiar el filtro del agua");
                    prueba.comprobar(f && f.area === "Casa" && f.vence === prueba.fechaMas(0) && f.dias === 0 && f.venceHoy && f.prioridad === "" && f.efectiva === "maxima" && f.subida === "vence hoy" && !f.hecha && !f.fijada, "  una tarea de hoy sin prioridad: sube a máxima, con el motivo", f ? JSON.stringify(f) : "no está");
                    const d = prueba.tarea("Mirar los discos");
                    prueba.comprobar(d && d.prioridad === "media" && d.dias === 5 && prueba.igual(d.detalles, ["Comprobar el estado SMART"]) && prueba.igual(d.subtareas, [{ texto: "Hacer la copia antes", hecha: false }, { texto: "Mirar el aviso", hecha: true }]), "  una con detalles y subtareas", d ? JSON.stringify(d) : "no está");
                    const u = prueba.tarea("Una sin fecha");
                    prueba.comprobar(u && u.fijada && u.prioridad === "baja" && u.dias === null && u.vence === "", "  una fijada, sin fecha", u ? JSON.stringify(u) : "no está");
                    const h = prueba.tarea("Una tarea ya hecha");
                    prueba.comprobar(h && h.hecha && h.hechaEl === prueba.fechaMas(-1), "  una hecha, con su día", h ? JSON.stringify(h) : "no está");
                    const e = prueba.tarea("Entrega de [[prueba]]");
                    prueba.comprobar(e && e.plano === "Entrega de prueba" && e.prioridad === "maxima" && t.areas.indexOf("Casa") >= 0, "  el texto con enlaces (texto) y sin marcas (plano), y las áreas", e ? e.texto + " / " + e.plano : "no está");
                    sig();
                }),
            // --- Inicio: marcar y desmarcar con el id de su tarjeta ---
            sig => {
                const l = a.inicio ? a.inicio.tareas : [];
                const pos = l.findIndex(t => t.texto === "Cambiar el filtro del agua");
                const f = l[pos];
                const enTareas = prueba.tarea("Cambiar el filtro del agua");
                prueba.comprobar(!!f && !!enTareas && f.id === enTareas.id && f.hecha === false, "inicio.tareas lleva el id de /api/tareas, el que pide marcarTarea", f ? f.id + " / " + (enTareas ? enTareas.id : "") : "no está");
                const otra = l.find(t => t.texto === "Tarea en otra nota");
                prueba.comprobar(!!otra && otra.id === "", "  y la de otra nota, sin id (no se marca desde el cajón)", otra ? JSON.stringify(otra) : "no está");
                const antes = l.map(t => t.texto);
                let alAcabar = null;
                // Lo que hay en Inicio en cuanto acaba la escritura, sin esperar
                // a nada más.
                prueba.escribe(fin => a.marcarTarea(f ? f.id : "", true, ok => {
                        alAcabar = a.inicio.tareas.slice();
                        fin(ok);
                    }), ok => {
                    const g = alAcabar ? alAcabar[pos] : null;
                    const nueva = prueba.tarea("Cambiar el filtro del agua");
                    prueba.comprobar(ok === true && !!g && g.texto === "Cambiar el filtro del agua" && g.hecha === true && g.cuando === "hecha hoy" && g.vencida === false && !!nueva && g.id === nueva.id, "marcarTarea con el id de Inicio: al acabar, la tarjeta ya está hecha, en su sitio y con el id nuevo", g ? JSON.stringify(g) : JSON.stringify(alAcabar));
                    const textos = (alAcabar || []).map(t => t.texto);
                    prueba.comprobar(prueba.igual(textos.slice(0, antes.length), antes) && textos.length === antes.length + 1, "  las demás siguen igual, y entra la siguiente abierta para que sigan siendo 5", JSON.stringify(textos));
                    prueba.enNota("- [x] **Casa** · Cambiar el filtro del agua", e => {
                        prueba.comprobar(e, "  y 00 Inicio.md la tiene con [x]");
                        prueba.escribe(fin => a.marcarTarea(g ? g.id : "", false, ok2 => {
                                alAcabar = a.inicio.tareas.slice();
                                fin(ok2);
                            }), ok2 => {
                            const h = alAcabar[pos];
                            prueba.comprobar(ok2 === true && !!h && h.texto === "Cambiar el filtro del agua" && h.hecha === false && h.cuando === "hoy" && prueba.igual(alAcabar.map(t => t.texto), antes), "desmarcarla desde Inicio (con el id nuevo): vuelve a estar abierta, y la lista como antes", JSON.stringify(alAcabar.map(t => t.texto + (t.hecha ? " (hecha)" : ""))));
                            prueba.enNota("- [ ] **Casa** · Cambiar el filtro del agua", e2 => {
                                prueba.comprobar(e2, "  y la nota ya no tiene la marca");
                                sig();
                            });
                        });
                    });
                });
            },
            // --- Escribir: hecha y deshecha ---
            sig => {
                const f = prueba.tarea("Cambiar el filtro del agua");
                prueba.escribe(fin => a.marcarTarea(f.id, true, fin), ok => {
                    const g = prueba.tarea("Cambiar el filtro del agua");
                    prueba.comprobar(ok === true && g && g.hecha && g.hechaEl === prueba.fechaMas(0), "marcarTarea: ok, y la lista que vuelve la trae hecha con el día de hoy", g ? JSON.stringify(g) : "");
                    prueba.enNota("- [x] **Casa** · Cambiar el filtro del agua", e => {
                        prueba.comprobar(e, "  y 00 Inicio.md del vault tiene la tarea con [x]");
                        sig();
                    });
                });
            },
            sig => {
                const f = prueba.tarea("Cambiar el filtro del agua");
                prueba.escribe(fin => a.marcarTarea(f.id, false, fin), ok => {
                    const g = prueba.tarea("Cambiar el filtro del agua");
                    prueba.comprobar(ok === true && g && !g.hecha && g.hechaEl === "", "marcarTarea(false): vuelve a estar abierta", g ? JSON.stringify(g) : "");
                    prueba.enNota("- [ ] **Casa** · Cambiar el filtro del agua", e => {
                        prueba.comprobar(e, "  y la nota ya no tiene la marca");
                        sig();
                    });
                });
            },
            // --- Un 409 desde Inicio: la tarjeta tenía un id viejo ---
            sig => {
                const f = (a.inicio ? a.inicio.tareas : []).find(t => t.texto === "Cambiar el filtro del agua");
                const id = f && typeof f.id === "string" ? f.id : "";
                prueba.avisos = [];
                prueba.sh("sed -i 's/Cambiar el filtro del agua/Cambiar el filtro del agua (cambiada)/' \"$PANEL_LOCAL_DIR/vault/00 Inicio.md\"", () => {
                    let alAcabar = null;
                    prueba.escribe(fin => a.marcarTarea(id, true, ok => {
                            alAcabar = a.inicio.tareas.slice();
                            fin(ok);
                        }), ok => {
                        const l = alAcabar || [];
                        const g = l.find(t => t.texto === "Cambiar el filtro del agua (cambiada)");
                        prueba.comprobar(id !== "" && ok === false && prueba.avisos.length === 1 && prueba.avisos[0].texto.indexOf("La nota cambió") === 0, "un id viejo en Inicio (la nota cambió fuera) da 409 y avisa", JSON.stringify(prueba.avisos));
                        prueba.comprobar(!!g && !g.hecha && !l.some(t => t.texto === "Cambiar el filtro del agua"), "  e Inicio se pone al día con lo de fuera, sin marcar nada", JSON.stringify(l.map(t => t.texto)));
                        prueba.enNota("- [ ] **Casa** · Cambiar el filtro del agua (cambiada)", e => {
                            prueba.comprobar(e, "  y la nota se queda como estaba");
                            sig();
                        });
                    });
                });
            },
            // --- Añadir ---
            sig => {
                prueba.escribe(fin => a.anadirTarea({ seccion: "general", texto: "Tarea de prueba desde el cajón", prioridad: "alta", fecha: prueba.fechaMas(3), area: "Prueba" }, fin), ok => {
                    const g = prueba.tarea("Tarea de prueba desde el cajón");
                    prueba.comprobar(ok === true && g && g.area === "Prueba" && g.prioridad === "alta" && g.vence === prueba.fechaMas(3) && g.dias === 3, "anadirTarea: sección, prioridad, fecha y área", g ? JSON.stringify(g) : "");
                    prueba.comprobar(a.tareas.secciones.find(s => s.id === "general").tareas.some(t => t.texto === "Tarea de prueba desde el cajón"), "  y está en la sección que se pidió");
                    prueba.enNota("Tarea de prueba desde el cajón ⏫ 📅 " + prueba.fechaMas(3), e => {
                        prueba.comprobar(e, "  y en la nota, con ⏫ y 📅");
                        sig();
                    });
                });
            },
            // --- Editar ---
            sig => {
                const f = prueba.tarea("Mirar los discos");
                prueba.escribe(fin => a.editarTarea(f.id, { fijada: true, prioridad: "minima", texto: "Mirar los discos (editado)" }, fin), ok => {
                    const g = prueba.tarea("Mirar los discos (editado)");
                    prueba.comprobar(ok === true && g && g.fijada && g.prioridad === "minima", "editarTarea: fijar, prioridad y texto de una vez", g ? JSON.stringify(g) : "");
                    prueba.comprobar(g && prueba.igual(g.detalles, ["Comprobar el estado SMART"]) && g.subtareas.length === 2, "  sin tocar sus detalles ni sus subtareas");
                    prueba.enNota("Mirar los discos (editado) ⏬ 📌 📅 " + prueba.fechaMas(5), e => {
                        prueba.comprobar(e, "  y la nota lleva 📌 y ⏬ (sin ⏫ ni 🔼)");
                        sig();
                    });
                });
            },
            sig => {
                const f = prueba.tarea("Mirar los discos (editado)");
                prueba.escribe(fin => a.editarTarea(f.id, { detalles: ["Una línea", "**Etiqueta**: otra"], subtareas: [{ texto: "Hacer la copia antes", hecha: true }, { texto: "Una nueva", hecha: false }] }, fin), ok => {
                    const g = prueba.tarea("Mirar los discos (editado)");
                    prueba.comprobar(ok === true && g && prueba.igual(g.detalles, ["Una línea", "**Etiqueta**: otra"]) && prueba.igual(g.subtareas, [{ texto: "Hacer la copia antes", hecha: true }, { texto: "Una nueva", hecha: false }]), "editarTarea: detalles y subtareas se sustituyen", g ? JSON.stringify(g.detalles) + JSON.stringify(g.subtareas) : "");
                    sig();
                });
            },
            sig => {
                const f = prueba.tarea("Mirar los discos (editado)");
                prueba.escribe(fin => a.editarTarea(f.id, { seccion: "clase", fecha: "", prioridad: "" }, fin), ok => {
                    const g = prueba.tarea("Mirar los discos (editado)");
                    const s = a.tareas.secciones.find(x => x.id === "clase");
                    prueba.comprobar(ok === true && g && s.tareas.indexOf(g) >= 0 && g.vence === "" && g.dias === null && g.prioridad === "" && g.subtareas.length === 2, "editarTarea: cambiar de sección, quitar la fecha y la prioridad", g ? JSON.stringify(g) : "");
                    sig();
                });
            },
            // --- Una escritura a la vez ---
            sig => {
                a.anadirTarea({ seccion: "general", texto: "Primera de dos" });
                const ocupado = a.tareasOcupado;
                let segunda = "sin llamar";
                a.anadirTarea({ seccion: "general", texto: "Segunda de dos" }, ok => {
                    segunda = ok;
                });
                prueba.comprobar(ocupado === true && segunda === false, "con una escritura en camino, otra no sale (tareasOcupado)", "ocupado " + ocupado + ", segunda " + segunda);
                prueba.esperar(8000, () => !a.tareasOcupado, ok => {
                    prueba.comprobar(ok && !!prueba.tarea("Primera de dos") && !prueba.tarea("Segunda de dos"), "  la primera se escribe y la segunda no");
                    sig();
                });
            },
            // --- Un 409: la nota cambió por otro lado ---
            sig => {
                const f = prueba.tarea("Una sin fecha");
                const id = f.id;
                prueba.avisos = [];
                // Se cambia la línea de la tarea en el vault (como Obsidian).
                prueba.sh("sed -i 's/Una sin fecha 🔽/Una sin fecha (cambiada) 🔽/' \"$PANEL_LOCAL_DIR/vault/00 Inicio.md\"", () => {
                    prueba.escribe(fin => a.marcarTarea(id, true, fin), ok => {
                        const g = prueba.tarea("Una sin fecha (cambiada)");
                        prueba.comprobar(ok === false, "un id viejo (la nota cambió fuera) da 409: la escritura no sale", String(ok));
                        prueba.comprobar(!!g && !g.hecha && !prueba.tarea("Una sin fecha"), "  se recarga la lista con lo de fuera y no se marca nada", g ? JSON.stringify(g) : "sin la tarea cambiada");
                        prueba.comprobar(prueba.avisos.length === 1 && prueba.avisos[0].error === true && prueba.avisos[0].texto.indexOf("La nota cambió") === 0, "  y avisa con una línea", JSON.stringify(prueba.avisos));
                        prueba.enNota("- [ ] Una sin fecha (cambiada)", e => {
                            prueba.comprobar(e, "  y la nota se queda como estaba");
                            sig();
                        });
                    });
                });
            },
            // --- Un fallo que no es 409 ---
            sig => {
                prueba.avisos = [];
                const f = prueba.tarea("Primera de dos");
                prueba.escribe(fin => a.editarTarea(f.id, { fecha: "no-es-una-fecha" }, fin), ok => {
                    prueba.comprobar(ok === false && prueba.avisos.length === 1 && prueba.avisos[0].texto === "No se pudo guardar la tarea (HTTP 422: La fecha debe ser AAAA-MM-DD y existir.)", "una escritura que el NUC rechaza (422): avisa con el motivo y no cambia nada", JSON.stringify(prueba.avisos));
                    sig();
                });
            },
            // --- Hábitos ---
            sig => {
                const h = a.habitos;
                const hoy = prueba.fechaMas(0);
                prueba.comprobar(h && h.habilitado && /^\d{4}-S\d\d$/.test(h.semana) && h.existe === false && h.hoy && h.hoy.fecha === hoy && h.hoy.gym === null && h.hoy.energia === null && h.totales.gym === "–", "habitos: la semana, hoy sin marcar y la nota de la semana sin crear", h ? JSON.stringify(h) : "");
                a.anotarHabito("gym", "si");
                prueba.comprobar(a.habitos.hoy.gym === true, "anotarHabito: el cambio se ve al momento (antes de que conteste el NUC)");
                prueba.esperar(8000, () => a.habitos.existe === true, ok => {
                    prueba.comprobar(ok && a.habitos.hoy.gym === true && a.habitos.totales.gym === "1/7", "  y con la respuesta, la nota de la semana ya existe y el total es 1/7", JSON.stringify(a.habitos));
                    prueba.sh("ls \"$PANEL_LOCAL_DIR/vault/30 Áreas/Revisiones/Semanas/\"*.md >/dev/null", c => {
                        prueba.comprobar(c === 0, "  y se ha creado desde la plantilla en el vault");
                        sig();
                    });
                });
            },
            sig => {
                a.anotarHabito("energia", "6");
                prueba.esperar(8000, () => a.habitos.hoy.energia === 6 && a.habitos.totales.energia === "6", ok => {
                    prueba.comprobar(ok, "energía 6", JSON.stringify(a.habitos.hoy) + " " + a.habitos.totales.energia);
                    a.anotarHabito("gym", "no");
                    prueba.esperar(8000, () => a.habitos.hoy.gym === false, ok2 => {
                        prueba.comprobar(ok2 && a.habitos.totales.gym === "0/7", "gym «no»: false, y el total no lo cuenta", JSON.stringify(a.habitos.hoy));
                        a.anotarHabito("gym", "");
                        prueba.esperar(8000, () => a.habitos.hoy.gym === null, ok3 => {
                            prueba.comprobar(ok3, "gym sin marcar: null");
                            sig();
                        });
                    });
                });
            },
            sig => {
                prueba.avisos = [];
                a.anotarHabito("energia", "11");
                const optimista = a.habitos.hoy.energia === 11;
                prueba.esperar(8000, () => prueba.avisos.length > 0, ok => {
                    prueba.comprobar(optimista && ok && a.habitos.hoy.energia === 6 && prueba.avisos[0].error === true && prueba.avisos[0].texto.indexOf("No se pudo guardar el hábito (HTTP 422") === 0, "un valor que el NUC rechaza: se ve un momento, se deshace y avisa", JSON.stringify(prueba.avisos) + " " + a.habitos.hoy.energia);
                    sig();
                });
            },
            // --- Aules ---
            sig => {
                const c = a.clase;
                prueba.comprobar(c && c.estado === "error" && c.ejecutando === false && c.terminado === null && c.error === "No se puede consultar systemd." && c.tareas === null && c.calendario === null && c.calendarioConectado === false && c.calendarioPersonalError === "", "clase: lo que da GET /api/clase/sync (sin systemd en el panel de prueba)", c ? JSON.stringify(c) : "");
                prueba.avisos = [];
                const antes = a.clase;
                a.actualizarAules();
                prueba.comprobar(a.clase.ejecutando === true && a.clase.estado === "ejecutando", "actualizarAules: se ve en marcha al momento");
                prueba.esperar(8000, () => prueba.avisos.length > 0, ok => {
                    prueba.comprobar(ok && a.clase.ejecutando === false && prueba.avisos[0].texto.indexOf("Aules: no se pudo lanzar (HTTP 502") === 0, "  y como el NUC no puede lanzarla, vuelve a como estaba y avisa", JSON.stringify(prueba.avisos));
                    sig();
                });
            },
            // --- Los eventos «tareas» y «clase» ---
            sig => {
                const leida = a.tareasCargadas;
                a.bloque("event: tareas\ndata: {\"version\":\"" + a.tareas.version + "\"}\n\n");
                prueba.dormir(1000, () => {
                    prueba.comprobar(a.tareasCargadas === leida, "evento «tareas» con la versión que ya se tiene: no vuelve a leer");
                    // Otra versión: se relee (el vault ha cambiado por fuera).
                    prueba.sh("printf '%s\\n' '- [ ] Escrita fuera, en Obsidian' >> \"$PANEL_LOCAL_DIR/vault/00 Inicio.md\"", () => {
                        a.bloque("event: tareas\ndata: {\"version\":\"otra\"}\n\n");
                        prueba.esperar(8000, () => prueba.tarea("Escrita fuera, en Obsidian") !== null, ok => {
                            prueba.comprobar(ok, "evento «tareas» con otra versión: relee y trae lo escrito fuera");
                            sig();
                        });
                    });
                });
            },
            sig => {
                a.editandoTarea = true;
                const leida = a.tareasCargadas;
                prueba.sh("printf '%s\\n' '- [ ] Escrita fuera mientras se edita' >> \"$PANEL_LOCAL_DIR/vault/00 Inicio.md\"", () => {
                    a.bloque("event: tareas\ndata: {\"version\":\"otra más\"}\n\n");
                    prueba.dormir(1200, () => {
                        prueba.comprobar(a.tareasObsoletas === true && a.tareasCargadas === leida && prueba.tarea("Escrita fuera mientras se edita") === null, "evento «tareas» mientras se edita: obsoletas, y no relee");
                        a.editandoTarea = false;
                        prueba.esperar(8000, () => prueba.tarea("Escrita fuera mientras se edita") !== null, ok => {
                            prueba.comprobar(ok && a.tareasObsoletas === false, "  al cerrar el editor relee solo");
                            sig();
                        });
                    });
                });
            },
            sig => {
                prueba.avisos = [];
                a.bloque("event: clase\ndata: " + JSON.stringify({ estado: "ejecutando", ejecutando: true, resultado: "", terminado: null, tareas: null, calendario: null, calendarioConectado: true, calendarioPersonal: null }) + "\n\n");
                prueba.comprobar(a.clase.ejecutando === true && a.clase.calendarioConectado === true, "evento «clase» (en marcha): lo mismo que GET /api/clase/sync");
                const leida = a.tareasCargadas;
                const terminado = new Date(Date.now() - 90000).toISOString();
                a.bloque("event: clase\ndata: " + JSON.stringify({ estado: "ok", ejecutando: false, resultado: "success", terminado: terminado, tareas: { at: terminado, anadidas: 2, fechas: 1, completadas: 0 }, calendario: { at: terminado, creados: 1, cambiados: 0, borrados: 0 }, calendarioConectado: true, calendarioPersonal: { at: terminado, creados: 0, cambiados: 0, borrados: 0, error: "sin permiso" } }) + "\n\n");
                const c = a.clase;
                prueba.comprobar(c.estado === "ok" && !c.ejecutando && c.terminado instanceof Date && Math.abs(c.terminado.getTime() - Date.parse(terminado)) < 1000 && c.tareas.anadidas === 2 && c.tareas.fechas === 1 && c.calendario.creados === 1 && c.calendarioPersonalError === "sin permiso", "evento «clase» (acabada): normalizado, con fechas y fallo del calendario Personal", JSON.stringify(c));
                prueba.comprobar(prueba.avisos.length === 1 && prueba.avisos[0].texto === "Aules actualizado" && prueba.avisos[0].error === false, "  y avisa de que acabó", JSON.stringify(prueba.avisos));
                prueba.esperar(8000, () => a.tareasCargadas !== leida, ok => {
                    prueba.comprobar(ok, "  y al acabar una en marcha relee las tareas (el cruce pudo cambiarlas)");
                    sig();
                });
            },
            // --- Cuándo se vuelve a leer ---
            sig => {
                const leida = a.tareasCargadas;
                a.refrescar();
                prueba.dormir(1200, () => {
                    prueba.comprobar(a.tareasCargadas === leida, "refrescar() con las tareas de menos de 60 s no las vuelve a leer");
                    a.inicioVale = 500;
                    prueba.dormir(700, () => {
                        a.refrescar();
                        prueba.esperar(5000, () => a.tareasCargadas !== leida, ok => {
                            prueba.comprobar(ok, "refrescar() con las tareas viejas las vuelve a leer");
                            a.inicioVale = 60000;
                            sig();
                        });
                    });
                });
            },
            sig => {
                // La contraseña no se ha colado en los avisos.
                const todo = JSON.stringify(prueba.avisos) + JSON.stringify(a.tareas) + JSON.stringify(a.habitos) + JSON.stringify(a.clase);
                prueba.comprobar(todo.indexOf("Pr0ba-") < 0, "ni los avisos ni los datos de la fase 3 llevan la contraseña");
                prueba.fase4();
            }
        ]);
    }

    // =========================================================================
    // Fase 4: el servidor (los stacks, las acciones de Docker, los logs y el
    // consumo), el Registro, los proyectos y GitHub, contra el panel local.
    // Las acciones llegan al Docker falso; los proyectos se escriben en el
    // vault falso; GitHub no tiene token, así que nunca se le habla.
    // =========================================================================

    property var resultados: []
    property var m: null
    property var movilAvisos: []

    Connections {
        target: a
        function onResultado(r) {
            prueba.resultados.push(r);
        }
    }

    // Las líneas del Registro van por su hora (no por su id: una acción se
    // apunta al acabar con la hora a la que empezó).
    function deNuevaAVieja(entradas) {
        return entradas.every((e, i) => i === 0 || e.hora.getTime() <= entradas[i - 1].hora.getTime());
    }

    // Lo mismo, sin mirar el orden de las claves.
    function igualObj(x, y) {
        const orden = o => JSON.stringify(Object.keys(o || {}).sort().map(k => [k, o[k]]));
        return orden(x) === orden(y);
    }

    function stack(nombre, api) {
        return (api || a).stacks.find(s => s.nombre === nombre) || null;
    }

    function contenedor(nombre, api) {
        for (const s of (api || a).stacks)
            for (const c of s.contenedores)
                if (c.nombre === nombre)
                    return c;
        return null;
    }

    function proyecto(titulo) {
        return (a.proyectos || []).find(p => p.titulo === titulo) || null;
    }

    function enFichero(ruta, fragmento, luego) {
        prueba.sh("grep -q -F -- '" + fragmento + "' \"$PANEL_LOCAL_DIR/vault/" + ruta + "\"", c => luego(c === 0));
    }

    // Cuántas veces se ha lanzado curl contra esa ruta. En ordenes.txt la
    // dirección va en su propia línea (el -w de curl lleva saltos de línea).
    function contarCurl(ruta, luego) {
        prueba.sh("exit $(grep -c -- '" + ruta + "$' \"$PRUEBA_DIR/ordenes.txt\")", c => luego(c));
    }

    // ¿Hay un curl corriendo con eso?
    function curlVivo(patron, luego) {
        prueba.sh("ps -eo args | grep -q '[c]url -K - -N .*" + patron + "'", c => luego(c === 0));
    }

    function fase4() {
        prueba.serie([
            // --- Los stacks, en vivo ---
            sig => {
                const nombres = a.stacks.map(s => s.nombre);
                prueba.comprobar(prueba.igual(nombres.slice(0, 3), ["homelab", "sync", "immich"]) && nombres.indexOf("traderepublic") >= 0 && nombres.indexOf("") >= 0, "stacks: los de la configuración del panel primero, después los demás y los sueltos", JSON.stringify(nombres));
                const h = prueba.stack("homelab");
                prueba.comprobar(h && h.gestionado && !h.protegido && h.ocupado === "" && prueba.igualObj(h.acciones, { up: "", stop: "homelab", down: "homelab", update: "homelab" }), "  homelab: del panel, con las acciones y palabras del NUC (parar todo pide su nombre: lleva caddy)", h ? JSON.stringify(h.acciones) : "");
                const caddy = prueba.contenedor("caddy");
                prueba.comprobar(caddy && caddy.critico && caddy.estado === "running" && caddy.salud === "healthy" && caddy.desde instanceof Date && caddy.hasta === null && caddy.ocupado === "" && prueba.igualObj(caddy.acciones, { start: "", stop: "caddy", restart: "" }), "  caddy: crítico, sano, desde cuándo, y pararlo pide su nombre", caddy ? JSON.stringify(caddy) : "");
                const vw = prueba.contenedor("vaultwarden");
                prueba.comprobar(vw && vw.estado === "exited" && vw.codigo === 1 && vw.hasta instanceof Date && prueba.igualObj(vw.acciones, { start: "", stop: "", restart: "" }), "  vaultwarden: parado con código 1, con su hora y sin palabras", vw ? JSON.stringify(vw) : "");
                const im = prueba.stack("immich");
                prueba.comprobar(im && im.protegido && prueba.igualObj(im.acciones, { up: "immich", stop: "immich" }) && prueba.igualObj(prueba.contenedor("immich_server").acciones, { start: "immich", stop: "immich", restart: "immich" }), "  immich, protegido: solo levantar y parar, y todo con su nombre", im ? JSON.stringify(im.acciones) : "");
                const tr = prueba.stack("traderepublic");
                prueba.comprobar(tr && !tr.gestionado && prueba.igual(tr.acciones, {}) && tr.contenedores.length === 1 && prueba.igual(tr.contenedores[0].acciones, {}) && tr.contenedores[0].unUso, "  un stack que no es del panel: sin acciones", tr ? JSON.stringify(tr) : "");
                prueba.comprobar(a.puedeDocker === true && a.dockerError === "", "puedeDocker, de /api/yo, y sin error de Docker");
                prueba.comprobar(a.alertas.length > 0 && a.alertas.every(x => typeof x.entrada === "number" && x.entrada >= 0), "las alertas llevan «entrada» (su línea del Registro, o 0)", JSON.stringify(a.alertas.map(x => x.entrada)));
                sig();
            },
            // --- El Registro ---
            sig => {
                a.cargarRegistro("");
                prueba.esperar(8000, () => a.registro !== null && !a.registro.cargando, ok => {
                    const r = a.registro;
                    prueba.comprobar(ok && r.error === "" && r.entradas.length > 0 && prueba.deNuevaAVieja(r.entradas), "cargarRegistro(\"\"): las líneas, de la más nueva a la más vieja", r.entradas.length + " líneas; «" + r.error + "»");
                    const d = r.entradas.find(e => e.titulo.indexOf("Disco casi lleno") === 0);
                    prueba.comprobar(!!d && d.fuente === "disk" && d.nivel === "warn" && d.hora instanceof Date && d.conDetalle === true && d.objetivo === "/", "  normalizadas: fuente, nivel, hora (Date), objetivo y si tienen detalle", d ? JSON.stringify(d) : "");
                    prueba.comprobar(r.notas.some(n => n.indexOf("systemd") >= 0), "  y las notas de lo que el panel no puede ver", JSON.stringify(r.notas));
                    sig();
                });
            },
            // --- Una acción y cómo acaba ---
            sig => {
                prueba.resultados = [];
                prueba.avisos = [];
                const antes = a.registro.entradas.length;
                prueba.escribe(fin => a.accionDocker("contenedor", "syncthing", "restart", "", fin), ok => {
                    prueba.comprobar(ok === true, "accionDocker (reiniciar syncthing): el NUC la acepta (202)", String(ok));
                    prueba.esperar(8000, () => prueba.resultados.length > 0, ok2 => {
                        const r = prueba.resultados[0];
                        prueba.comprobar(ok2 && r.tipo === "contenedor" && r.objetivo === "syncthing" && r.accion === "restart" && r.ok === true && r.error === "", "  cómo acaba llega por el evento «result»", JSON.stringify(r));
                        prueba.comprobar(prueba.avisos.some(x => x.texto === "Reiniciar · syncthing: hecho" && x.error === false), "  y sale como aviso", JSON.stringify(prueba.avisos));
                        prueba.esperar(5000, () => a.registro.entradas.length > antes && a.registro.entradas[0].titulo === "Reiniciar contenedor · syncthing", ok3 => {
                            const e = a.registro.entradas[0];
                            prueba.comprobar(ok3 && e.fuente === "panel" && e.nivel === "info" && e.conDetalle && e.objetivo === "syncthing", "  y su línea llega sola al Registro (evento «journal»), arriba", JSON.stringify(e));
                            let det = null;
                            a.detalleRegistro(e.id, (texto, error) => det = {
                                    texto: texto,
                                    error: error
                                });
                            prueba.esperar(5000, () => det !== null, ok4 => {
                                prueba.comprobar(ok4 && det.error === "" && det.texto.indexOf("Por: " + prueba.usuarioPrueba) === 0 && det.texto.indexOf("Duración:") > 0, "detalleRegistro: el detalle de la línea (quién y cuánto tardó)", JSON.stringify(det));
                                sig();
                            });
                        });
                    });
                });
            },
            // --- La palabra de confirmación ---
            sig => {
                prueba.avisos = [];
                prueba.escribe(fin => a.accionDocker("contenedor", "caddy", "stop", "", fin), ok => {
                    prueba.comprobar(ok === false && prueba.avisos.length === 1 && prueba.avisos[0].texto === "Parar · caddy: hay que escribir «caddy» para confirmarla", "parar caddy sin su nombre: el NUC no lo hace (428) y se dice qué escribir", JSON.stringify(prueba.avisos));
                    prueba.resultados = [];
                    prueba.escribe(fin => a.accionDocker("contenedor", "caddy", "stop", "caddy", fin), ok2 => {
                        prueba.esperar(8000, () => prueba.resultados.length > 0, ok3 => {
                            prueba.comprobar(ok2 === true && ok3 && prueba.resultados[0].ok && prueba.resultados[0].accion === "stop" && prueba.resultados[0].objetivo === "caddy", "  con «caddy», sí", JSON.stringify(prueba.resultados));
                            sig();
                        });
                    });
                });
            },
            sig => {
                prueba.avisos = [];
                prueba.escribe(fin => a.accionDocker("stack", "sync", "update", "otro", fin), ok => {
                    prueba.comprobar(ok === false && prueba.avisos.length === 1 && prueba.avisos[0].texto === "Actualizar · sync: hay que escribir «sync» para confirmarla", "actualizar un stack con otra palabra: no", JSON.stringify(prueba.avisos));
                    prueba.resultados = [];
                    prueba.escribe(fin => a.accionDocker("stack", "sync", "down", "sync", fin), ok2 => {
                        prueba.esperar(8000, () => prueba.resultados.length > 0, ok3 => {
                            const r = prueba.resultados[0];
                            prueba.comprobar(ok2 === true && ok3 && r.tipo === "stack" && r.objetivo === "sync" && r.accion === "down" && r.ok, "bajar un stack con su nombre: se hace (docker compose down)", JSON.stringify(r));
                            prueba.avisos = [];
                            prueba.escribe(fin => a.accionDocker("contenedor", "no-existe", "restart", "", fin), ok4 => {
                                prueba.comprobar(ok4 === false && prueba.avisos.length === 1 && prueba.avisos[0].texto === "Reiniciar · no-existe: ya no está en el NUC", "un contenedor que no está: 404, y se dice", JSON.stringify(prueba.avisos));
                                sig();
                            });
                        });
                    });
                });
            },
            // --- El Registro: filtros y páginas ---
            sig => {
                a.cargarRegistro("panel");
                prueba.esperar(8000, () => a.registro.filtro === "panel" && !a.registro.cargando, ok => {
                    const r = a.registro;
                    prueba.comprobar(ok && r.entradas.length >= 3 && r.entradas.every(e => e.fuente === "panel"), "cargarRegistro(\"panel\"): solo lo del panel", JSON.stringify(r.entradas.map(e => e.titulo)));
                    prueba.comprobar(r.entradas.some(e => e.titulo === "Bajar stack · sync") && r.entradas.some(e => e.titulo === "Parar contenedor · caddy"), "  con las acciones de antes");
                    a.cargarRegistro("level:warn");
                    prueba.esperar(8000, () => a.registro.filtro === "level:warn" && !a.registro.cargando, ok2 => {
                        const w = a.registro;
                        prueba.comprobar(ok2 && w.entradas.length > 0 && w.entradas.every(e => e.nivel !== "info"), "cargarRegistro(\"level:warn\"): solo avisos y errores", JSON.stringify(w.entradas.map(e => e.nivel)));
                        sig();
                    });
                });
            },
            sig => {
                a.paginaRegistro = 2;
                a.cargarRegistro("");
                prueba.esperar(8000, () => a.registro.filtro === "" && !a.registro.cargando, ok => {
                    const r = a.registro;
                    prueba.comprobar(ok && r.entradas.length === 2 && r.mas === true && r.siguiente !== "", "con páginas de 2: la primera, y que hay más", r.entradas.length + " " + r.mas);
                    const primeras = r.entradas.map(e => e.id);
                    a.masRegistro();
                    prueba.esperar(8000, () => !a.registro.cargando && a.registro.entradas.length > 2, ok2 => {
                        const ids = a.registro.entradas.map(e => e.id);
                        const sinRepetir = ids.every((x, i) => ids.indexOf(x) === i);
                        prueba.comprobar(ok2 && ids.length === 4 && prueba.igual(ids.slice(0, 2), primeras) && sinRepetir && prueba.deNuevaAVieja(a.registro.entradas), "masRegistro(): la página siguiente, más vieja, detrás y sin repetir", JSON.stringify(ids));
                        a.paginaRegistro = 50;
                        sig();
                    });
                });
            },
            // --- Los logs ---
            sig => {
                a.abrirLogs("caddy");
                prueba.comprobar(a.logs !== null && a.logs.contenedor === "caddy" && a.logs.estado === "conectando", "abrirLogs: «conectando» al momento");
                prueba.esperar(8000, () => a.logs && a.logs.estado === "fin", ok => {
                    const l = a.logs;
                    const linea = l ? l.lineas.find(x => !x.nota) : null;
                    prueba.comprobar(ok && !!linea && linea.texto === "línea de prueba del contenedor" && /^\d\d:\d\d:\d\d$/.test(linea.hora), "  las líneas del contenedor, con su hora (la de aquí)", l ? JSON.stringify(l.lineas) : "");
                    const ultima = l ? l.lineas[l.lineas.length - 1] : null;
                    prueba.comprobar(ultima && ultima.nota && ultima.texto === "— fin del log (el contenedor se ha parado)" && l.total === l.lineas.length, "  y «fin» cuando el log acaba (el contenedor se ha parado)", l ? JSON.stringify(l) : "");
                    a.abrirLogs("no-existe");
                    prueba.esperar(8000, () => a.logs && a.logs.estado === "cortado", ok2 => {
                        prueba.comprobar(ok2 && a.logs.contenedor === "no-existe" && a.logs.error === "Ese contenedor ya no está en el NUC.", "abrirLogs de uno que no está: «cortado», y por qué", a.logs ? JSON.stringify(a.logs) : "");
                        a.cerrarLogs();
                        prueba.comprobar(a.logs === null, "cerrarLogs(): null");
                        sig();
                    });
                });
            },
            // --- El consumo, solo mientras se mira ---
            sig => {
                prueba.comprobar(a.consumo === null, "sin verConsumo no hay consumo");
                prueba.contarCurl("/api/stats", n0 => {
                    prueba.comprobar(n0 === 0, "  ni se ha pedido nunca", String(n0));
                    a.verConsumo = true;
                    prueba.esperar(10000, () => a.consumo !== null, ok => {
                        const c = a.consumo;
                        prueba.comprobar(ok && c.host.memTotal > 0 && c.host.memUsada > 0 && c.host.cpu >= 0 && c.cuando instanceof Date && c.host.discos.length === 1 && c.host.discos[0].ruta === "/" && c.host.discos[0].total > 0, "verConsumo: el consumo del NUC (CPU, memoria y discos)", c ? JSON.stringify(c.host) : "");
                        const cd = c ? c.contenedores.caddy : null;
                        prueba.comprobar(!!cd && Math.abs(cd.cpu - 40) < 0.01 && cd.mem === 190 * 1048576 && cd.memLimite === 2 * 1073741824, "  y el de cada contenedor en marcha", c ? JSON.stringify(c.contenedores) : "");
                        const primera = c ? c.cuando : null;
                        prueba.esperar(8000, () => a.consumo && a.consumo.cuando !== primera, ok2 => {
                            prueba.comprobar(ok2, "  y otra muestra a los pocos segundos, sola");
                            a.verConsumo = false;
                            prueba.comprobar(a.consumo === null, "verConsumo a false: se olvida el consumo");
                            prueba.dormir(1500, () => prueba.curlVivo("/api/stats", vivo => {
                                    prueba.contarCurl("/api/stats", n => {
                                        prueba.comprobar(!vivo && n === 1, "  y se para el curl de /api/stats (uno solo en todo el rato)", "vivo " + vivo + ", lanzados " + n);
                                        a.verConsumo = true;
                                        prueba.esperar(10000, () => a.consumo !== null, ok3 => {
                                            prueba.comprobar(ok3, "verConsumo otra vez: vuelve");
                                            a.verConsumo = false;
                                            sig();
                                        });
                                    });
                                }));
                        });
                    });
                });
            },
            // --- Los proyectos ---
            sig => {
                const pr = prueba.proyecto("Proyecto de prueba");
                const sub = prueba.proyecto("Subproyecto de prueba");
                prueba.comprobar(pr && pr.tipo === "proyecto" && pr.padre === "" && pr.estado === "activo" && pr.prioridad === "media" && pr.progreso === 40 && prueba.igual(pr.siguiente, ["Algo que hacer"]) && pr.siguientePanel === false && pr.repo === "", "proyectos (de /api/personal): el proyecto, con su progreso y el siguiente paso de la nota", pr ? JSON.stringify(pr) : "no está");
                prueba.comprobar(sub && sub.tipo === "subproyecto" && sub.padre === "10 Proyectos/Proyecto de prueba.md" && sub.progreso === null && sub.prioridad === "baja", "  y su subproyecto, con la ruta de su proyecto", sub ? JSON.stringify(sub) : "no está");
                prueba.escribe(fin => a.editarProyecto(sub.ruta, {
                        estado: "pausado",
                        progreso: 55
                    }, fin), ok => {
                    const s2 = prueba.proyecto("Subproyecto de prueba");
                    prueba.comprobar(ok === true && s2.estado === "pausado" && s2.progreso === 55 && s2.actualizado === prueba.fechaMas(0), "editarProyecto: estado y progreso de una vez (y «actualizado», hoy)", JSON.stringify(s2));
                    prueba.enFichero("10 Proyectos/Subproyecto de prueba.md", "estado: pausado", e1 => prueba.enFichero("10 Proyectos/Subproyecto de prueba.md", "progreso: 55", e2 => {
                            prueba.comprobar(e1 && e2, "  y la nota del vault lo tiene en el frontmatter");
                            sig();
                        }));
                });
            },
            sig => {
                const pr = prueba.proyecto("Proyecto de prueba");
                prueba.escribe(fin => a.editarProyecto(pr.ruta, {
                        siguiente: "Uno\n- Dos\n\n",
                        prioridad: "alta"
                    }, fin), ok => {
                    const p2 = prueba.proyecto("Proyecto de prueba");
                    prueba.comprobar(ok === true && prueba.igual(p2.siguiente, ["Uno", "Dos"]) && p2.siguientePanel && p2.prioridad === "alta", "editarProyecto: el siguiente paso pasa a ser el bloque del panel", JSON.stringify(p2));
                    prueba.enFichero("10 Proyectos/Proyecto de prueba.md", "%% panel:siguiente:start %%", e1 => prueba.enFichero("10 Proyectos/Proyecto de prueba.md", "- Algo que hacer", e2 => {
                            prueba.comprobar(e1 && e2, "  y en la nota va al principio de su sección, sin tocar lo que ya había");
                            sig();
                        }));
                });
            },
            sig => {
                prueba.avisos = [];
                const sub = prueba.proyecto("Subproyecto de prueba");
                prueba.sh("sed -i 's/^estado: pausado$/estado: idea/' \"$PANEL_LOCAL_DIR/vault/10 Proyectos/Subproyecto de prueba.md\"", () => {
                    prueba.escribe(fin => a.editarProyecto(sub.ruta, {
                            estado: "activo"
                        }, fin), ok => {
                        const s2 = prueba.proyecto("Subproyecto de prueba");
                        prueba.comprobar(ok === false && s2.estado === "idea", "un proyecto que cambió en la nota (409): no se escribe y se recarga como está", JSON.stringify(s2));
                        prueba.comprobar(prueba.avisos.length === 1 && prueba.avisos[0].error && prueba.avisos[0].texto.indexOf("El proyecto cambió en tus notas") === 0, "  y avisa", JSON.stringify(prueba.avisos));
                        prueba.enFichero("10 Proyectos/Subproyecto de prueba.md", "estado: idea", e => {
                            prueba.comprobar(e, "  y la nota se queda como estaba");
                            sig();
                        });
                    });
                });
            },
            sig => {
                prueba.avisos = [];
                const sub = prueba.proyecto("Subproyecto de prueba");
                prueba.escribe(fin => a.editarProyecto(sub.ruta, {
                        progreso: 150
                    }, fin), ok => {
                    prueba.comprobar(ok === false && prueba.avisos.length === 1 && prueba.avisos[0].texto === "No se pudo guardar el proyecto (HTTP 422: El progreso es un número de 0 a 100.)", "un valor que el NUC rechaza (422): avisa con el motivo", JSON.stringify(prueba.avisos));
                    sig();
                });
            },
            // --- Las escrituras de proyectos, en cola ---
            sig => {
                prueba.avisos = [];
                const sub = prueba.proyecto("Subproyecto de prueba");
                const r = [null, null, null];
                a.editarProyecto(sub.ruta, {
                    estado: "activo"
                }, ok => r[0] = ok);
                const ocupado = a.proyectosOcupado;
                a.editarProyecto(sub.ruta, {
                    estado: "pausado",
                    progreso: 60
                }, ok => r[1] = ok);
                // Lo mismo que deja la de antes: no hace falta escribir nada.
                a.editarProyecto(sub.ruta, {
                    progreso: 60
                }, ok => r[2] = ok);
                prueba.comprobar(ocupado && r[1] === null && r[2] === null, "editarProyecto con otra en camino: espera en cola, no se pierde", JSON.stringify(r));
                prueba.esperar(8000, () => r.every(x => x !== null), ok => {
                    const s2 = prueba.proyecto("Subproyecto de prueba");
                    prueba.comprobar(ok && r.every(x => x === true) && s2.estado === "pausado" && s2.progreso === 60 && prueba.avisos.length === 0, "  y sale al acabar la de antes, sobre lo que ésta dejó (sin 409)", JSON.stringify(r) + " " + s2.estado + " " + s2.progreso + " " + JSON.stringify(prueba.avisos));
                    prueba.enFichero("10 Proyectos/Subproyecto de prueba.md", "estado: pausado", e1 => prueba.enFichero("10 Proyectos/Subproyecto de prueba.md", "progreso: 60", e2 => {
                            prueba.comprobar(e1 && e2, "  y la nota queda con lo último");
                            sig();
                        }));
                });
            },
            sig => {
                prueba.avisos = [];
                const sub = prueba.proyecto("Subproyecto de prueba");
                prueba.sh("sed -i 's/^estado: pausado$/estado: idea/' \"$PANEL_LOCAL_DIR/vault/10 Proyectos/Subproyecto de prueba.md\"", () => {
                    const r = [null, null];
                    a.editarProyecto(sub.ruta, {
                        estado: "hecho"
                    }, ok => r[0] = ok);
                    a.editarProyecto(sub.ruta, {
                        prioridad: "alta"
                    }, ok => r[1] = ok);
                    prueba.esperar(8000, () => r.every(x => x !== null), ok => {
                        const s2 = prueba.proyecto("Subproyecto de prueba");
                        prueba.comprobar(ok && r[0] === false && r[1] === false && s2.estado === "idea" && s2.prioridad === "baja" && prueba.avisos.length === 1, "tras un 409, las que esperaban en cola para ese proyecto no salen", JSON.stringify(r) + " " + JSON.stringify(s2));
                        prueba.enFichero("10 Proyectos/Subproyecto de prueba.md", "prioridad: baja", e => {
                            prueba.comprobar(e, "  y la nota no se toca");
                            sig();
                        });
                    });
                });
            },
            // --- GitHub: el panel de prueba no tiene token ---
            sig => {
                a.cargarGithub();
                prueba.esperar(8000, () => a.github !== null, ok => {
                    prueba.comprobar(ok && a.github.habilitado === false && a.github.error === "", "cargarGithub: sin GITHUB_TOKEN en el NUC, «no habilitado»", JSON.stringify(a.github));
                    a.cargarRepo("IshimiG/homelab");
                    prueba.esperar(8000, () => !!a.repos["ishimig/homelab"] && !a.repos["ishimig/homelab"].cargando, ok2 => {
                        const r = a.repos["ishimig/homelab"];
                        prueba.comprobar(ok2 && r.error === "GitHub sin conectar: falta GITHUB_TOKEN en el NUC." && r.pulls.length === 0, "cargarRepo: sin token, lo dice", JSON.stringify(r));
                        sig();
                    });
                });
            },
            // --- El usuario movil: lo ve todo, pero no actúa (E10, M5) ---
            sig => prueba.sh("secret-tool clear servicio homelab-panel usuario " + prueba.usuarioPrueba + " && secret-tool store --label='Panel del homelab' servicio homelab-panel usuario movil < '" + prueba.dir + "/clave-movil'", () => {
                    prueba.m = otroApi.createObject(prueba);
                    prueba.esperar(10000, () => prueba.m.conexion === "conectado" && prueba.m.permisos !== null && prueba.m.stacks.length > 0, ok => {
                        const m = prueba.m;
                        prueba.comprobar(ok && m.usuario === "movil" && m.puedeDocker === false && prueba.igual(m.permisos, { acciones_docker: false, login_traderepublic: false }), "con el usuario movil: puedeDocker false (de /api/yo)", m.usuario + " " + JSON.stringify(m.permisos));
                        prueba.comprobar(m.stacks.every(s => prueba.igual(s.acciones, {}) && s.contenedores.every(c => prueba.igual(c.acciones, {}))), "  los stacks llegan sin ninguna acción (no hay botones)");
                        m.aviso.connect((texto, error) => prueba.movilAvisos.push(texto));
                        let res = "sin llamar";
                        m.accionDocker("contenedor", "syncthing", "restart", "", r => res = r);
                        prueba.comprobar(res === false && prueba.movilAvisos.length === 1 && prueba.movilAvisos[0] === "Reiniciar · syncthing: el usuario movil no tiene acciones de Docker", "  accionDocker ni sale: lo dice", JSON.stringify(prueba.movilAvisos));
                        // Y si saliera (un cajón con los permisos viejos), el NUC la para.
                        let estado = -1;
                        m.pedir("POST", "/api/containers/syncthing/restart", {
                            confirm: ""
                        }, (e, t) => estado = e);
                        prueba.esperar(8000, () => estado !== -1, ok2 => {
                            prueba.comprobar(ok2 && estado === 403, "  y si una saliera, el NUC contesta 403", String(estado));
                            m.cargarRegistro("panel");
                            prueba.esperar(8000, () => m.registro !== null && !m.registro.cargando && m.registro.entradas.some(e => e.titulo.indexOf("No permitido") === 0), ok3 => {
                                const e = m.registro.entradas[0];
                                prueba.comprobar(ok3 && e.titulo === "No permitido: Reiniciar contenedor · syncthing" && e.nivel === "warn", "  y el intento queda en el Registro (que movil sí puede leer)", JSON.stringify(m.registro.entradas.slice(0, 2)));
                                sig();
                            });
                        });
                    });
                }),
            // --- Fase 5: una nota como página (GET /api/nota, sólo leer) ---
            sig => {
                prueba.comprobar(a.notasPermitidas.indexOf("00 Inicio.md") >= 0 && a.notasPermitidas.indexOf("10 Proyectos") >= 0 && a.notasPermitidas.every(e => e.indexOf("MentalHealth") < 0), "notasPermitidas: las carpetas de personal.allowed", JSON.stringify(a.notasPermitidas));
                prueba.comprobar(Array.isArray(a.notasRecientes) && a.notasRecientes.some(n => n.ruta === "10 Proyectos/Proyecto de prueba.md" && n.titulo === "Proyecto de prueba" && n.modificada instanceof Date), "notasRecientes: las de los últimos 7 días, con su título y su fecha", JSON.stringify(a.notasRecientes));
                const r = {};
                a.leerNota("10 Proyectos/Proyecto de prueba.md", (n, e) => r.bien = [n, e]);
                a.leerNota("MentalHealth/Diario.md", (n, e) => r.fuera = [n, e]);
                a.leerNota("10 Proyectos/No existe.md", (n, e) => r.falta = [n, e]);
                prueba.esperar(8000, () => r.bien && r.fuera && r.falta, ok => {
                    const n = ok ? r.bien[0] : null;
                    prueba.comprobar(ok && r.bien[1] === "" && n.ruta === "10 Proyectos/Proyecto de prueba.md" && n.titulo === "Proyecto de prueba" && n.modificada instanceof Date && n.texto.indexOf("# Proyecto de prueba") === 0 && n.texto.indexOf("tipo: proyecto") < 0, "leerNota: la nota, sin el frontmatter", n ? JSON.stringify(n.texto.slice(0, 40)) : JSON.stringify(r.bien));
                    prueba.comprobar(ok && r.fuera[0] === null && r.fuera[1] === "No se puede abrir la nota: esa nota no está en las carpetas que muestra el panel", "  una de fuera de las carpetas: lo que dice el NUC (403)", ok ? r.fuera[1] : "");
                    prueba.comprobar(ok && r.falta[0] === null && r.falta[1] === "No se puede abrir la nota: no encuentro esa nota", "  una que no está (404)", ok ? r.falta[1] : "");
                    sig();
                });
            },
            sig => {
                const todo = JSON.stringify(a.registro) + JSON.stringify(a.stacks) + JSON.stringify(a.proyectos) + JSON.stringify(a.logs) + JSON.stringify(prueba.avisos) + JSON.stringify(prueba.movilAvisos);
                prueba.comprobar(todo.indexOf("Pr0ba-") < 0, "ni el Registro, ni los stacks, ni los proyectos, ni los avisos llevan las contraseñas");
                prueba.fin();
            }
        ]);
    }

    function fin() {
        console.log("");
        console.log((prueba.hechas - prueba.fallos.length) + " de " + prueba.hechas + " bien" + (prueba.fallos.length ? "; fallan: " + prueba.fallos.join(" | ") : ""));
        Qt.quit();
    }
}
