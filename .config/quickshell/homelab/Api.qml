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
//     del panel contra las peticiones de otras webs): /api/yo, lo de Inicio,
//     marcar una alerta como vista y, en la fase 3, las tareas, los hábitos y
//     lo de Aules; en la 4, los proyectos, GitHub (solo leer), las acciones
//     de Docker y el Registro.
//   - Los logs de un contenedor y el consumo (fase 4) también son flujos que
//     no acaban: otro curl -N para cada uno, solo mientras se miran. El
//     consumo, solo con Servidor a la vista (verConsumo); los logs, mientras
//     están abiertos. Cómo acaba una acción de Docker y cada línea nueva del
//     Registro llegan por /api/events («result» y «journal»).
//   - Los eventos «tareas» y «clase» (fase 3) son opcionales: si el servidor los
//     manda, el cajón se pone al día solo; si no, lo hace al abrirse (si lo que
//     tiene es de hace más de 60 s) y después de cada cosa que escribe, porque
//     las escrituras ya contestan con el estado nuevo.
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
    // titulo, detalle, desde (Date), vista, entrada (el id de su línea del
    // Registro, con toda la historia, o 0) }. Sin conexión, vacía: no se sabe
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
    // son las abiertas vencidas y las de hoy, como mucho 5, de la más urgente
    // a la menos, y en su sitio las de 00 Inicio que se han hecho hoy (para
    // poder desmarcarlas): { id, hecha, texto, seccion, color, prioridad,
    // cuando, vencida }. id es el de «tareas», el que pide marcarTarea, y ""
    // en las de otras notas, que no se marcan desde el cajón. La meta es solo
    // el %, nunca una cantidad (E11).
    readonly property var inicio: p.inicio
    // Cuándo se leyó inicio por última vez (Date), o null.
    readonly property var inicioCargado: p.inicioCargado
    // El último error, en una línea; "" si no hay.
    readonly property string error: p.error

    // --- Fase 3: tareas, hábitos y Aules --------------------------------------
    // Las tareas de 00 Inicio.md, o null sin cargar:
    //   { habilitado, error, version, hoy ("2026-10-20"), areas: [texto],
    //     secciones: [{ id, titulo, color ("#rrggbb" o ""), pausa,
    //                   tareas: [tarea] }] }
    // con cada tarea { id, linea, hecha, area, texto (Markdown), plano (sin
    // marcas), prioridad y efectiva ("maxima", "alta", "media", "baja",
    // "minima" o ""; efectiva es la de hoy, que el servidor sube cerca de la
    // fecha), subida (por qué sube, o ""), vence ("2026-10-22" o ""), dias
    // (hasta que vence, negativo si venció, o null), empieza, noEmpezada,
    // hechaEl, vencida, venceHoy, detalles: [línea], subtareas: [{ texto,
    // hecha }], fijada }.
    readonly property var tareas: p.tareas
    // Cuándo se leyeron o se escribieron por última vez (Date), o null.
    readonly property var tareasCargadas: p.tareasCargadas
    // El último fallo al leerlas, en una línea; "" si no hay.
    readonly property string tareasError: p.tareasError
    // Hay una escritura de tareas en camino: otra no sale hasta que acabe
    // (los id llevan el número de línea, y una escritura lo cambia).
    readonly property bool tareasOcupado: p.escribiendoTarea
    // La interfaz lo pone a true mientras se edita una tarea. Un evento
    // «tareas» que llega entonces no recarga: marca las tareas como obsoletas y
    // se recargan al volver a false, sin pisar lo que se estaba escribiendo.
    property bool editandoTarea: false
    readonly property bool tareasObsoletas: p.tareasObsoletas

    // La semana de hábitos de hoy, o null sin cargar:
    //   { habilitado, error, semana, existe, ruta, hoy: { fecha, gym, lectura,
    //     programar (true, false o null), energia (1–10 o null) } o null,
    //     totales: { gym, lectura, programar ("3/7"), energia ("6,5") } }
    readonly property var habitos: p.habitos
    // «Actualizar Aules», o null sin cargar:
    //   { estado ("ejecutando", "ok", "error", "nunca" o "sin-unidad"),
    //     ejecutando, terminado (Date o null), error, tareas ({ anadidas,
    //     fechas, completadas, error } o null), calendario ({ creados,
    //     cambiados, borrados, error } o null), calendarioConectado,
    //     calendarioPersonalError }
    readonly property var clase: p.clase

    // --- Fase 4: proyectos, servidor y registro -------------------------------
    // Los proyectos de las notas, los de /api/personal (que ya se lee para
    // Inicio), en el orden del NUC (estado, prioridad, actualizado), o null sin
    // cargar:
    //   [{ ruta, titulo, tipo ("proyecto" o "subproyecto"), padre (la ruta del
    //      proyecto de un subproyecto, o ""), estado, prioridad, actualizado
    //      ("2026-10-20" o ""), siguiente: [texto en Markdown], siguientePanel
    //      (el siguiente paso es el bloque del panel, el que se edita; si no,
    //      sale de la sección de la nota), repo ("dueño/nombre" o ""), progreso
    //      (0–100 o null) }]
    // Vacía si el panel no tiene el vault.
    readonly property var proyectos: p.proyectos
    // Hay una escritura de proyecto en camino: otra espera en cola a que acabe.
    readonly property bool proyectosOcupado: p.escribiendoProyecto
    // GitHub, de /api/github, o null sin leer:
    //   { habilitado (false: el NUC no tiene token), usuario, error,
    //     repos: { "dueño/nombre" en minúsculas: { repo, url, descripcion,
    //              prs, issues, privado } } }
    readonly property var github: p.github
    // Las PR e issues abiertas de cada repo que se ha mirado con cargarRepo,
    // solo para leer: { "dueño/nombre" en minúsculas: { cargando, error, url,
    // cuando (Date o null), pulls: [item], issues: [item] } }, con cada item
    // { numero, titulo, autor, borrador, actualizada (Date o null), url, ramas
    // ("rama → base" en las PR, "" en las issues), etiquetas: [texto],
    // comentarios }.
    readonly property var repos: p.repos

    // Los stacks y sus contenedores, en vivo (evento «state»), o [] sin datos:
    //   [{ nombre ("" para los sueltos), gestionado (está en la configuración
    //      del panel), protegido, ocupado (el paso de la acción en marcha, o
    //      ""), acciones, contenedores: [{ nombre, servicio, stack, imagen,
    //      estado ("running", "exited", "restarting"…), salud ("", "starting",
    //      "healthy" o "unhealthy"), desde y hasta (Date o null), codigo,
    //      reinicios, unUso, puertos: [texto], critico, ocupado, acciones }] }]
    // acciones son las que permite el NUC ({ accion: palabra }, con la palabra
    // que hay que escribir para confirmarla, o "" si no hace falta), y vacías
    // si este usuario no tiene acciones de Docker (movil, decisión E10).
    readonly property var stacks: api.stacksDe(p.snap, api.puedeDocker)
    // Docker no responde en el NUC: lo de stacks es lo último que se supo.
    readonly property string dockerError: p.dockerError
    // Lo dice GET /api/yo; sin saberlo todavía, tampoco.
    readonly property bool puedeDocker: p.permisos !== null && p.permisos.acciones_docker === true
    // Los nombres de las acciones del NUC, para los avisos.
    readonly property var nombresAccion: ({
            start: "Arrancar",
            stop: "Parar",
            restart: "Reiniciar",
            up: "Levantar",
            update: "Actualizar",
            down: "Bajar"
        })
    // Los logs del contenedor abierto con abrirLogs, o null. El NUC sigue el
    // log en vivo (GET /api/containers/{nombre}/logs), así que llegan líneas
    // mientras esté abierto:
    //   { contenedor, vez (cambia con cada abrirLogs), estado ("conectando",
    //     "abierto", "fin": el contenedor se ha parado, o "cortado": se cortó
    //     la conexión), error, lineas: [{ hora ("12:03:04" o ""), texto, nota
    //     (true si lo dice el cajón y no el contenedor) }], total (las líneas
    //     que han llegado desde que se abrió, también las que ya no están) }
    // Como mucho maxLineasLog, las últimas.
    readonly property var logs: p.logs
    property int maxLineasLog: 1000
    // La interfaz lo pone a true mientras Servidor está a la vista con el
    // cajón abierto: solo entonces se lee el consumo (/api/stats, que el NUC
    // manda cada 3 s y que no mide nada si nadie mira; E8).
    property bool verConsumo: false
    // El consumo, o null sin leer (o con verConsumo a false):
    //   { host: { cpu (%), memUsada, memTotal (bytes), carga, discos: [{ ruta,
    //     montado, usado, total }] }, contenedores: { nombre: { cpu, mem,
    //     memLimite } }, cuando (Date) }
    readonly property var consumo: p.consumo
    // El Registro del NUC (su diario, GET /api/journal), o null hasta que se
    // pide con cargarRegistro:
    //   { filtro, cargando, error, entradas: [{ id, hora (Date), fuente
    //     ("container", "apt", "system", "disk" o "panel"), nivel ("info",
    //     "warn" o "error"), objetivo, titulo, conDetalle }], mas, notas:
    //     [texto] }
    // De la más nueva a la más vieja. Las nuevas llegan solas (evento
    // «journal») si pasan el filtro: "" (todo), "level:warn" (avisos y
    // errores) o una fuente.
    readonly property var registro: p.registro
    property int paginaRegistro: 50

    // Algo que decirle al usuario en una línea (un conflicto, un fallo de
    // escritura); la interfaz lo enseña un rato. error es true si es un fallo.
    signal aviso(string texto, bool error)
    // Cómo acabó una acción de Docker (evento «result»), de este cajón o de
    // cualquier otro cliente: { tipo ("contenedor" o "stack"), objetivo,
    // accion, ok, error, salida }. También sale como aviso.
    signal resultado(var r)
    readonly property string baseUrl: (Quickshell.env("HOMELAB_PANEL_URL") || "https://panel.lab.ishimi.es").replace(/\/+$/, "")

    // --- Para las pruebas y para mirar desde fuera (no son del contrato) -----
    // Las veces que se ha lanzado curl contra /api/events.
    readonly property int intentos: p.intentos
    // Lo que se espera antes del próximo intento (0 si no hay ninguno
    // pendiente).
    readonly property int esperaMs: reintento.running ? p.espera : 0

    // Una vez por cada alerta que aparece y no estaba, con lo mismo que trae
    // en «alertas» (una copia: desde Qt 6.12, un objeto de JS que pasa por una
    // señal llega copiado). La primera lista después de arrancar no la emite (al
    // iniciar sesión saldría una notificación por cada alerta vieja); después
    // de una reconexión, sí, para las que no estaban antes del corte. Una que
    // llega ya vista (la marcaron en la web mientras tanto) tampoco.
    signal alertaNueva(var alerta)

    // Al abrir el cajón: si los eventos están cortados, vuelve a conectar ya,
    // sin esperar al siguiente intento; si no hay credenciales o no valían,
    // vuelve a mirar el llavero; y si Inicio tiene más de 60 s, lo lee otra
    // vez. Una conexión que lleva más de medio vigía callada (al volver de una
    // suspensión) también se da por cortada.
    function refrescar() {
        if (p.leyendo)
            return;
        if (p.conexion === "sin-credenciales" || p.conexion === "no-autorizado") {
            api.leerCredenciales();
            return;
        }
        if (p.vivo && p.enVivo && Date.now() - p.ultimoBloque > api.silencioMax / 2) {
            p.silencio = true;
            p.otraVezYa = true;
            eventos.running = false;
            return;
        }
        if (!p.vivo && p.clave !== "") {
            p.conexion = "conectando";
            api.conectar();
            return;
        }
        if (p.conexion === "conectado") {
            if (api.inicioViejo())
                api.cargarInicio();
            api.refrescarFase3();
        }
    }

    // Tareas, hábitos y Aules, los que tengan más de inicioVale. Aules, además,
    // si había una actualización en marcha: sin el evento «clase» es la única
    // forma de enterarse de que ha acabado (una lectura, no un bucle).
    function refrescarFase3() {
        const viejo = f => !f || Date.now() - f.getTime() > api.inicioVale;
        if (viejo(p.tareasCargadas))
            api.cargarTareas();
        if (viejo(p.habitosCargados))
            api.cargarHabitos();
        if (viejo(p.claseCargada) || (p.clase && p.clase.ejecutando))
            api.cargarClase();
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
                // En una lista nueva, para que las vinculaciones se enteren.
                // (Lo que salió por alertaNueva es una copia: no cambia.)
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
    readonly property int esperaPeticion: 15000
    // Sin un solo bloque en este tiempo, la conexión se da por muerta (el panel
    // manda un «: ping» cada 25 s). Pasa al volver de una suspensión o al
    // cambiar de red, cuando curl se queda esperando para siempre. Las pruebas
    // lo bajan, y también inicioVale (lo que dura Inicio sin volver a leerse).
    property int silencioMax: 70000
    property int inicioVale: 60000

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
        // Cuándo llegó el último bloque (con la hora de pared, que sigue
        // contando durante una suspensión).
        property double ultimoBloque: 0
        // Al acabar este curl, otro al momento, sin esperar (refrescar()).
        property bool otraVezYa: false

        // La espera del intento pendiente y la del siguiente.
        property int espera: 0
        property int siguiente: api.esperaMin

        // Los id de las alertas de la última lista, para saber cuáles son
        // nuevas. Se guardan aunque se corte la conexión.
        property var conocidas: ({})
        property bool primeraLista: true

        property bool cargandoInicio: false
        // Lo último de /api/personal y de /api/tareas, tal como llegó: las
        // tareas de Inicio se vuelven a sacar de aquí con cada lista nueva.
        property var personalInicio: null
        property var ultimasTareas: null

        // Fase 3. Cada lectura y cada escritura de tareas lleva un número de
        // secuencia: una lectura que contesta después de una escritura más
        // nueva no la pisa.
        property var tareas: null
        property var tareasCargadas: null
        property string tareasVersion: ""
        property string tareasError: ""
        property bool tareasObsoletas: false
        property bool escribiendoTarea: false
        property int secTareas: 0
        property var habitos: null
        property var habitosCargados: null
        property var habitoOcupado: ({})
        property int secHabitos: 0
        property var clase: null
        property var claseCargada: null
        property string calendarioPersonalError: ""

        // Fase 4.
        property var proyectos: null
        property bool escribiendoProyecto: false
        // Las escrituras de proyectos que esperan su turno: [{ ruta, cambios,
        // alAcabar }].
        property var colaProyectos: []
        property var github: null
        property var githubCargado: null
        property bool cargandoGithub: false
        property var repos: ({})
        // El último «state» tal como llega; stacks sale de aquí.
        property var snap: null
        property string dockerError: ""
        // Los logs: la secuencia del contenedor abierto (cada abrirLogs y
        // cerrarLogs la sube) y la del curl que corre; las líneas que han
        // llegado y aún no se han pintado; el curl de antes sigue vivo y hay
        // que lanzar otro al acabar.
        property var logs: null
        property int secLogs: 0
        property int secCurlLogs: 0
        property var logsBuffer: []
        property bool logsVivo: false
        property bool logsOtro: false
        property string logsHttp: ""
        property var consumo: null
        property bool consumoVivo: false
        property bool consumoParado: false
        property string consumoHttp: ""
        property var registro: null
        property int secRegistro: 0
        // Las líneas que han llegado por los eventos mientras se leía la
        // primera página: la página no las trae y se ponen delante.
        property var registroVivas: []
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
        if (p.clave === "")
            return;
        if (p.vivo) {
            // El curl de antes, parado a posta, aún no ha acabado: en cuanto
            // acabe.
            if (p.parado)
                p.otraVezYa = true;
            return;
        }
        reintento.stop();
        p.parado = false;
        p.enVivo = false;
        p.silencio = false;
        p.otraVezYa = false;
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
        p.otraVezYa = false;
        reintento.stop();
        vigia.stop();
        if (eventos.running)
            eventos.running = false;
    }

    // Lo que solo vale con la conexión viva.
    function olvidarVivo() {
        p.alertas = [];
        p.servidor = null;
        p.snap = null;
        p.dockerError = "";
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

    // Un bloque de text/event-stream (un evento, un «: ping» o lo que curl
    // escribe al acabar): { evento, datos (las líneas data: juntas, o null si
    // no hay ninguna), http (el estado HTTP que imprime curl al acabar, o "") }.
    function leerBloque(texto) {
        let evento = "message";
        let http = "";
        const datos = [];
        for (const cruda of texto.split("\n")) {
            const linea = cruda.replace(/\r$/, "");
            if (linea === "")
                continue;
            if (linea.startsWith(":curl-http ")) {
                http = linea.slice(11).trim();
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
        return {
            evento: evento,
            datos: datos.length ? datos.join("\n") : null,
            http: http
        };
    }

    readonly property var eventosConocidos: ["state", "alerts", "tareas", "clase", "result", "journal"]

    function bloque(texto) {
        if (p.parado)
            return;
        vigia.restart();
        p.ultimoBloque = Date.now();
        const b = api.leerBloque(texto);
        if (b.http !== "")
            p.http = b.http;
        if (b.datos === null || api.eventosConocidos.indexOf(b.evento) < 0)
            return;
        let d;
        try {
            d = JSON.parse(b.datos);
        } catch (e) {
            return;
        }
        switch (b.evento) {
        case "state":
            p.servidor = api.servidorDe(d);
            p.snap = d && typeof d === "object" ? d : null;
            p.dockerError = d && d.error ? String(d.error) : "";
            return;
        case "tareas":
            api.eventoTareas(d);
            return;
        case "clase":
            api.eventoClase(d);
            return;
        case "result":
            api.eventoResultado(d);
            return;
        case "journal":
            api.eventoRegistro(d);
            return;
        }
        // Al conectar, el panel manda el estado y enseguida las alertas: con
        // las alertas ya puestas se pasa a "conectado", para que el asa no
        // pase un instante por "ok" antes de saberlas.
        const nuevas = api.alertasDe(d);
        if (!p.enVivo) {
            p.enVivo = true;
            p.conexion = "conectado";
            p.siguiente = api.esperaMin;
            p.error = "";
            api.pedirYo();
            if (api.inicioViejo())
                api.cargarInicio();
            api.refrescarFase3();
            // Lo que se escribió en el Registro durante el corte no ha llegado
            // por los eventos: si ya se estaba mirando, se lee otra vez.
            if (p.registro !== null)
                api.cargarRegistro(p.registro.filtro);
        }
        for (const a of nuevas)
            api.alertaNueva(a);
    }

    function eventosAcabados(codigo) {
        if (!p.vivo)
            return;
        p.vivo = false;
        vigia.stop();
        if (p.parado) {
            if (p.otraVezYa)
                api.conectar();
            return;
        }
        if (p.http === "401") {
            api.noAutorizado();
            return;
        }
        p.error = api.motivoCorte(codigo, p.http);
        api.olvidarVivo();
        if (p.otraVezYa) {
            p.conexion = "conectando";
            api.conectar();
            return;
        }
        p.conexion = "sin-conexion";
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
        if (codigo === -1 || codigo === 127)
            return "No encuentro curl";
        if (codigo === 6)
            return "No encuentro " + host + " (DNS)";
        if (codigo === 7)
            return "No se puede conectar con " + host;
        if (codigo === 28)
            return host + " no contesta";
        // Los de TLS y certificados.
        if ([35, 51, 53, 54, 58, 59, 60, 77, 80, 83, 90, 91].indexOf(codigo) >= 0)
            return "Error de TLS con " + host + " (curl " + codigo + ")";
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

    // Pone las alertas y devuelve las que hay que anunciar con alertaNueva.
    function alertasDe(lista) {
        const nuevas = (Array.isArray(lista) ? lista : []).map(a => ({
                    id: String(a.id),
                    nivel: a.level === "error" ? "error" : "warn",
                    titulo: String(a.title || ""),
                    detalle: String(a.detail || ""),
                    desde: api.fecha(a.since) || api.fecha(a.updated) || new Date(),
                    vista: !!a.seenBy,
                    entrada: Number(a.entry) || 0
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
            return [];
        }
        return nuevas.filter(a => !antes[a.id] && !a.vista);
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
        const sec = p.secTareas;
        const r = {};
        let faltan = 3;
        // La respuesta de cada una; con las tres, se junta.
        function una(clave) {
            return (estado, texto) => {
                r[clave] = {
                    estado: estado,
                    texto: texto
                };
                if (--faltan > 0)
                    return;
                p.cargandoInicio = false;
                if (gen === p.generacion)
                    api.juntarInicio(r, sec);
            };
        }
        api.pedir("GET", "/api/personal", undefined, una("personal"));
        api.pedir("GET", "/api/tareas", undefined, una("tareas"));
        api.pedir("GET", "/api/finanzas/resumen", undefined, una("finanzas"));
    }

    // sec: el número de secuencia de las tareas al empezar a leer Inicio.
    function juntarInicio(r, sec) {
        if (r.personal.estado === 401 || r.tareas.estado === 401) {
            api.noAutorizado();
            return;
        }
        const personal = api.leerJSON(r.personal);
        const tareas = api.leerJSON(r.tareas);
        // Los proyectos van en la misma respuesta que Inicio (fase 4).
        if (personal)
            p.proyectos = personal.vault === false ? [] : (personal.projects || []).map(api.proyectoDe);
        if (!personal || !tareas) {
            const malo = personal ? r.tareas : r.personal;
            p.error = "No se pudo leer Inicio" + api.porQue(malo.estado, malo.texto);
            return;
        }
        // Solo el %; el resto del resumen ni se mira.
        const fin = api.leerJSON(r.finanzas);
        const meta = fin && fin.enabled && fin.ready && isFinite(fin.porcentaje) ? Math.round(fin.porcentaje) : null;
        p.personalInicio = personal;
        // Si mientras tanto ha llegado otra lista de tareas (una escritura,
        // una lectura), se usa esa: esta pudo leerse antes, y sus id ya no
        // valdrían para marcar.
        const lista = sec !== p.secTareas && p.ultimasTareas ? p.ultimasTareas : tareas;
        p.inicio = {
            hoy: api.textoHoy(personal.today),
            semana: api.textoSemana(personal.isoWeek),
            metaPorcentaje: meta,
            tareas: api.tareasDeInicio(lista, personal)
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

    // tareas es lo de /api/tareas (o la respuesta de una escritura, que es lo
    // mismo) y personal, lo de /api/personal.
    function tareasDeInicio(tareas, personal) {
        const hoyT = api.diaNum(tareas.today) ?? api.diaNum(personal.today) ?? api.hoyLocal();
        const hoyP = api.diaNum(personal.today) ?? hoyT;
        const lista = [];
        // id: el de /api/tareas, o "" si es de otra nota.
        const meter = (t, hoy, eff, pausa, seccion, color, fuente, ruta, id) => {
            const d = api.diaNum(t.due);
            let vencida = false;
            if (t.done) {
                // Hecha: solo si es de 00 Inicio, se hizo hoy y estaba aquí
                // (vencía hoy o antes), para poder desmarcarla.
                if (id === "" || api.diaNum(t.doneDate) !== hoy || d === null || d > hoy)
                    return;
            } else {
                vencida = !!t.overdue || (d !== null && d < hoy);
                if (!vencida && !t.dueToday && d !== hoy)
                    return;
            }
            lista.push({
                // Primero lo que no está en pausa; después, la prioridad de
                // hoy, la fecha y el orden de las notas (00 Inicio delante).
                orden: [pausa ? 1 : 0, eff in api.rangoPrio ? api.rangoPrio[eff] : 5, t.due || "9999", fuente, ruta, t.line || 0],
                tarea: {
                    id: id,
                    hecha: !!t.done,
                    texto: api.plano(t.text),
                    seccion: seccion,
                    color: /^#[0-9a-fA-F]{6}$/.test(color || "") ? color : "",
                    // Una tarea sin prioridad no llega aquí: vencida o de hoy,
                    // el panel ya la ha subido a máxima.
                    prioridad: pausa ? "pausa" : api.nombrePrio[eff] || "minima",
                    cuando: t.done ? "hecha hoy" : api.cuando(d !== null ? d - hoy : 0),
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
                // El NUC no sube la prioridad de una hecha: se calcula como si
                // siguiera abierta, para que no cambie de sitio al marcarla.
                const d = api.diaNum(t.due);
                const eff = t.done ? api.efectiva(t.priority || "", d === null ? null : d - hoyT) : t.effective || t.priority || "";
                meter(t, hoyT, eff, s.id === "en-pausa", seccion, s.color, 0, "", String(t.id || ""));
            }
        }
        for (const t of personal.tasks || []) {
            if (t.path === "00 Inicio.md" || t.done)
                continue;
            const d = api.diaNum(t.due);
            const nota = String(t.path || "").split("/").pop().replace(/\.md$/, "");
            meter(t, hoyP, api.efectiva(t.priority || "", d === null ? null : d - hoyP), false, nota, "", 1, String(t.path || ""), "");
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
        // Como mucho 5 abiertas; las hechas que caen entre ellas se quedan.
        const r = [];
        let abiertas = 0;
        for (const x of lista) {
            if (abiertas === 5)
                break;
            if (!x.tarea.hecha)
                abiertas++;
            r.push(x.tarea);
        }
        return r;
    }

    // --- Fase 3: tareas -------------------------------------------------------
    // Lo mismo que la tarjeta de tareas de la web: /api/tareas se lee entero, y
    // cada escritura contesta con la lista entera, que sustituye a la anterior.
    // Un 409 quiere decir que 00 Inicio.md cambió por otro lado (Obsidian, la
    // web): trae la lista como está ahora, y aquí se recarga y se avisa, sin
    // volver a mandar nada.

    readonly property var prioServidor: ({
            maxima: "highest",
            alta: "high",
            media: "medium",
            baja: "low",
            minima: "lowest"
        })

    function tareaDe(t, hoy) {
        const vence = String(t.due || "");
        const d = api.diaNum(vence);
        const empieza = String(t.start || "");
        const ed = api.diaNum(empieza);
        const prio = x => api.nombrePrio[x] || "";
        const texto = String(t.text || "");
        return {
            id: String(t.id),
            linea: t.line || 0,
            hecha: !!t.done,
            area: String(t.area || ""),
            texto: texto,
            plano: api.plano(texto),
            prioridad: prio(t.priority),
            efectiva: prio(t.effective || t.priority),
            subida: String(t.raised || ""),
            vence: vence,
            dias: d !== null && hoy !== null ? d - hoy : null,
            empieza: empieza,
            programada: String(t.scheduled || ""),
            noEmpezada: ed !== null && hoy !== null && ed > hoy,
            hechaEl: String(t.doneDate || ""),
            vencida: !!t.overdue,
            venceHoy: !!t.dueToday,
            detalles: (t.details || []).map(String),
            subtareas: (t.subtasks || []).map(x => ({
                        texto: String(x.text || ""),
                        hecha: !!x.done
                    })),
            fijada: !!t.pinned
        };
    }

    function tareasDe(d) {
        const hoy = api.diaNum(d.today) ?? api.hoyLocal();
        return {
            habilitado: d.enabled !== false,
            error: String(d.error || ""),
            version: String(d.version || ""),
            hoy: String(d.today || ""),
            areas: (d.areas || []).map(String),
            secciones: (d.sections || []).map(s => ({
                        id: String(s.id),
                        titulo: String(s.title || ""),
                        color: /^#[0-9a-fA-F]{6}$/.test(s.color || "") ? s.color : "",
                        pausa: s.id === "en-pausa",
                        tareas: (s.tasks || []).map(t => api.tareaDe(t, hoy))
                    }))
        };
    }

    // Pone la lista que ha llegado (de una lectura o de una escritura).
    function aplicarTareas(d) {
        p.secTareas++;
        p.ultimasTareas = d;
        p.tareas = api.tareasDe(d);
        p.tareasVersion = p.tareas.version;
        p.tareasCargadas = new Date();
        p.tareasError = "";
        p.tareasObsoletas = false;
        // Las tareas de Inicio salen de la misma lista: se ponen al día a la
        // vez, con los id nuevos, para que su casilla se pueda volver a pulsar
        // sin un 409.
        if (p.inicio && p.personalInicio)
            p.inicio = Object.assign({}, p.inicio, {
                tareas: api.tareasDeInicio(d, p.personalInicio)
            });
    }

    function cargarTareas() {
        if (p.clave === "")
            return;
        const gen = p.generacion;
        const sec = ++p.secTareas;
        api.pedir("GET", "/api/tareas", undefined, (estado, texto) => {
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
                p.tareasError = "No se pudieron leer las tareas" + api.porQue(estado, texto);
                return;
            }
            // Una escritura o una lectura más nueva ya ha puesto otra cosa.
            if (sec !== p.secTareas)
                return;
            api.aplicarTareas(d);
            api.bien();
        });
    }

    // Un evento «tareas» con { version }. Si es la que ya se tiene (una
    // escritura propia, que contestó antes que el evento), no hace nada; si
    // no, se relee, salvo que se esté editando una tarea: entonces se marca y
    // se relee al soltar el editor.
    function eventoTareas(d) {
        if (!d || typeof d.version !== "string" || d.version === p.tareasVersion)
            return;
        if (api.editandoTarea)
            p.tareasObsoletas = true;
        else
            api.cargarTareas();
    }

    onEditandoTareaChanged: if (!api.editandoTarea && p.tareasObsoletas) {
        p.tareasObsoletas = false;
        api.cargarTareas();
    }

    // POST /api/tareas: datos { seccion, texto, area, fecha ("2026-10-22"),
    // prioridad ("maxima".."minima") }; area, fecha y prioridad son opcionales.
    function anadirTarea(datos, alAcabar) {
        const cuerpo = {
            seccion: String(datos.seccion || ""),
            texto: String(datos.texto || "")
        };
        if (datos.area)
            cuerpo.area = String(datos.area);
        if (datos.fecha)
            cuerpo.fecha = String(datos.fecha);
        if (datos.prioridad)
            cuerpo.prioridad = api.prioServidor[datos.prioridad] || "";
        api.escribirTarea("POST", "/api/tareas", cuerpo, "No se pudo añadir la tarea", alAcabar);
    }

    // POST /api/tareas/{id}/hecha.
    function marcarTarea(id, hecha, alAcabar) {
        api.escribirTarea("POST", "/api/tareas/" + encodeURIComponent(id) + "/hecha", {
            hecha: !!hecha
        }, hecha ? "No se pudo marcar como hecha" : "No se pudo desmarcar", alAcabar);
    }

    // POST /api/tareas/{id}: solo lo que se manda cambia. cambios puede llevar
    // texto, area, fecha ("" la quita), prioridad ("" la quita), seccion (id),
    // detalles (las líneas de detalle, que sustituyen a las de ahora),
    // subtareas ([{ texto, hecha }], que sustituyen a las de ahora) y fijada.
    function editarTarea(id, cambios, alAcabar) {
        const cuerpo = Object.assign({}, cambios);
        if ("prioridad" in cuerpo)
            cuerpo.prioridad = api.prioServidor[cuerpo.prioridad] || "";
        api.escribirTarea("POST", "/api/tareas/" + encodeURIComponent(id), cuerpo, "No se pudo guardar la tarea", alAcabar);
    }

    // Una escritura a la vez. alAcabar(ok) al terminar, o al momento con false
    // si no ha salido porque hay otra en camino o no hay conexión.
    function escribirTarea(metodo, ruta, cuerpo, queHacia, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        if (p.clave === "" || p.conexion !== "conectado" || p.escribiendoTarea) {
            if (p.conexion !== "conectado")
                api.aviso(queHacia + ": no hay conexión con el NUC", true);
            fin(false);
            return;
        }
        p.escribiendoTarea = true;
        const gen = p.generacion;
        api.pedir(metodo, ruta, cuerpo, (estado, texto) => {
            p.escribiendoTarea = false;
            if (gen !== p.generacion) {
                fin(false);
                return;
            }
            const d = api.leerJSON({
                estado: estado === 409 ? 200 : estado,
                texto: texto
            });
            if (estado === 200 && d) {
                // También pone al día las tareas de Inicio.
                api.aplicarTareas(d);
                api.bien();
                fin(true);
            } else if (estado === 409) {
                if (d && d.tareas)
                    api.aplicarTareas(d.tareas);
                else
                    api.cargarTareas();
                p.inicioCargado = null;
                api.aviso("La nota cambió en tus notas; he recargado las tareas y no he cambiado nada.", true);
                fin(false);
            } else if (estado === 401) {
                api.noAutorizado();
                fin(false);
            } else {
                api.aviso(queHacia + api.porQue(estado, texto), true);
                fin(false);
            }
        });
    }

    // --- Fase 3: hábitos ------------------------------------------------------
    // La semana de hábitos de hoy, de /api/habitos. Para el cajón basta el día
    // de hoy; la web sigue teniendo la semana entera y el cambio de semana.

    function habitosDe(w) {
        const dia = (w.dias || []).find(x => x.hoy) || null;
        const t = w.totales || {};
        const total = v => v === null || v === undefined ? "–" : v + "/7";
        const energia = v => v === null || v === undefined ? "–" : String(Math.round(v * 10) / 10).replace(".", ",");
        const bool = v => v === null || v === undefined ? null : !!v;
        return {
            habilitado: w.enabled !== false,
            error: String(w.error || ""),
            semana: String(w.semana || ""),
            existe: !!w.existe,
            ruta: String(w.path || ""),
            hoy: dia ? {
                fecha: String(dia.fecha),
                gym: bool(dia.gym),
                lectura: bool(dia.lectura),
                programar: bool(dia.programar),
                energia: dia.energia === null || dia.energia === undefined ? null : +dia.energia
            } : null,
            totales: {
                gym: total(t.gym),
                lectura: total(t.lectura),
                programar: total(t.programar),
                energia: energia(t.energia)
            }
        };
    }

    function cargarHabitos() {
        if (p.clave === "")
            return;
        const gen = p.generacion;
        const sec = ++p.secHabitos;
        api.pedir("GET", "/api/habitos", undefined, (estado, texto) => {
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
                p.error = "No se pudieron leer los hábitos" + api.porQue(estado, texto);
                return;
            }
            if (sec !== p.secHabitos)
                return;
            p.habitos = api.habitosDe(d);
            p.habitosCargados = new Date();
        });
    }

    // Anota un hábito de hoy. campo: "gym", "lectura", "programar" o "energia";
    // valor: "si", "no" o "" (sin marcar) y, para la energía, "1" a "10" o "".
    // El cambio se ve al momento y se deshace si el servidor lo rechaza.
    function anotarHabito(campo, valor) {
        const h = p.habitos;
        if (!h || !h.hoy || p.conexion !== "conectado" || p.habitoOcupado[campo])
            return;
        const dia = h.hoy;
        const actual = dia[campo];
        const antes = actual === null ? "" : campo === "energia" ? String(actual) : actual ? "si" : "no";
        const nuevo = valor === "" ? null : campo === "energia" ? +valor : valor === "si";
        const poner = v => {
            const copia = Object.assign({}, p.habitos);
            copia.hoy = Object.assign({}, p.habitos.hoy);
            copia.hoy[campo] = v;
            p.habitos = copia;
        };
        const ocupado = v => {
            const o = Object.assign({}, p.habitoOcupado);
            o[campo] = v;
            p.habitoOcupado = o;
        };
        poner(nuevo);
        ocupado(true);
        const gen = p.generacion;
        api.pedir("POST", "/api/habitos", {
            semana: h.semana,
            fecha: dia.fecha,
            campo: campo,
            antes: antes,
            valor: valor
        }, (estado, texto) => {
            ocupado(false);
            if (gen !== p.generacion)
                return;
            const d = api.leerJSON({
                estado: estado === 409 ? 200 : estado,
                texto: texto
            });
            if (estado === 200 && d) {
                p.habitos = api.habitosDe(d);
                p.habitosCargados = new Date();
                api.bien();
            } else if (estado === 409 && d && d.semana) {
                p.habitos = api.habitosDe(d.semana);
                p.habitosCargados = new Date();
                api.aviso("La semana cambió en tus notas; la he recargado.", true);
            } else if (estado === 401) {
                api.noAutorizado();
            } else {
                poner(actual);
                api.aviso("No se pudo guardar el hábito" + api.porQue(estado, texto), true);
            }
        });
    }

    // --- Fase 3: Aules ----------------------------------------------------------
    // GET /api/clase/sync dice cómo va la actualización; POST la lanza. Sin el
    // evento «clase» no se sondea: se lee una vez al conectar, al abrir el cajón
    // si había una en marcha y justo después de lanzarla.

    function claseDe(d) {
        const tar = d.tareas;
        const cal = d.calendario;
        const per = d.calendarioPersonal;
        return {
            estado: String(d.estado || ""),
            ejecutando: !!d.ejecutando,
            terminado: d.terminado ? api.fecha(d.terminado) : null,
            error: String(d.error || ""),
            tareas: tar ? {
                anadidas: tar.anadidas || 0,
                fechas: tar.fechas || 0,
                completadas: tar.completadas || 0,
                error: String(tar.error || "")
            } : null,
            calendario: cal ? {
                creados: cal.creados || 0,
                cambiados: cal.cambiados || 0,
                borrados: cal.borrados || 0,
                error: String(cal.error || "")
            } : null,
            calendarioConectado: !!d.calendarioConectado,
            calendarioPersonalError: per && per.error ? String(per.error) : ""
        };
    }

    // Una lectura o un evento «clase». Si una actualización que estaba en
    // marcha acaba, el cruce con 00 Inicio.md pudo cambiar las tareas.
    function aplicarClase(d) {
        const estaba = p.clase && p.clase.ejecutando;
        p.clase = api.claseDe(d);
        p.claseCargada = new Date();
        if (estaba && !p.clase.ejecutando) {
            api.cargarTareas();
            api.aviso(p.clase.estado === "error" ? "Aules: " + (p.clase.error || "falló la actualización") : "Aules actualizado", p.clase.estado === "error");
        }
    }

    function cargarClase() {
        if (p.clave === "")
            return;
        const gen = p.generacion;
        api.pedir("GET", "/api/clase/sync", undefined, (estado, texto) => {
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
                p.error = "No se pudo leer lo de Aules" + api.porQue(estado, texto);
                return;
            }
            api.aplicarClase(d);
        });
    }

    // Los eventos «clase» traen lo mismo que GET /api/clase/sync.
    function eventoClase(d) {
        if (d && typeof d === "object")
            api.aplicarClase(d);
    }

    // POST /api/clase/sync: lanza la actualización y contesta 202 con el estado
    // (ejecutando). Un 409 es que ya había una: se lee cómo va.
    function actualizarAules() {
        if (p.clave === "" || p.conexion !== "conectado" || (p.clase && p.clase.ejecutando))
            return;
        const gen = p.generacion;
        const antes = p.clase;
        // Se ve ya como en marcha, sin esperar al servidor.
        p.clase = Object.assign({}, p.clase || api.claseDe({}), {
            estado: "ejecutando",
            ejecutando: true
        });
        api.pedir("POST", "/api/clase/sync", undefined, (estado, texto) => {
            if (gen !== p.generacion)
                return;
            const d = api.leerJSON({
                estado: estado === 202 ? 200 : estado,
                texto: texto
            });
            if (estado === 202 && d) {
                api.aplicarClase(d);
            } else if (estado === 401) {
                api.noAutorizado();
            } else if (estado === 409) {
                // Ya había una en marcha: se mira cómo va.
                api.cargarClase();
            } else {
                p.clase = antes;
                api.aviso("Aules: no se pudo lanzar" + api.porQue(estado, texto), true);
            }
        });
    }

    // --- Fase 4: proyectos -------------------------------------------------------
    // Los proyectos llegan con /api/personal (juntarInicio). Se editan como en
    // la web, con POST /api/proyectos { path, antes, nuevo }: «antes» es lo que
    // se veía de cada campo que se cambia, y si la nota cambió mientras tanto
    // (Obsidian, la web) el NUC no escribe nada y contesta 409 con el proyecto
    // como está ahora, que sustituye al de aquí.

    function proyectoDe(x) {
        const tipo = String(x.tipo || "").toLowerCase() === "subproyecto" ? "subproyecto" : "proyecto";
        return {
            ruta: String(x.path || ""),
            titulo: String(x.title || x.path || ""),
            tipo: tipo,
            padre: String(x.parent || ""),
            estado: String(x.estado || ""),
            prioridad: String(x.prioridad || ""),
            actualizado: String(x.actualizado || ""),
            siguiente: (x.siguiente || []).map(String),
            siguientePanel: !!x.siguientePanel,
            repo: String(x.repo || ""),
            progreso: typeof x.progreso === "number" && isFinite(x.progreso) ? x.progreso : null
        };
    }

    // Cada campo editable como texto, como lo compara el NUC: progreso "" si
    // no hay, y el siguiente paso solo si es el bloque del panel.
    function camposProyecto(pr) {
        return {
            estado: pr.estado,
            prioridad: pr.prioridad,
            progreso: pr.progreso === null ? "" : String(pr.progreso),
            repo: pr.repo,
            siguiente: pr.siguientePanel ? pr.siguiente.join("\n") : ""
        };
    }

    // El proyecto que contesta el NUC, en el sitio del que había.
    function ponerProyecto(x) {
        const nuevo = api.proyectoDe(x);
        const lista = (p.proyectos || []).slice();
        const i = lista.findIndex(q => q.ruta === nuevo.ruta);
        if (i >= 0)
            lista[i] = nuevo;
        else
            lista.push(nuevo);
        p.proyectos = lista;
    }

    // cambios: { estado, prioridad ("" la quita), progreso (0–100, o null o ""
    // para quitarlo), siguiente (un paso por línea; "" lo quita), repo }; solo
    // lo que se manda cambia. alAcabar(ok) al terminar, o al momento con
    // false si no puede salir.
    //
    // Una escritura a la vez y, si llega otra mientras tanto, en cola
    // (decidido el 2026-10-21): sale cuando acaba la de antes, y su «antes»
    // se saca entonces, del proyecto como lo ha dejado esa. Si una sale mal
    // (un 409, un fallo), las que esperaban para ese mismo proyecto no salen:
    // se pensaron sobre lo que ya no es.
    function editarProyecto(ruta, cambios, alAcabar) {
        if (!(p.proyectos || []).some(x => x.ruta === ruta)) {
            if (alAcabar)
                alAcabar(false);
            return;
        }
        if (p.clave === "" || p.conexion !== "conectado") {
            api.aviso("No se pudo guardar el proyecto: no hay conexión con el NUC", true);
            if (alAcabar)
                alAcabar(false);
            return;
        }
        p.colaProyectos = p.colaProyectos.concat([
            {
                ruta: ruta,
                cambios: cambios,
                alAcabar: alAcabar
            }
        ]);
        api.siguienteProyecto();
    }

    // Saca de la cola la primera escritura, si no hay otra en camino.
    function siguienteProyecto() {
        if (p.escribiendoProyecto || p.colaProyectos.length === 0)
            return;
        const q = p.colaProyectos[0];
        p.colaProyectos = p.colaProyectos.slice(1);
        const fin = ok => {
            if (q.alAcabar)
                q.alAcabar(ok);
        };
        const pr = (p.proyectos || []).find(x => x.ruta === q.ruta);
        if (!pr || p.clave === "" || p.conexion !== "conectado") {
            fin(false);
            api.siguienteProyecto();
            return;
        }
        const campos = api.camposProyecto(pr);
        const antes = {};
        const nuevo = {};
        for (const k of Object.keys(q.cambios || {})) {
            if (!(k in campos))
                continue;
            const v = q.cambios[k];
            const n = k === "progreso" ? (v === null || v === "" || v === undefined ? "" : String(Math.round(+v))) : String(v ?? "");
            // Lo que ya está así (otra de la cola lo ha dejado igual) no se manda.
            if (n === campos[k])
                continue;
            antes[k] = campos[k];
            nuevo[k] = n;
        }
        if (Object.keys(nuevo).length === 0) {
            fin(Object.keys(q.cambios || {}).some(k => k in campos));
            api.siguienteProyecto();
            return;
        }
        p.escribiendoProyecto = true;
        const gen = p.generacion;
        api.pedir("POST", "/api/proyectos", {
            path: q.ruta,
            antes: antes,
            nuevo: nuevo
        }, (estado, texto) => {
            p.escribiendoProyecto = false;
            if (gen !== p.generacion) {
                fin(false);
                api.descartarProyectos("");
                return;
            }
            const d = api.leerJSON({
                estado: estado === 409 ? 200 : estado,
                texto: texto
            });
            const ok = estado === 200 && d && d.proyecto;
            if (ok) {
                api.ponerProyecto(d.proyecto);
                api.bien();
            } else if (estado === 409) {
                if (d && d.proyecto)
                    api.ponerProyecto(d.proyecto);
                api.aviso("El proyecto cambió en tus notas; lo he recargado y no he cambiado nada.", true);
            } else if (estado === 401) {
                api.noAutorizado();
            } else {
                api.aviso("No se pudo guardar el proyecto" + api.porQue(estado, texto), true);
            }
            if (!ok)
                api.descartarProyectos(estado === 401 ? "" : q.ruta);
            fin(!!ok);
            api.siguienteProyecto();
        });
    }

    // Quita de la cola las escrituras de ese proyecto (o todas, con ""), y
    // les dice que no han salido.
    function descartarProyectos(ruta) {
        const fuera = p.colaProyectos.filter(q => ruta === "" || q.ruta === ruta);
        p.colaProyectos = p.colaProyectos.filter(q => fuera.indexOf(q) < 0);
        for (const q of fuera)
            if (q.alAcabar)
                q.alAcabar(false);
    }

    // --- Fase 4: GitHub, solo leer ------------------------------------------------
    // El resumen (cuántas PR e issues abiertas tiene cada repo) se lee al ver
    // Proyectos, si tiene más de inicioVale; las PR e issues de un repo, al
    // abrir su proyecto. El NUC guarda lo de GitHub 60 s; «fresco» se lo salta.
    // Fusionar, cerrar y comentar se quedan en la web.

    function cargarGithub(fresco) {
        if (p.clave === "" || p.cargandoGithub)
            return;
        if (!fresco && p.githubCargado && Date.now() - p.githubCargado.getTime() <= api.inicioVale)
            return;
        p.cargandoGithub = true;
        const gen = p.generacion;
        api.pedir("GET", "/api/github" + (fresco ? "?fresh=1" : ""), undefined, (estado, texto) => {
            p.cargandoGithub = false;
            if (gen !== p.generacion)
                return;
            if (estado === 401) {
                api.noAutorizado();
                return;
            }
            p.githubCargado = new Date();
            const d = api.leerJSON({
                estado: estado,
                texto: texto
            });
            if (!d) {
                p.github = Object.assign({
                    habilitado: true,
                    usuario: "",
                    repos: {}
                }, p.github || {}, {
                    error: "No se pudo leer GitHub" + api.porQue(estado, texto)
                });
                return;
            }
            const repos = {};
            for (const r of d.repos || [])
                repos[String(r.repo).toLowerCase()] = {
                    repo: String(r.repo),
                    url: String(r.url || ""),
                    descripcion: String(r.description || ""),
                    prs: r.prs || 0,
                    issues: r.issues || 0,
                    privado: !!r.private
                };
            p.github = {
                habilitado: d.enabled !== false,
                usuario: String(d.user || ""),
                error: "",
                repos: repos
            };
        });
    }

    function itemGithub(x, pr) {
        return {
            numero: x.number || 0,
            titulo: String(x.title || ""),
            autor: String(x.author || ""),
            borrador: !!x.draft,
            actualizada: api.fecha(x.updatedAt),
            url: String(x.url || ""),
            ramas: pr && x.head ? String(x.head) + " → " + String(x.base || "") : "",
            etiquetas: (x.labels || []).map(l => String(l.name || "")),
            comentarios: x.comments || 0
        };
    }

    function ponerRepo(clave, v) {
        const r = Object.assign({}, p.repos);
        r[clave] = v;
        p.repos = r;
    }

    function cargarRepo(repo, fresco) {
        const m = /^([A-Za-z0-9-]+)\/([A-Za-z0-9._-]+)$/.exec(String(repo || ""));
        if (!m || p.clave === "")
            return;
        const clave = String(repo).toLowerCase();
        const ya = p.repos[clave];
        if (ya && ya.cargando)
            return;
        if (!fresco && ya && ya.cuando && !ya.error && Date.now() - ya.cuando.getTime() <= api.inicioVale)
            return;
        const base = ya || {
            error: "",
            url: "",
            cuando: null,
            pulls: [],
            issues: []
        };
        api.ponerRepo(clave, Object.assign({}, base, {
            cargando: true
        }));
        const gen = p.generacion;
        api.pedir("GET", "/api/github/repos/" + encodeURIComponent(m[1]) + "/" + encodeURIComponent(m[2]) + "?estado=abierto" + (fresco ? "&fresh=1" : ""), undefined, (estado, texto) => {
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
            let error = "";
            if (!d)
                error = "No se pudo leer el repositorio" + api.porQue(estado, texto);
            else if (d.enabled === false)
                error = "GitHub sin conectar: falta GITHUB_TOKEN en el NUC.";
            api.ponerRepo(clave, error ? Object.assign({}, base, {
                cargando: false,
                error: error,
                cuando: new Date()
            }) : {
                cargando: false,
                error: "",
                url: String(d.url || ""),
                cuando: new Date(),
                pulls: (d.pulls || []).map(x => api.itemGithub(x, true)),
                issues: (d.issues || []).map(x => api.itemGithub(x, false))
            });
        });
    }

    // --- Fase 4: servidor -----------------------------------------------------------

    // "0001-01-01T00:00:00Z" es el «nunca» de Docker.
    function fechaDocker(s) {
        return !s || String(s).startsWith("0001-") ? null : api.fecha(s);
    }

    function stacksDe(snap, puede) {
        if (!snap || !Array.isArray(snap.stacks))
            return [];
        const busy = snap.busy || {};
        const acc = a => puede && a && typeof a === "object" ? Object.assign({}, a) : ({});
        return snap.stacks.map(st => {
            const nombre = String(st.name || "");
            const ocupado = String(busy["stack:" + nombre] || "");
            return {
                nombre: nombre,
                gestionado: !!st.managed,
                protegido: !!st.protected,
                ocupado: ocupado,
                acciones: acc(st.actions),
                contenedores: (st.containers || []).map(c => ({
                            nombre: String(c.name || ""),
                            servicio: String(c.service || c.name || ""),
                            stack: nombre,
                            imagen: String(c.image || ""),
                            estado: String(c.state || ""),
                            salud: String(c.health || ""),
                            desde: api.fechaDocker(c.startedAt),
                            hasta: api.fechaDocker(c.finishedAt),
                            codigo: c.exitCode || 0,
                            reinicios: c.restarts || 0,
                            unUso: !!c.oneOff,
                            puertos: (c.ports || []).map(String),
                            critico: !!c.critical,
                            ocupado: String(busy["container:" + c.name] || ocupado),
                            acciones: acc(c.actions)
                        }))
            };
        });
    }

    // Una acción de Docker (E10): tipo "contenedor" o "stack", accion una de
    // las que trae su «acciones», y confirmacion la palabra escrita (o ""). El
    // NUC la valida otra vez con su configuración: no se fía de lo que vio el
    // cajón. Contesta 202 al momento y cómo acaba llega después, por el evento
    // «result» (resultado y un aviso). alAcabar(ok): ok es que el NUC la ha
    // aceptado, no que haya acabado bien.
    function accionDocker(tipo, nombre, accion, confirmacion, alAcabar) {
        const fin = ok => {
            if (alAcabar)
                alAcabar(ok);
        };
        const que = (api.nombresAccion[accion] || accion) + " · " + nombre;
        if (!api.puedeDocker) {
            api.aviso(que + ": " + (p.usuario ? "el usuario " + p.usuario + " no tiene acciones de Docker" : "todavía no sé si este usuario puede"), true);
            fin(false);
            return;
        }
        if (p.clave === "" || p.conexion !== "conectado") {
            api.aviso(que + ": no hay conexión con el NUC", true);
            fin(false);
            return;
        }
        const ruta = "/api/" + (tipo === "stack" ? "stacks" : "containers") + "/" + encodeURIComponent(nombre) + "/" + encodeURIComponent(accion);
        const gen = p.generacion;
        api.pedir("POST", ruta, {
            confirm: String(confirmacion || "")
        }, (estado, texto) => {
            if (gen !== p.generacion) {
                fin(false);
                return;
            }
            if (estado === 202) {
                api.bien();
                fin(true);
                return;
            }
            if (estado === 401) {
                api.noAutorizado();
                fin(false);
                return;
            }
            let motivo;
            if (estado === 409) {
                motivo = ": ya hay una acción en marcha";
            } else if (estado === 428) {
                let palabra = "";
                try {
                    palabra = JSON.parse(texto).word || "";
                } catch (e) {}
                motivo = ": hay que escribir «" + palabra + "» para confirmarla";
            } else if (estado === 404) {
                motivo = ": ya no está en el NUC";
            } else {
                motivo = api.porQue(estado, texto);
            }
            api.aviso(que + motivo, true);
            fin(false);
        });
    }

    function eventoResultado(d) {
        if (!d || typeof d !== "object")
            return;
        const r = {
            tipo: d.kind === "stack" ? "stack" : "contenedor",
            objetivo: String(d.target || ""),
            accion: String(d.action || ""),
            ok: !!d.ok,
            error: String(d.error || ""),
            salida: String(d.output || "")
        };
        api.resultado(r);
        api.aviso((api.nombresAccion[r.accion] || r.accion) + " · " + r.objetivo + (r.ok ? ": hecho" : ": " + (r.error || "falló")), !r.ok);
    }

    // Lo que se le pasa a curl para un flujo de eventos del panel. Al acabar,
    // curl escribe el estado HTTP como un comentario más, en su propio bloque.
    function comandoFlujo(ruta) {
        return ["curl", "-K", "-", "-N", "-sS", "--connect-timeout", "10", "-H", "Accept: text/event-stream", "-H", "X-Panel-Request: 1", "-w", "\n\n:curl-http %{http_code}\n\n", api.baseUrl + ruta];
    }

    // --- Fase 4: logs ------------------------------------------------------------------
    // Un curl -N a /api/containers/{nombre}/logs?tail=300: las 300 últimas
    // líneas y, después, las que vayan saliendo. Las líneas se juntan y se
    // pintan cada 100 ms, no una a una. Si se corta no se reintenta (como en la
    // web): se dice y se vuelve a abrir a mano.

    function abrirLogs(nombre) {
        p.secLogs++;
        p.logsBuffer = [];
        reposoLogs.stop();
        if (p.clave === "" || p.conexion !== "conectado") {
            p.logs = {
                contenedor: String(nombre),
                vez: p.secLogs,
                estado: "cortado",
                error: "No hay conexión con el NUC.",
                lineas: [],
                total: 0
            };
            return;
        }
        p.logs = {
            contenedor: String(nombre),
            vez: p.secLogs,
            estado: "conectando",
            error: "",
            lineas: [],
            total: 0
        };
        if (p.logsVivo) {
            // El de antes se para y, al acabar, sale el de ahora.
            p.logsOtro = true;
            procLogs.running = false;
            return;
        }
        api.lanzarLogs();
    }

    function cerrarLogs() {
        p.secLogs++;
        p.logs = null;
        p.logsBuffer = [];
        p.logsOtro = false;
        reposoLogs.stop();
        if (p.logsVivo)
            procLogs.running = false;
    }

    function lanzarLogs() {
        if (!p.logs)
            return;
        p.secCurlLogs = p.secLogs;
        p.logsHttp = "";
        p.logsVivo = true;
        procLogs.command = api.comandoFlujo("/api/containers/" + encodeURIComponent(p.logs.contenedor) + "/logs?tail=300");
        procLogs.stdinEnabled = true;
        procLogs.running = true;
    }

    // Lo que añade el cajón a las líneas del contenedor.
    function notaLogs(texto) {
        p.logsBuffer.push({
            hora: "",
            texto: "— " + texto,
            nota: true
        });
    }

    function bloqueLogs(texto) {
        if (p.secCurlLogs !== p.secLogs || !p.logs)
            return;
        const b = api.leerBloque(texto);
        if (b.http !== "")
            p.logsHttp = b.http;
        if (b.datos === null)
            return;
        if (b.evento === "line") {
            // «2026-10-20T08:00:00.000000000Z texto»: la hora, en la de aquí.
            const m = /^(\d{4}-\d\d-\d\dT[\d:.]+Z) ?([\s\S]*)$/.exec(b.datos);
            const d = m ? api.fecha(m[1]) : null;
            p.logsBuffer.push({
                hora: d ? Qt.locale("es_ES").toString(d, "HH:mm:ss") : "",
                texto: m ? m[2] : b.datos,
                nota: false
            });
        } else if (b.evento === "failure") {
            api.notaLogs(b.datos);
        } else if (b.evento === "end") {
            api.notaLogs("fin del log (el contenedor se ha parado)");
            api.pintarLogs("fin");
            return;
        } else {
            return;
        }
        if (!reposoLogs.running)
            reposoLogs.start();
    }

    // Pinta lo que haya llegado; con «estado», también lo cambia.
    function pintarLogs(estado) {
        reposoLogs.stop();
        if (!p.logs)
            return;
        const nuevas = p.logsBuffer;
        p.logsBuffer = [];
        let lineas = nuevas.length ? p.logs.lineas.concat(nuevas) : p.logs.lineas;
        if (lineas.length > api.maxLineasLog)
            lineas = lineas.slice(lineas.length - api.maxLineasLog);
        const est = estado || (p.logs.estado === "conectando" ? "abierto" : p.logs.estado);
        p.logs = Object.assign({}, p.logs, {
            lineas: lineas,
            total: p.logs.total + nuevas.length,
            estado: est
        });
    }

    Timer {
        id: reposoLogs
        interval: 100
        onTriggered: api.pintarLogs("")
    }

    function logsAcabados(codigo) {
        if (!p.logsVivo)
            return;
        p.logsVivo = false;
        if (p.logsOtro) {
            p.logsOtro = false;
            api.lanzarLogs();
            return;
        }
        // Cerrados a posta, o ya sustituidos por otros.
        if (p.secCurlLogs !== p.secLogs || !p.logs || p.logs.estado === "fin")
            return;
        if (p.logsHttp === "404") {
            api.notaLogs("ese contenedor ya no está en el NUC");
            api.pintarLogs("cortado");
            p.logs = Object.assign({}, p.logs, {
                error: "Ese contenedor ya no está en el NUC."
            });
            return;
        }
        if (p.logsHttp === "401") {
            api.pintarLogs("cortado");
            api.noAutorizado();
            return;
        }
        api.notaLogs("conexión perdida; vuelve a abrir los logs");
        api.pintarLogs("cortado");
        const h = parseInt(p.logsHttp) || 0;
        p.logs = Object.assign({}, p.logs, {
            error: h >= 400 ? "El panel ha respondido HTTP " + h + "." : "Se ha cortado la conexión con el NUC" + (codigo > 0 ? " (curl " + codigo + ")." : ".")
        });
    }

    Process {
        id: procLogs

        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => api.bloqueLogs(data)
        }

        // La contraseña, como en los eventos: por la entrada estándar.
        onStarted: {
            procLogs.write(api.configCurl());
            procLogs.stdinEnabled = false;
        }

        onExited: codigo => api.logsAcabados(codigo)

        onRunningChanged: if (!procLogs.running)
            Qt.callLater(() => {
                if (p.logsVivo && !procLogs.running)
                    api.logsAcabados(-1);
            })
    }

    // --- Fase 4: consumo ---------------------------------------------------------------
    // Un curl -N a /api/stats mientras verConsumo y la conexión siguen. Si se
    // corta sin querer, otro a los 5 s (mientras se siga mirando).

    readonly property bool quiereConsumo: api.verConsumo && p.conexion === "conectado" && p.clave !== ""

    onQuiereConsumoChanged: api.ajustarConsumo()

    // Si el curl de antes se está parando, el nuevo sale al acabar él
    // (consumoAcabado).
    function ajustarConsumo() {
        if (api.quiereConsumo) {
            if (!p.consumoVivo && !reintentoConsumo.running)
                api.lanzarConsumo();
            return;
        }
        reintentoConsumo.stop();
        p.consumo = null;
        if (p.consumoVivo) {
            p.consumoParado = true;
            procConsumo.running = false;
        }
    }

    function lanzarConsumo() {
        p.consumoHttp = "";
        p.consumoVivo = true;
        procConsumo.command = api.comandoFlujo("/api/stats");
        procConsumo.stdinEnabled = true;
        procConsumo.running = true;
    }

    function consumoDe(d) {
        const h = d.host || {};
        const cont = {};
        for (const k of Object.keys(d.containers || {})) {
            const u = d.containers[k] || {};
            cont[k] = {
                cpu: +u.cpu || 0,
                mem: +u.mem || 0,
                memLimite: +u.memLimit || 0
            };
        }
        return {
            host: {
                cpu: +h.cpu || 0,
                memUsada: +h.memUsed || 0,
                memTotal: +h.memTotal || 0,
                carga: +h.load1 || 0,
                discos: (h.disks || []).map(x => ({
                            ruta: String(x.path || ""),
                            montado: !!x.mounted,
                            usado: +x.used || 0,
                            total: +x.total || 0
                        }))
            },
            contenedores: cont,
            cuando: new Date()
        };
    }

    function bloqueConsumo(texto) {
        const b = api.leerBloque(texto);
        if (b.http !== "")
            p.consumoHttp = b.http;
        if (b.evento !== "stats" || b.datos === null || !api.quiereConsumo)
            return;
        try {
            p.consumo = api.consumoDe(JSON.parse(b.datos));
        } catch (e) {}
    }

    function consumoAcabado() {
        if (!p.consumoVivo)
            return;
        p.consumoVivo = false;
        const aPosta = p.consumoParado;
        p.consumoParado = false;
        if (p.consumoHttp === "401") {
            api.noAutorizado();
            return;
        }
        if (!api.quiereConsumo)
            return;
        if (aPosta)
            api.lanzarConsumo();
        else
            reintentoConsumo.restart();
    }

    Timer {
        id: reintentoConsumo
        interval: 5000
        onTriggered: if (api.quiereConsumo && !p.consumoVivo)
            api.lanzarConsumo()
    }

    Process {
        id: procConsumo

        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => api.bloqueConsumo(data)
        }

        onStarted: {
            procConsumo.write(api.configCurl());
            procConsumo.stdinEnabled = false;
        }

        onExited: api.consumoAcabado()

        onRunningChanged: if (!procConsumo.running)
            Qt.callLater(() => {
                if (p.consumoVivo && !procConsumo.running)
                    api.consumoAcabado();
            })
    }

    // --- Fase 4: registro ----------------------------------------------------------------
    // GET /api/journal por páginas (la más nueva primero) con el filtro de la
    // web, y GET /api/journal/{id} para el detalle de una línea, que la lista
    // no trae. Las líneas nuevas llegan solas por el evento «journal».

    function entradaDe(e) {
        return {
            id: Number(e.id) || 0,
            hora: api.fecha(e.time) || new Date(),
            fuente: String(e.source || ""),
            nivel: e.level === "error" || e.level === "warn" ? e.level : "info",
            objetivo: String(e.target || ""),
            titulo: String(e.title || ""),
            conDetalle: !!e.hasDetail
        };
    }

    function rangoNivel(n) {
        return n === "error" ? 2 : n === "warn" ? 1 : 0;
    }

    function pasaFiltro(e, filtro) {
        if (!filtro)
            return true;
        if (filtro.startsWith("level:"))
            return api.rangoNivel(e.nivel) >= api.rangoNivel(filtro.slice(6));
        return e.fuente === filtro;
    }

    // Desde el principio, con ese filtro (sin filtro, el que tenía). Con el
    // mismo filtro, lo de antes se sigue viendo mientras llega lo nuevo.
    function cargarRegistro(filtro) {
        if (p.clave === "")
            return;
        const f = filtro === undefined || filtro === null ? (p.registro ? p.registro.filtro : "") : String(filtro);
        const mismo = p.registro !== null && p.registro.filtro === f;
        p.registroVivas = [];
        p.registro = {
            filtro: f,
            cargando: true,
            error: "",
            entradas: mismo ? p.registro.entradas : [],
            mas: mismo ? p.registro.mas : false,
            siguiente: mismo ? p.registro.siguiente : "",
            notas: p.registro ? p.registro.notas : []
        };
        api.leerRegistro(f, "");
    }

    // La página siguiente (más vieja).
    function masRegistro() {
        const r = p.registro;
        if (!r || r.cargando || !r.mas || !r.siguiente)
            return;
        p.registro = Object.assign({}, r, {
            cargando: true,
            error: ""
        });
        api.leerRegistro(r.filtro, r.siguiente);
    }

    function leerRegistro(filtro, antes) {
        const sec = ++p.secRegistro;
        const q = ["limit=" + api.paginaRegistro];
        if (filtro.startsWith("level:"))
            q.push("level=" + encodeURIComponent(filtro.slice(6)));
        else if (filtro)
            q.push("source=" + encodeURIComponent(filtro));
        if (antes)
            q.push("before=" + encodeURIComponent(antes));
        const gen = p.generacion;
        api.pedir("GET", "/api/journal?" + q.join("&"), undefined, (estado, texto) => {
            if (gen !== p.generacion || sec !== p.secRegistro || !p.registro)
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
                p.registro = Object.assign({}, p.registro, {
                    cargando: false,
                    error: "No se pudo leer el registro" + api.porQue(estado, texto)
                });
                return;
            }
            const pagina = (d.entries || []).map(api.entradaDe);
            let entradas;
            if (antes) {
                const ya = {};
                for (const e of p.registro.entradas)
                    ya[e.id] = true;
                entradas = p.registro.entradas.concat(pagina.filter(e => !ya[e.id]));
            } else {
                // Las que llegaron por los eventos mientras se leía la página,
                // si no vienen ya en ella, delante. (Por el id no se puede: va
                // por orden de escritura, y la lista va por la hora.)
                const enPagina = {};
                for (const e of pagina)
                    enPagina[e.id] = true;
                entradas = p.registroVivas.filter(e => !enPagina[e.id]).concat(pagina);
                p.registroVivas = [];
            }
            p.registro = {
                filtro: filtro,
                cargando: false,
                error: "",
                entradas: entradas,
                mas: !!d.more,
                siguiente: String(d.next || ""),
                notas: (d.notes || []).map(String)
            };
            api.bien();
        });
    }

    // Una línea nueva del Registro (evento «journal»), arriba, si pasa el
    // filtro y ya se estaba mirando.
    function eventoRegistro(d) {
        if (!d || typeof d !== "object" || p.registro === null)
            return;
        const e = api.entradaDe(d);
        if (!api.pasaFiltro(e, p.registro.filtro) || p.registro.entradas.some(x => x.id === e.id))
            return;
        if (p.registro.cargando)
            p.registroVivas = [e].concat(p.registroVivas);
        p.registro = Object.assign({}, p.registro, {
            entradas: [e].concat(p.registro.entradas)
        });
    }

    // El detalle de una línea: alAcabar(texto, error), con error "" si fue
    // bien.
    function detalleRegistro(id, alAcabar) {
        if (p.clave === "") {
            alAcabar("", "No hay conexión con el NUC.");
            return;
        }
        const gen = p.generacion;
        api.pedir("GET", "/api/journal/" + encodeURIComponent(String(id)), undefined, (estado, texto) => {
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
            if (!d)
                alAcabar("", "No se pudo leer" + api.porQue(estado, texto));
            else
                alAcabar(String(d.detail || ""), "");
        });
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

    // --- Fase 5: Revisiones ------------------------------------------------------
    // Los reminders de la semana y su retro y su planning, de /api/revisiones.
    // El cajón no genera nada: enseña las notas del usuario y guarda lo que
    // escribe, un apartado cada vez. Se lee al entrar en la sección y al cambiar
    // de semana; los eventos no lo empujan. Estado propio («rv») para no tocar «p».

    // La semana que se está viendo, o null sin cargar:
    //   { habilitado, error, semana ("2026-S43"), etiqueta, lunes, domingo, hoy
    //     (AAAA-MM-DD), actual (es esta semana), semanaActual, anterior,
    //     siguiente, semanas, reminders: [{ fecha, existe, editable, texto }],
    //     planning y retro: { existe, ruta, secciones: [{ i, nivel, titulo,
    //     cuerpo }] } }
    readonly property var revisiones: rv.semana
    readonly property var revisionesCargadas: rv.cargada
    // Por qué no se pudo leer la semana; "" si bien.
    readonly property string revisionesError: rv.error
    // true mientras se guarda algo.
    readonly property bool revisionesOcupado: rv.escribiendo
    // La semana pedida ("" es esta semana), para releerla donde estaba.
    readonly property string revisionesPedida: rv.pedida

    QtObject {
        id: rv

        property var semana: null
        property var cargada: null
        property string error: ""
        property bool escribiendo: false
        property string pedida: ""
        property int sec: 0
    }

    function revisionesDe(w) {
        const nota = n => ({
                existe: !!(n && n.existe),
                ruta: String(n && n.path || ""),
                secciones: ((n && n.secciones) || []).map(s => ({
                            i: +s.i,
                            nivel: +s.nivel,
                            titulo: String(s.titulo || ""),
                            cuerpo: String(s.cuerpo || "")
                        }))
            });
        return {
            habilitado: w.enabled !== false,
            error: String(w.error || ""),
            semana: String(w.semana || ""),
            etiqueta: String(w.etiqueta || ""),
            lunes: String(w.lunes || ""),
            domingo: String(w.domingo || ""),
            hoy: String(w.hoy || ""),
            actual: !!w.actual,
            semanaActual: String(w.semanaActual || ""),
            anterior: String(w.anterior || ""),
            siguiente: String(w.siguiente || ""),
            semanas: (w.semanas || []).map(String),
            reminders: (w.reminders || []).map(r => ({
                        fecha: String(r.fecha),
                        existe: !!r.existe,
                        editable: r.editable === true,
                        texto: String(r.texto || "")
                    })),
            planning: nota(w.planning),
            retro: nota(w.retro)
        };
    }

    // GET /api/revisiones?semana=…; "" es esta semana. Una respuesta de una
    // petición vieja (se cambió de semana mientras tanto) se tira.
    function cargarRevisiones(semana) {
        if (p.clave === "")
            return;
        const gen = p.generacion;
        const sec = ++rv.sec;
        const pedida = semana === undefined ? rv.pedida : String(semana);
        rv.pedida = pedida;
        api.pedir("GET", "/api/revisiones" + (pedida !== "" ? "?semana=" + encodeURIComponent(pedida) : ""), undefined, (estado, texto) => {
            if (gen !== p.generacion || sec !== rv.sec)
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
                rv.error = "No se pudieron leer las revisiones" + api.porQue(estado, texto);
                return;
            }
            rv.semana = api.revisionesDe(d);
            rv.cargada = new Date();
            rv.error = "";
        });
    }

    // Guarda el reminder de un día (se crea desde la plantilla si no existe).
    // «antes» es el texto del que se partió: si cambió en las notas, el NUC
    // contesta 409 y no escribe. alAcabar("ok" | "obsoleta" | "error").
    function guardarRecordatorio(fecha, antes, texto, alAcabar) {
        api.escribirRevision("/api/revisiones/reminder", {
            fecha: fecha,
            antes: antes,
            texto: texto
        }, alAcabar);
    }

    // Guarda el cuerpo de un apartado de la retro o del planning (tipo:
    // "retro" o "planning"); i y titulo dicen cuál, y «antes» como arriba.
    function guardarApartado(tipo, semana, i, titulo, antes, cuerpo, alAcabar) {
        api.escribirRevision("/api/revisiones/nota", {
            tipo: tipo,
            semana: semana,
            i: i,
            titulo: titulo,
            antes: antes,
            cuerpo: cuerpo
        }, alAcabar);
    }

    // Crea la retro o el planning de la semana desde la plantilla.
    function crearNotaRevision(tipo, semana, alAcabar) {
        api.escribirRevision("/api/revisiones/nota", {
            tipo: tipo,
            semana: semana,
            crear: true
        }, alAcabar);
    }

    // Una escritura. 200: la semana nueva. 409: alguien cambió la nota por
    // otro lado; el NUC manda la semana como está y no escribe nada, se
    // recarga y se avisa. Otro fallo (403, 422…): se avisa con lo que diga el
    // NUC y lo que se veía se queda como estaba.
    function escribirRevision(ruta, cuerpo, alAcabar) {
        if (p.conexion !== "conectado" || rv.escribiendo) {
            if (alAcabar)
                alAcabar("error");
            return;
        }
        rv.escribiendo = true;
        const gen = p.generacion;
        api.pedir("POST", ruta, cuerpo, (estado, texto) => {
            rv.escribiendo = false;
            if (gen !== p.generacion)
                return;
            const d = api.leerJSON({
                estado: estado === 409 ? 200 : estado,
                texto: texto
            });
            let res = "error";
            if (estado === 200 && d) {
                rv.semana = api.revisionesDe(d);
                rv.cargada = new Date();
                rv.error = "";
                res = "ok";
                api.bien();
            } else if (estado === 409 && d && d.revisiones) {
                rv.semana = api.revisionesDe(d.revisiones);
                rv.cargada = new Date();
                res = "obsoleta";
                api.aviso("Tus notas han cambiado; las he recargado. Revisa lo que escribías.", true);
            } else if (estado === 409) {
                res = "obsoleta";
                api.cargarRevisiones();
                api.aviso("Tus notas han cambiado; las he recargado. Revisa lo que escribías.", true);
            } else if (estado === 401) {
                api.noAutorizado();
            } else {
                api.aviso("No se pudo guardar" + api.porQue(estado, texto), true);
            }
            if (alAcabar)
                alAcabar(res);
        });
    }
}
