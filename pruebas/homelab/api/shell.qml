import QtQuick
import Quickshell
import Quickshell.Io
import "homelab"

// Prueba sin pantalla de Api.qml (la lanza prueba-api.sh, al lado): el Api.qml
// del repo contra el panel local de panel-local.sh, detrás de su Caddy falso,
// con un llavero de usar y tirar. Cada comprobación imprime OK o FALLO; al
// final, el recuento.
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
                prueba.luego(ok);
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
    property var tiempos: []
    // Cuándo pasó «a» a "sin-conexion" por última vez.
    property double tCorte: 0
    // Los valores de nivelAlertas de «a», en orden.
    property var niveles: []

    Connections {
        target: a
        function onAlertaNueva(alerta) {
            prueba.nuevas.push(alerta);
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

    // El vault falso de panel-local.sh: 6 vencidas o de hoy, se enseñan 5.
    readonly property var tareasEsperadas: [
        {
            texto: "Otra vencida",
            seccion: "General",
            color: "",
            prioridad: "maxima",
            cuando: "vencida hace 11 días",
            vencida: true
        },
        {
            texto: "Tarea en otra nota",
            seccion: "Proyecto de prueba",
            color: "",
            prioridad: "maxima",
            cuando: "vencida hace 2 días",
            vencida: true
        },
        {
            texto: "Entrega de prueba",
            seccion: "Clase",
            color: "#b48cff",
            prioridad: "maxima",
            cuando: "vencida ayer",
            vencida: true
        },
        {
            texto: "Cambiar el filtro del agua",
            seccion: "Homelab · Casa",
            color: "#6aa8ff",
            prioridad: "maxima",
            cuando: "hoy",
            vencida: false
        },
        {
            texto: "Pausada que venció",
            seccion: "En pausa",
            color: "",
            prioridad: "pausa",
            cuando: "vencida hace 3 días",
            vencida: true
        }
    ]

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
        prueba.comprobar(prueba.igual(i.tareas, prueba.tareasEsperadas), "inicio.tareas: vencidas y de hoy, 5, por urgencia, la de pausa al final", JSON.stringify(i.tareas));
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
                prueba.comprobar(!!n && a.alertas.indexOf(n) >= 0, "  con el mismo objeto que en alertas");
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
                                        prueba.fin();
                                    });
                                });
                            });
                        });
                    });
                });
            });
        });
    }

    function fin() {
        console.log("");
        console.log((prueba.hechas - prueba.fallos.length) + " de " + prueba.hechas + " bien" + (prueba.fallos.length ? "; fallan: " + prueba.fallos.join(" | ") : ""));
        Qt.quit();
    }
}
