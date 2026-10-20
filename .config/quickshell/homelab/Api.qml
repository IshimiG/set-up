import QtQuick
import Quickshell
import Quickshell.Io

// La capa de datos del cajón: el único sitio que habla con el panel del NUC
// (panel.lab.ishimi.es, el servidor Go de IshimiG/homelab). La interfaz
// (Contenido, Cajon, Borde, shell) solo lee lo de aquí, ya normalizado, y
// nunca el JSON de la API. Las decisiones, en el vault: «30 Áreas/Servidor/
// 26-panel-escritorio.md» (E8, E9, E11, E12 y la fase 2).
//
// Cómo habla (E8):
//   - Los eventos, con un curl -N a /api/events, leído bloque a bloque. El
//     panel manda el estado de los contenedores y las alertas al conectar y en
//     cada cambio, y un «: ping» cada 25 s. Si se corta, vuelve a conectar
//     esperando 2 s, 4, 8… hasta 5 min; con refrescar(), al momento. Volver a
//     conectar no es sondear: mientras la conexión está viva no se pide nada.
//   - Lo demás, con XMLHttpRequest y la cabecera X-Panel-Request: 1 (la guarda
//     del panel contra las peticiones de otras webs): /api/yo, lo de Inicio y
//     marcar una alerta como vista.
//
// Las credenciales (E9): el usuario de Caddy de cada equipo y su contraseña
// están en el llavero, guardados por el usuario con
//   secret-tool store --label="Panel del homelab" servicio homelab-panel usuario <equipo>
// Lo común no nombra ningún equipo, así que el usuario sale del propio
// llavero: «secret-tool search» da los atributos del elemento. La contraseña
// se lee una vez, con «secret-tool lookup», y se queda en memoria. Nunca va en
// la línea de órdenes (curl la lee de la entrada estándar, con -K -), ni en un
// log, ni en un console.log.
//
// Para las pruebas (pruebas/homelab/api/prueba-api.sh), HOMELAB_PANEL_URL
// cambia la dirección del panel; en uso normal no se pone. La prueba no toca
// el llavero de verdad: lanza esto con un llavero de usar y tirar.
Scope {
    id: api

    // --- Lo que lee la interfaz (el contrato) --------------------------------
    // Todo es de solo lectura: lo cambia «p», abajo.

    // "conectando", "conectado", "sin-conexion" (no llega al NUC: fuera de
    // Tailscale, el NUC caído, la red), "sin-credenciales" (no hay contraseña
    // en el llavero) o "no-autorizado" (Caddy responde 401).
    readonly property string conexion: p.conexion
    // El usuario según GET /api/yo; "" hasta saberlo.
    readonly property string usuario: p.usuario
    // { acciones_docker, login_traderepublic }, de /api/yo; null hasta saberlo.
    readonly property var permisos: p.permisos
    // Las alertas abiertas, de la más grave a la menos y, dentro de cada
    // nivel, de la más nueva a la más vieja: { id, nivel ("error" o "warn"),
    // titulo, detalle, desde (Date), vista }. Sin conexión, vacía: no se sabe
    // cuáles hay.
    readonly property var alertas: p.alertas
    // El color del asa: "error" si hay alguna sin ver de nivel error, "warn"
    // si hay alguna sin ver, "ok" si no; "desconocido" sin conexión.
    readonly property string nivelAlertas: {
        if (p.conexion !== "conectado")
            return "desconocido";
        let nivel = "ok";
        for (const a of p.alertas) {
            if (a.vista)
                continue;
            if (a.nivel === "error")
                return "error";
            nivel = "warn";
        }
        return nivel;
    }
    // { enMarcha, total, problemas }: los contenedores de servicio (sin los de
    // un solo uso). Problemas son los que deberían estar en marcha y no lo
    // están: parados con un código de error, muertos, reiniciándose o
    // unhealthy. null sin datos.
    readonly property var servidor: p.servidor
    // { hoy, semana, metaPorcentaje, tareas }, o null sin cargar. Las tareas
    // son las vencidas y las de hoy, como mucho 5, de la más urgente a la
    // menos: { texto, seccion, color, prioridad, cuando, vencida }. La meta
    // es solo el %, nunca una cantidad (E11).
    readonly property var inicio: p.inicio
    // Cuándo se leyó inicio por última vez (Date), o null.
    readonly property var inicioCargado: p.inicioCargado
    // El último error, en una línea; "" si no hay.
    readonly property string error: p.error
    readonly property string baseUrl: (Quickshell.env("HOMELAB_PANEL_URL") || "https://panel.lab.ishimi.es").replace(/\/+$/, "")

    // --- Para las pruebas y para mirar desde fuera (no son del contrato) -----
    // Las veces que se ha lanzado curl contra /api/events.
    readonly property int intentos: p.intentos
    // Lo que se espera antes del próximo intento (0 si no hay ninguno
    // pendiente).
    readonly property int esperaMs: reintento.running ? p.espera : 0

    // Una vez por cada alerta que aparece y no estaba, con el mismo objeto que
    // en «alertas». La primera lista después de arrancar no la emite (al
    // iniciar sesión saldría una notificación por cada alerta vieja); después
    // de una reconexión, sí, para las que no estaban antes del corte. Una que
    // llega ya vista (la marcaron en la web mientras tanto) tampoco.
    signal alertaNueva(var alerta)

    // Al abrir el cajón: si los eventos están cortados, vuelve a conectar ya,
    // sin esperar al siguiente intento; si no hay credenciales o no valían,
    // vuelve a mirar el llavero; y si Inicio tiene más de 60 s, lo lee otra
    // vez.
    function refrescar() {
        if (p.leyendo)
            return;
        if (p.conexion === "sin-credenciales" || p.conexion === "no-autorizado") {
            api.leerCredenciales();
            return;
        }
        if (!p.vivo && p.clave !== "") {
            p.conexion = "conectando";
            api.conectar();
            return;
        }
        if (p.conexion === "conectado" && api.inicioViejo())
            api.cargarInicio();
    }

    // POST /api/alerts/seen. La alerta queda vista en «alertas» en cuanto el
    // servidor responde bien; después llega la lista nueva por los eventos.
    function marcarVista(id) {
        if (p.clave === "")
            return;
        const gen = p.generacion;
        api.pedir("POST", "/api/alerts/seen", {
            id: String(id)
        }, (estado, texto) => {
            if (gen !== p.generacion)
                return;
            if (estado === 200) {
                // El mismo objeto, para quien lo tenga guardado (alertaNueva),
                // en una lista nueva, para que las vinculaciones se enteren.
                for (const a of p.alertas)
                    if (a.id === id)
                        a.vista = true;
                p.alertas = p.alertas.slice();
                api.bien();
            } else if (estado === 401) {
                api.noAutorizado();
            } else if (estado !== 404) {
                // 404: ya no existe (resuelta mientras tanto); la lista nueva
                // ya viene por los eventos.
                p.error = "No se pudo marcar la alerta como vista" + api.porQue(estado, texto);
            }
        });
    }

    // Para «Abrir en la web»: urlWeb("#/servidor").
    function urlWeb(ruta) {
        return api.baseUrl + "/" + String(ruta || "").replace(/^\/+/, "");
    }

    // --- El estado de verdad --------------------------------------------------

    readonly property int esperaMin: 2000
    readonly property int esperaMax: 300000
    // Sin un solo bloque en este tiempo, la conexión se da por muerta (el panel
    // manda un «: ping» cada 25 s). Pasa al volver de una suspensión o al
    // cambiar de red, cuando curl se queda esperando para siempre.
    readonly property int silencioMax: 70000
    readonly property int esperaPeticion: 15000
    readonly property int inicioVale: 60000

    QtObject {
        id: p

        property string conexion: "conectando"
        property string usuario: ""
        property var permisos: null
        property var alertas: []
        property var servidor: null
        property var inicio: null
        property var inicioCargado: null
        property string error: ""
        property int intentos: 0

        // Del llavero. La contraseña solo sale de aquí hacia la entrada
        // estándar de curl y hacia la cabecera de cada petición.
        property string usuarioLlavero: ""
        property string clave: ""
        property bool leyendo: false
        // Sube cada vez que se vuelven a leer las credenciales: las respuestas
        // de antes ya no cuentan.
        property int generacion: 0

        // curl lanzado y sin terminar; el curl de ahora ya ha traído eventos;
        // se ha parado a posta (no se reintenta); el estado HTTP que imprime
        // curl al acabar.
        property bool vivo: false
        property bool enVivo: false
        property bool parado: false
        property bool silencio: false
        property string http: ""

        // La espera del intento pendiente y la del siguiente.
        property int espera: 0
        property int siguiente: api.esperaMin

        // Los id de las alertas de la última lista, para saber cuáles son
        // nuevas. Se guardan aunque se corte la conexión.
        property var conocidas: ({})
        property bool primeraLista: true

        property bool cargandoInicio: false
    }

    Component.onCompleted: api.leerCredenciales()

    // --- Las credenciales -----------------------------------------------------

    function leerCredenciales() {
        if (p.leyendo)
            return;
        p.leyendo = true;
        p.generacion++;
        api.parar();
        p.usuarioLlavero = "";
        p.clave = "";
        p.usuario = "";
        p.permisos = null;
        p.conexion = "conectando";
        api.olvidarVivo();
        // La salida normal de «search» lleva la contraseña: se tira a
        // /dev/null sin leerla. Los atributos salen por la de errores.
        api.ejecutar(["sh", "-c", "secret-tool search servicio homelab-panel 2>&1 >/dev/null"], (codigo, texto) => {
            const m = /^attribute\.usuario = (.+)$/m.exec(texto);
            if (codigo !== 0 || !m) {
                p.leyendo = false;
                api.sinCredenciales(codigo !== 0 ? api.primeraLinea(texto) : "");
                return;
            }
            const usuario = m[1].trim();
            api.ejecutar(["secret-tool", "lookup", "servicio", "homelab-panel", "usuario", usuario], (codigo2, clave) => {
                p.leyendo = false;
                // Guardada desde una tubería («echo … | secret-tool store»),
                // la contraseña lleva el salto de línea del final.
                clave = clave.replace(/\r?\n$/, "");
                if (codigo2 !== 0 || clave === "") {
                    api.sinCredenciales("");
                    return;
                }
                p.usuarioLlavero = usuario;
                p.clave = clave;
                api.conectar();
            });
        });
    }

    // Sin elemento en el llavero no se reintenta: refrescar() vuelve a mirar.
    function sinCredenciales(motivo) {
        p.conexion = "sin-credenciales";
        p.error = "No hay contraseña del panel en el llavero" + (motivo ? " (" + motivo + ")" : "");
    }

    // Caddy no acepta el usuario o la contraseña. Tampoco se reintenta solo.
    function noAutorizado() {
        api.parar();
        p.conexion = "no-autorizado";
        p.error = "El panel no acepta el usuario «" + p.usuarioLlavero + "» con la contraseña del llavero";
        api.olvidarVivo();
    }

    // --- Los eventos ------------------------------------------------------------

    function conectar() {
        if (p.vivo || p.clave === "")
            return;
        reintento.stop();
        p.parado = false;
        p.enVivo = false;
        p.silencio = false;
        p.http = "";
        p.vivo = true;
        p.intentos++;
        eventos.stdinEnabled = true;
        eventos.running = true;
        vigia.restart();
    }

    // Corta curl a posta, sin reintento.
    function parar() {
        p.parado = true;
        reintento.stop();
        vigia.stop();
        if (eventos.running)
            eventos.running = false;
    }

    // Lo que solo vale con la conexión viva.
    function olvidarVivo() {
        p.alertas = [];
        p.servidor = null;
    }

    // Las comillas y las barras de la configuración de curl (-K).
    function configCurl() {
        const v = (p.usuarioLlavero + ":" + p.clave).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t");
        return "user = \"" + v + "\"\n";
    }

    Process {
        id: eventos

        // Al acabar, curl escribe el estado HTTP como un comentario más, en
        // su propio bloque: así se distingue un 401 de Caddy de un corte.
        command: ["curl", "-K", "-", "-N", "-sS", "--connect-timeout", "10", "-H", "Accept: text/event-stream", "-H", "X-Panel-Request: 1", "-w", "\n\n:curl-http %{http_code}\n\n", api.baseUrl + "/api/events"]

        // Cada evento acaba en una línea en blanco, así que cada lectura es un
        // evento entero (o un «: ping»).
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => api.bloque(data)
        }

        // La contraseña entra por aquí y la entrada se cierra enseguida: curl
        // lee la configuración hasta el final antes de conectar.
        onStarted: {
            eventos.write(api.configCurl());
            eventos.stdinEnabled = false;
        }

        onExited: codigo => api.eventosAcabados(codigo)

        // Si curl ni siquiera arranca, no hay «exited».
        onRunningChanged: if (!eventos.running)
            Qt.callLater(() => {
                if (p.vivo && !eventos.running)
                    api.eventosAcabados(-1);
            })
    }

    function bloque(texto) {
        if (p.parado)
            return;
        vigia.restart();
        let evento = "message";
        const datos = [];
        for (const cruda of texto.split("\n")) {
            const linea = cruda.replace(/\r$/, "");
            if (linea === "")
                continue;
            if (linea.startsWith(":curl-http ")) {
                p.http = linea.slice(11).trim();
                continue;
            }
            if (linea.startsWith(":"))
                continue;
            const i = linea.indexOf(":");
            const campo = i < 0 ? linea : linea.slice(0, i);
            let valor = i < 0 ? "" : linea.slice(i + 1);
            if (valor.startsWith(" "))
                valor = valor.slice(1);
            if (campo === "event")
                evento = valor;
            else if (campo === "data")
                datos.push(valor);
        }
        if (datos.length === 0 || (evento !== "state" && evento !== "alerts"))
            return;
        let d;
        try {
            d = JSON.parse(datos.join("\n"));
        } catch (e) {
            return;
        }
        if (!p.enVivo) {
            // El primer evento de esta conexión: ya se habla con el NUC.
            p.enVivo = true;
            p.conexion = "conectado";
            p.siguiente = api.esperaMin;
            p.error = "";
            api.pedirYo();
            if (api.inicioViejo())
                api.cargarInicio();
        }
        if (evento === "state")
            p.servidor = api.servidorDe(d);
        else
            api.alertasDe(d);
    }

    function eventosAcabados(codigo) {
        if (!p.vivo)
            return;
        p.vivo = false;
        vigia.stop();
        if (p.parado)
            return;
        if (p.http === "401") {
            api.noAutorizado();
            return;
        }
        p.error = api.motivoCorte(codigo, p.http);
        p.conexion = "sin-conexion";
        api.olvidarVivo();
        p.espera = p.siguiente;
        p.siguiente = Math.min(p.siguiente * 2, api.esperaMax);
        reintento.interval = p.espera;
        reintento.restart();
    }

    function motivoCorte(codigo, http) {
        const host = api.baseUrl.replace(/^[a-z]+:\/\//, "").replace(/\/.*$/, "");
        if (p.silencio)
            return "Sin noticias del NUC en " + api.silencioMax / 1000 + " s";
        const h = parseInt(http) || 0;
        if (h === 502 || h === 503 || h === 504)
            return "El panel del NUC no responde (HTTP " + h + ")";
        if (h >= 400)
            return "El panel ha respondido HTTP " + h;
        switch (codigo) {
        case -1:
        case 127:
            return "No encuentro curl";
        case 6:
            return "No encuentro " + host + " (DNS)";
        case 7:
            return "No se puede conectar con " + host;
        case 28:
            return host + " no contesta";
        case 35:
        case 51:
        case 53:
        case 54:
        case 58:
        case 59:
        case 60:
        case 77:
        case 80:
        case 83:
        case 90:
        case 91:
            return "Error de TLS con " + host + " (curl " + codigo + ")";
        }
        return h === 200 ? "Se ha cortado la conexión con el NUC" : "Se ha cortado la conexión con el NUC (curl " + codigo + ")";
    }

    Timer {
        id: reintento
        onTriggered: api.conectar()
    }

    Timer {
        id: vigia
        interval: api.silencioMax
        onTriggered: if (eventos.running) {
            p.silencio = true;
            eventos.running = false;
        }
    }

    // --- Lo que llega por los eventos ------------------------------------------

    function servidorDe(snap) {
        let enMarcha = 0, total = 0, problemas = 0;
        for (const st of snap.stacks || []) {
            for (const c of st.containers || []) {
                // `docker run --rm` y `docker compose run`: acaban a posta.
                if (c.oneOff)
                    continue;
                total++;
                if (c.state === "running")
                    enMarcha++;
                // 0, 130 y 143 son salidas normales (las mismas que el panel
                // no cuenta como caída): un contenedor parado así se paró a
                // posta.
                const caido = c.state === "exited" && c.exitCode !== 0 && c.exitCode !== 130 && c.exitCode !== 143;
                if (caido || c.state === "dead" || c.state === "restarting" || (c.state === "running" && c.health === "unhealthy"))
                    problemas++;
            }
        }
        // Docker no responde en el NUC y nunca ha respondido: no hay datos.
        if (total === 0 && snap.error)
            return null;
        return {
            enMarcha: enMarcha,
            total: total,
            problemas: problemas
        };
    }

    function fecha(s) {
        const d = new Date(s);
        return isNaN(d.getTime()) ? null : d;
    }

    function alertasDe(lista) {
        const nuevas = (Array.isArray(lista) ? lista : []).map(a => ({
                    id: String(a.id),
                    nivel: a.level === "error" ? "error" : "warn",
                    titulo: String(a.title || ""),
                    detalle: String(a.detail || ""),
                    desde: api.fecha(a.since) || api.fecha(a.updated) || new Date(),
                    vista: !!a.seenBy
                }));
        nuevas.sort((x, y) => (x.nivel === y.nivel ? 0 : x.nivel === "error" ? -1 : 1) || y.desde - x.desde || (x.id < y.id ? -1 : x.id > y.id ? 1 : 0));
        const antes = p.conocidas;
        const ahora = {};
        for (const a of nuevas)
            ahora[a.id] = true;
        p.conocidas = ahora;
        p.alertas = nuevas;
        if (p.primeraLista) {
            p.primeraLista = false;
            return;
        }
        for (const a of nuevas)
            if (!antes[a.id] && !a.vista)
                api.alertaNueva(a);
    }

    // --- Las peticiones ----------------------------------------------------------

    // Una petición a la API, con la contraseña en la cabecera (montada aquí, en
    // memoria). alAcabar(estado, texto): estado 0 es que no hubo respuesta.
    function pedir(metodo, ruta, cuerpo, alAcabar) {
        const xhr = new XMLHttpRequest();
        const reloj = relojes.createObject(api, {
            interval: api.esperaPeticion
        });
        let hecha = false;
        const acabar = (estado, texto) => {
            if (hecha)
                return;
            hecha = true;
            reloj.destroy();
            alAcabar(estado, texto);
        };
        // El XMLHttpRequest de QML no tiene tiempo máximo.
        reloj.triggered.connect(() => {
            acabar(0, "");
            xhr.abort();
        });
        xhr.onreadystatechange = () => {
            if (xhr.readyState === XMLHttpRequest.DONE)
                acabar(xhr.status, xhr.responseText);
        };
        xhr.open(metodo, api.baseUrl + ruta);
        xhr.setRequestHeader("Authorization", "Basic " + api.base64(p.usuarioLlavero + ":" + p.clave));
        xhr.setRequestHeader("X-Panel-Request", "1");
        xhr.setRequestHeader("Accept", "application/json");
        if (cuerpo === undefined) {
            xhr.send();
        } else {
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(cuerpo));
        }
    }

    Component {
        id: relojes
        Timer {
            running: true
        }
    }

    // Base64 de los bytes UTF-8, para la cabecera Basic. Qt.btoa con un texto
    // está obsoleto en Qt 6.11 (avisa en el log) y con bytes devuelve un
    // ArrayBuffer, así que se hace aquí.
    function base64(texto) {
        const b = [];
        for (const ch of texto) {
            const c = ch.codePointAt(0);
            if (c < 0x80)
                b.push(c);
            else if (c < 0x800)
                b.push(0xc0 | c >> 6, 0x80 | c & 63);
            else if (c < 0x10000)
                b.push(0xe0 | c >> 12, 0x80 | c >> 6 & 63, 0x80 | c & 63);
            else
                b.push(0xf0 | c >> 18, 0x80 | c >> 12 & 63, 0x80 | c >> 6 & 63, 0x80 | c & 63);
        }
        const t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let s = "";
        for (let i = 0; i < b.length; i += 3) {
            const n = b[i] << 16 | (b[i + 1] || 0) << 8 | (b[i + 2] || 0);
            s += t[n >> 18 & 63] + t[n >> 12 & 63] + (i + 1 < b.length ? t[n >> 6 & 63] : "=") + (i + 2 < b.length ? t[n & 63] : "=");
        }
        return s;
    }

    function leerJSON(r) {
        if (!r || r.estado !== 200)
            return null;
        try {
            return JSON.parse(r.texto);
        } catch (e) {
            return null;
        }
    }

    function porQue(estado, texto) {
        if (estado === 0)
            return ": el NUC no contesta";
        let msg = "";
        try {
            msg = JSON.parse(texto).error || "";
        } catch (e) {}
        return " (HTTP " + estado + (msg ? ": " + api.primeraLinea(msg) : "") + ")";
    }

    function primeraLinea(texto) {
        return String(texto || "").trim().split("\n")[0].slice(0, 160);
    }

    // Una petición ha ido bien: el error que hubiera ya no vale.
    function bien() {
        if (p.conexion === "conectado")
            p.error = "";
    }

    function pedirYo() {
        const gen = p.generacion;
        api.pedir("GET", "/api/yo", undefined, (estado, texto) => {
            if (gen !== p.generacion)
                return;
            if (estado === 401) {
                api.noAutorizado();
                return;
            }
            const d = api.leerJSON({
                estado: estado,
                texto: texto
            });
            if (!d) {
                p.error = "No se pudo saber quién soy" + api.porQue(estado, texto);
                return;
            }
            p.usuario = String(d.usuario || "");
            const per = d.permisos || {};
            p.permisos = {
                acciones_docker: per.acciones_docker === true,
                login_traderepublic: per.login_traderepublic === true
            };
        });
    }

    // --- Inicio -------------------------------------------------------------------
    // Lo mismo que el Inicio de la web: la fecha y la semana de /api/personal,
    // las tareas vencidas y las de hoy de /api/tareas (00 Inicio.md) y de
    // /api/personal (las de otras notas), y el % de la meta de
    // /api/finanzas/resumen, que no trae cantidades. No se empuja por los
    // eventos: se lee al conectar y al abrir el cajón, si tiene más de 60 s.

    function inicioViejo() {
        return !p.inicioCargado || Date.now() - p.inicioCargado.getTime() > api.inicioVale;
    }

    function cargarInicio() {
        if (p.cargandoInicio || p.clave === "")
            return;
        p.cargandoInicio = true;
        const gen = p.generacion;
        const r = {};
        let faltan = 3;
        const una = clave => (estado, texto) => {
            r[clave] = {
                estado: estado,
                texto: texto
            };
            if (--faltan > 0)
                return;
            p.cargandoInicio = false;
            if (gen === p.generacion)
                api.juntarInicio(r);
        };
        api.pedir("GET", "/api/personal", undefined, una("personal"));
        api.pedir("GET", "/api/tareas", undefined, una("tareas"));
        api.pedir("GET", "/api/finanzas/resumen", undefined, una("finanzas"));
    }

    function juntarInicio(r) {
        if (r.personal.estado === 401 || r.tareas.estado === 401) {
            api.noAutorizado();
            return;
        }
        const personal = api.leerJSON(r.personal);
        const tareas = api.leerJSON(r.tareas);
        if (!personal || !tareas) {
            const malo = personal ? r.tareas : r.personal;
            p.error = "No se pudo leer Inicio" + api.porQue(malo.estado, malo.texto);
            return;
        }
        // Solo el %; el resto del resumen ni se mira.
        const fin = api.leerJSON(r.finanzas);
        const meta = fin && fin.enabled && fin.ready && isFinite(fin.porcentaje) ? Math.round(fin.porcentaje) : null;
        p.inicio = {
            hoy: api.textoHoy(personal.today),
            semana: api.textoSemana(personal.isoWeek),
            metaPorcentaje: meta,
            tareas: api.tareasDeInicio(tareas, personal)
        };
        p.inicioCargado = new Date();
        api.bien();
    }

    // "2026-10-20" → días desde 1970, para restar fechas sin husos.
    function diaNum(s) {
        const m = /^(\d{4})-(\d\d)-(\d\d)/.exec(s || "");
        return m ? Date.UTC(+m[1], +m[2] - 1, +m[3]) / 86400000 : null;
    }

    function hoyLocal() {
        const d = new Date();
        return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000;
    }

    // «Martes 20 de octubre», como la web.
    function textoHoy(s) {
        const m = /^(\d{4})-(\d\d)-(\d\d)/.exec(s || "");
        const d = m ? new Date(+m[1], +m[2] - 1, +m[3]) : new Date();
        const t = Qt.locale("es_ES").toString(d, "dddd d 'de' MMMM");
        return t.charAt(0).toUpperCase() + t.slice(1);
    }

    // «Semana 43», de "2026-S43"; sin ella, la semana ISO de hoy.
    function textoSemana(iso) {
        const m = /S(\d+)/.exec(iso || "");
        if (m)
            return "Semana " + (+m[1]);
        const d = new Date();
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return "Semana " + Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    // Sin las marcas de Markdown, como plain() de la web.
    function plano(texto) {
        return String(texto || "").replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, (_, a, b) => (b || a.split("#")[0].split("/").pop()).trim()).replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g, "$1").replace(/\*\*|~~|`/g, "");
    }

    readonly property var rangoPrio: ({
            highest: 0,
            high: 1,
            medium: 2,
            low: 3,
            lowest: 4
        })
    readonly property var nombrePrio: ({
            highest: "maxima",
            high: "alta",
            medium: "media",
            low: "baja",
            lowest: "minima"
        })

    // La prioridad que tiene hoy una tarea abierta: la del panel, que la sube
    // a medida que se acerca la fecha (a media a 7 días o menos, a alta a 3, a
    // máxima a 1 o vencida) sin bajarla nunca. /api/tareas ya la trae
    // («effective»); para las de otras notas se calcula igual.
    function efectiva(prio, n) {
        if (n === null)
            return prio || "";
        const suelo = n <= 1 ? "highest" : n <= 3 ? "high" : n <= 7 ? "medium" : "";
        const r = x => x in api.rangoPrio ? api.rangoPrio[x] : 5;
        return suelo && r(suelo) < r(prio) ? suelo : prio || "";
    }

    function cuando(n) {
        if (n < -1)
            return "vencida hace " + -n + " días";
        if (n === -1)
            return "vencida ayer";
        if (n === 0)
            return "hoy";
        if (n === 1)
            return "mañana";
        return "en " + n + " días";
    }

    function tareasDeInicio(tareas, personal) {
        const hoyT = api.diaNum(tareas.today) ?? api.diaNum(personal.today) ?? api.hoyLocal();
        const hoyP = api.diaNum(personal.today) ?? hoyT;
        const lista = [];
        const meter = (t, hoy, eff, pausa, seccion, color, fuente, ruta) => {
            if (t.done)
                return;
            const d = api.diaNum(t.due);
            const vencida = !!t.overdue || (d !== null && d < hoy);
            if (!vencida && !t.dueToday && d !== hoy)
                return;
            lista.push({
                // Primero lo que no está en pausa; después, la prioridad de
                // hoy, la fecha y el orden de las notas (00 Inicio delante).
                orden: [pausa ? 1 : 0, eff in api.rangoPrio ? api.rangoPrio[eff] : 5, t.due || "9999", fuente, ruta, t.line || 0],
                tarea: {
                    texto: api.plano(t.text),
                    seccion: seccion,
                    color: /^#[0-9a-fA-F]{6}$/.test(color || "") ? color : "",
                    // Una tarea sin prioridad no llega aquí: vencida o de hoy,
                    // el panel ya la ha subido a máxima.
                    prioridad: pausa ? "pausa" : api.nombrePrio[eff] || "minima",
                    cuando: api.cuando(d !== null ? d - hoy : 0),
                    vencida: vencida
                }
            });
        };
        for (const s of tareas.sections || []) {
            for (const t of s.tasks || []) {
                // La sección y, si la tarea lleva otra área, el área, como las
                // tarjetas «Ahora» de la web.
                const area = String(t.area || "").trim();
                const seccion = String(s.title || "") + (area && area.toLowerCase() !== String(s.title || "").trim().toLowerCase() ? " · " + area : "");
                meter(t, hoyT, t.effective || t.priority || "", s.id === "en-pausa", seccion, s.color, 0, "");
            }
        }
        for (const t of personal.tasks || []) {
            if (t.path === "00 Inicio.md")
                continue;
            const d = api.diaNum(t.due);
            const nota = String(t.path || "").split("/").pop().replace(/\.md$/, "");
            meter(t, hoyP, api.efectiva(t.priority || "", d === null ? null : d - hoyP), false, nota, "", 1, String(t.path || ""));
        }
        lista.sort((a, b) => {
            for (let i = 0; i < a.orden.length; i++) {
                if (a.orden[i] < b.orden[i])
                    return -1;
                if (a.orden[i] > b.orden[i])
                    return 1;
            }
            return 0;
        });
        return lista.slice(0, 5).map(x => x.tarea);
    }

    // --- Órdenes de una vez (secret-tool) -----------------------------------------
    // alAcabar(codigo, salida) cuando el proceso ha salido y su salida se ha
    // leído entera; después el proceso se destruye, con lo que haya leído. La
    // salida de errores no se lee.

    Component {
        id: ordenes
        Process {
            id: orden
            signal leida(string texto)
            stdout: StdioCollector {
                onStreamFinished: orden.leida(this.text)
            }
        }
    }

    function ejecutar(comando, alAcabar) {
        const o = ordenes.createObject(api, {
            command: comando
        });
        let codigo = -1, leida = false, hecha = false, texto = "";
        const acabar = () => {
            if (hecha || codigo < 0 || !leida)
                return;
            hecha = true;
            alAcabar(codigo, texto);
            o.destroy();
        };
        o.leida.connect(t => {
            texto = t;
            leida = true;
            acabar();
        });
        o.exited.connect(c => {
            codigo = c;
            acabar();
        });
        // Si no llega a arrancar (no está secret-tool), no hay «exited».
        o.runningChanged.connect(() => {
            if (!o.running)
                Qt.callLater(() => {
                    if (!hecha && codigo < 0) {
                        codigo = 127;
                        leida = true;
                        acabar();
                    }
                });
        });
        o.running = true;
    }
}
