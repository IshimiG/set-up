import QtQuick
import Quickshell
import Quickshell.Io

// La wifi: el estado de la radio y las redes a la vista, para el icono de la
// barra y para su desplegable. Una sola vez para los dos monitores, como
// Telemetry.qml.
//
// Todo pasa por ~/.config/hypr/scripts/wifi.sh, que habla con iwd por D-Bus.
// No se muestrea a ciegas: el script deja abierta una escucha de las señales de
// iwd y cada cambio (se conecta, se cae, termina un escaneo) dispara una
// relectura. Lo único que iwd no anuncia es la intensidad de la señal, y para
// eso queda un latido lento.
Scope {
    id: wifi

    required property var shell

    // El desplegable está abierto en algún monitor. Mientras lo está, la lista
    // se refresca más a menudo y se escanea al abrir.
    property bool mirando: false

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/wifi.sh"

    // --- El estado ---------------------------------------------------------
    property bool listo: false
    property bool hay: false
    property bool encendida: false
    // El State de iwd: connected, connecting, disconnected, roaming... y
    // "apagada" cuando la radio no tiene Station.
    property string estado: ""
    property bool escaneando: false
    property int frecuencia: 0
    property string ip: ""

    // La red conectada, o null.
    property var actual: null
    readonly property bool conectada: wifi.actual !== null && wifi.estado === "connected"

    // Las demás, en un ListModel y no en un array: si se reemplazara el array
    // en cada relectura, la lista del desplegable rehará todas sus filas cada
    // pocos segundos, perdiendo el resalte bajo el ratón. Con el modelo, las
    // filas que siguen ahí sólo cambian de datos.
    property alias otras: modelo

    ListModel {
        id: modelo
    }

    // --- Lo que se está haciendo ---------------------------------------------
    // La ruta de la red a la que se intenta conectar, o la acción en marcha
    // ("radio", "desconectar"...). Vacío es que no hay nada en curso.
    property string trabajando: ""
    property string error: ""
    // De qué red es el error, para enseñarlo junto a ella.
    property string errorDe: ""

    // Termina una acción: ok o no, y sobre qué.
    signal terminado(bool ok, string sobre)

    // Los mismos cinco escalones que tenía el icono de red de waybar en
    // Omarchy, más el de sin conexión y el de radio apagada.
    readonly property var glifosSenal: [String.fromCodePoint(0xF092F), String.fromCodePoint(0xF091F), String.fromCodePoint(0xF0922), String.fromCodePoint(0xF0925), String.fromCodePoint(0xF0928)]
    readonly property string glifoSinRed: String.fromCodePoint(0xF092E)
    readonly property string glifoApagada: String.fromCodePoint(0xF05AA)

    function glifoDe(senal) {
        return wifi.glifosSenal[Math.max(0, Math.min(4, Math.floor(senal / 20)))];
    }

    readonly property string glifo: {
        if (!wifi.listo || !wifi.hay)
            return "";
        if (!wifi.encendida)
            return wifi.glifoApagada;
        if (!wifi.conectada)
            return wifi.glifoSinRed;
        return wifi.glifoDe(wifi.actual.senal);
    }

    // --- Leer ----------------------------------------------------------------
    property bool otraVez: false

    function refrescar() {
        if (lector.running)
            wifi.otraVez = true;
        else
            lector.running = true;
    }

    Process {
        id: lector

        command: [wifi.script, "estado"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: wifi.aplicar(this.text)
        }

        onExited: {
            if (wifi.otraVez) {
                wifi.otraVez = false;
                lector.running = true;
            }
        }
    }

    function aplicar(texto) {
        let e;
        try {
            e = JSON.parse(texto);
        } catch (err) {
            return;
        }
        wifi.listo = true;
        wifi.hay = e.iwd === true && e.hay === true;
        if (!wifi.hay) {
            wifi.actual = null;
            modelo.clear();
            return;
        }
        wifi.encendida = e.encendida;
        wifi.estado = e.estado;
        wifi.escaneando = e.escaneando;
        wifi.frecuencia = e.frecuencia;
        wifi.ip = e.ip;

        let actual = null;
        const resto = [];
        for (let i = 0; i < e.redes.length; i++) {
            if (e.redes[i].conectada)
                actual = e.redes[i];
            else
                resto.push(e.redes[i]);
        }
        wifi.actual = actual;

        // Se cambian los datos de las filas que ya existen y sólo se añaden o
        // se quitan las que sobran o faltan.
        for (let i = 0; i < resto.length; i++) {
            if (i < modelo.count)
                modelo.set(i, resto[i]);
            else
                modelo.append(resto[i]);
        }
        if (modelo.count > resto.length)
            modelo.remove(resto.length, modelo.count - resto.length);
    }

    // iwd avisa de cada cambio por D-Bus. Durante un escaneo llegan decenas de
    // señales seguidas, así que no se relee en cada una: se espera a que paren.
    Process {
        id: vigia

        command: [wifi.script, "vigilar"]
        running: true

        stdout: SplitParser {
            onRead: rebote.restart()
        }

        // Si iwd se reinicia o la escucha muere, se vuelve a abrir.
        onExited: revivir.start()
    }

    Timer {
        id: revivir
        interval: 3000
        onTriggered: vigia.running = true
    }

    Timer {
        id: rebote
        interval: 350
        onTriggered: wifi.refrescar()
    }

    // La señal, que es lo único que iwd no anuncia. Con la barra escondida no
    // mira nadie, así que no se lee.
    Timer {
        interval: wifi.mirando ? 4000 : 15000
        running: !wifi.shell.hidden
        repeat: true
        onTriggered: wifi.refrescar()
    }

    onMirandoChanged: {
        if (wifi.mirando) {
            wifi.refrescar();
            wifi.escanear();
        } else {
            // Al cerrar el desplegable se olvida el error: la próxima vez se
            // abre limpio.
            wifi.error = "";
            wifi.errorDe = "";
        }
    }

    // --- Hacer ---------------------------------------------------------------
    // Una sola acción a la vez. Las contraseñas van por el entorno del proceso,
    // nunca en la línea de órdenes (ver wifi.sh).
    function ejecutar(sobre, args, entorno, aviso) {
        if (accion.running)
            return;
        wifi.error = "";
        wifi.errorDe = "";
        wifi.trabajando = sobre;
        accion.sobre = sobre;
        accion.aviso = aviso || "";
        accion.codigo = -1;
        accion.leida = false;
        accion.environment = entorno || {};
        accion.command = [wifi.script].concat(args);
        accion.running = true;
    }

    Process {
        id: accion

        property string sobre: ""
        // Qué notificar si sale bien con el desplegable cerrado. Vacío, nada.
        property string aviso: ""

        // El final se da cuando han pasado las dos cosas, el proceso ha
        // salido y su salida se ha leído entera, en el orden que sea: sin la
        // salida no hay motivo que enseñar, y sin el código no se sabe si
        // hubo error.
        property int codigo: -1
        property bool leida: false

        stdout: StdioCollector {
            id: salida
            onStreamFinished: {
                accion.leida = true;
                wifi.acabar();
            }
        }

        onExited: codigo => {
            accion.codigo = codigo;
            wifi.acabar();
        }
    }

    function acabar() {
        if (accion.codigo < 0 || !accion.leida)
            return;
        const ok = accion.codigo === 0;
        const sobre = accion.sobre;
        accion.codigo = -1;
        accion.leida = false;
        accion.environment = {};
        wifi.trabajando = "";
        if (!ok) {
            wifi.error = salida.text.trim() || "No se ha podido";
            wifi.errorDe = sobre;
            // Con el desplegable cerrado —pasa con las redes de empresa,
            // porque la ventana de polkit se lleva el foco y lo cierra—, el
            // error se avisa por notificación.
            if (!wifi.mirando)
                Quickshell.execDetached(["notify-send", "-a", "Wi-Fi", "-i", "network-wireless-offline", "Wi-Fi", wifi.error]);
        } else if (accion.aviso !== "" && !wifi.mirando) {
            Quickshell.execDetached(["notify-send", "-a", "Wi-Fi", "-i", "network-wireless", "Wi-Fi", accion.aviso]);
        }
        wifi.terminado(ok, sobre);
        wifi.refrescar();
    }

    function escanear() {
        if (wifi.encendida && !wifi.escaneando)
            Quickshell.execDetached([wifi.script, "escanear"]);
    }

    // Una red abierta o ya guardada: no hay nada que preguntar.
    function conectar(ruta) {
        wifi.ejecutar(ruta, ["conectar", ruta]);
    }

    function conectarConClave(ruta, ssid, clave) {
        wifi.ejecutar(ruta, ["clave"], {
            WIFI_SSID: ssid,
            WIFI_CLAVE: clave
        });
    }

    // Ésta se lanza con el desplegable ya cerrado (ver WifiPanel.qml), así que
    // avisa también cuando sale bien.
    function conectarEmpresa(ruta, ssid, metodo, usuario, clave) {
        wifi.ejecutar(ruta, ["empresa"], {
            WIFI_SSID: ssid,
            WIFI_METODO: metodo,
            WIFI_USUARIO: usuario,
            WIFI_CLAVE: clave
        }, "Conectado a " + ssid);
    }

    function desconectar() {
        wifi.ejecutar("desconectar", ["desconectar"]);
    }

    function olvidar(ruta) {
        wifi.ejecutar(ruta, ["olvidar", ruta]);
    }

    function alternarRadio() {
        wifi.ejecutar("radio", ["radio", wifi.encendida ? "off" : "on"]);
    }

    // Lo de Omarchy, para lo que el desplegable no cubre (redes ocultas,
    // modo punto de acceso...).
    function abrirImpala() {
        Quickshell.execDetached(["sh", "-c", "rfkill unblock wifi; exec ghostty --title=Impala -e impala"]);
    }
}
