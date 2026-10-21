import QtQuick
import Quickshell
import Quickshell.Io
import "shared/AgendaFormato.js" as Formato

// La agenda para el calendario de la barra.
//
// La barra (quickshell/bar) es otro proceso y no habla con el NUC. Lo que tiene
// fecha en el panel (las tareas de 00 Inicio con 📅 y las entregas de Aules: lo
// mismo que el panel lleva a los calendarios «Clase» y «Personal» de Google) se
// lo deja este en un fichero de $XDG_RUNTIME_DIR que la barra vigila. Así no
// hay una segunda conexión con el NUC ni una segunda lectura del llavero: sale
// de las tareas que Api.qml ya tiene, y se reescribe cada vez que cambian
// (el evento «tareas», una escritura, al abrir el cajón) o cambia la conexión.
// El formato, en shared/AgendaFormato.js.
//
// El fichero está en memoria (tmpfs, se va al cerrar la sesión), es solo del
// usuario (umask 077: modo 600) y se escribe entero de una vez, con un
// temporal y mv, así la barra nunca lee uno a medias. Al arrancar se borra el
// que hubiera de una vez anterior: hasta que lleguen las tareas, la barra no
// enseña nada que este proceso no sepa. Ni el JSON ni el texto de una tarea
// van nunca a un log.
Scope {
    id: agenda

    // El Api.qml del shell (o la falsa de las pruebas): tareas, tareasCargadas
    // y conexion.
    property var api: null

    // Las pruebas lo cambian; "" (sin XDG_RUNTIME_DIR) no escribe nada.
    property string ruta: Formato.ruta(Quickshell.env("XDG_RUNTIME_DIR"))

    // Una ráfaga de cambios (las tareas y la conexión llegan casi juntas) se
    // escribe una vez.
    property int espera: 400

    // Para las pruebas y para mirar desde fuera: las veces que se ha escrito o
    // borrado el fichero.
    readonly property int escrituras: p.escrituras

    QtObject {
        id: p

        // Lo que hay en el fichero ahora: el JSON, "" si no está, o null si no
        // se sabe (al arrancar, que se borra).
        property var escrito: null
        // Lo que está escribiendo el sh en marcha.
        property string texto: ""
        // Ha cambiado algo mientras se escribía: otra vez al acabar.
        property bool otraVez: false
        property int escrituras: 0
        // Las últimas tareas que el panel pudo leer, y cuándo.
        property var buenas: null
        property var buenasCargadas: null
    }

    // Lo que tiene que haber en el fichero: el JSON, "" para que no haya
    // fichero, o null para dejarlo como está.
    function contenido() {
        const a = agenda.api;
        const t = a ? a.tareas : null;
        if (t && t.error) {
            // El panel no pudo leer la nota: se quedan las últimas tareas
            // buenas (si las hay), aunque la conexión sí se pone al día.
            if (!p.buenas)
                return null;
        } else {
            p.buenas = t;
            p.buenasCargadas = a ? a.tareasCargadas : null;
        }
        const datos = Formato.deTareas(p.buenas, a && a.conexion === "conectado", p.buenasCargadas);
        return datos ? JSON.stringify(datos) : "";
    }

    function escribir() {
        if (agenda.ruta === "")
            return;
        if (escritor.running) {
            p.otraVez = true;
            return;
        }
        const texto = agenda.contenido();
        if (texto === null || texto === p.escrito)
            return;
        p.texto = texto;
        escritor.stdinEnabled = true;
        escritor.running = true;
    }

    Timer {
        id: rafaga
        interval: agenda.espera
        onTriggered: agenda.escribir()
    }

    Connections {
        target: agenda.api
        ignoreUnknownSignals: true

        function onTareasChanged() {
            rafaga.restart();
        }

        function onConexionChanged() {
            rafaga.restart();
        }
    }

    Component.onCompleted: agenda.escribir()
    onRutaChanged: {
        p.escrito = null;
        agenda.escribir();
    }

    Process {
        id: escritor

        // La ruta va como argumento, nunca dentro del guion. Con texto, se
        // escribe; sin él, se borra. umask 077 hace que el temporal nazca con
        // modo 600, y mv lo pone en su sitio de una vez.
        command: ["sh", "-c", "umask 077 && if [ -z \"$2\" ]; then rm -f -- \"$1\"; else cat > \"$1.tmp\" && mv -f -- \"$1.tmp\" \"$1\"; fi", "sh", agenda.ruta, p.texto === "" ? "" : "escribir"]

        // El JSON entra por aquí, y al cerrar la entrada cat acaba.
        onStarted: {
            if (p.texto !== "")
                escritor.write(p.texto);
            escritor.stdinEnabled = false;
        }

        onExited: codigo => {
            if (codigo === 0)
                p.escrito = p.texto;
            else
                console.warn("No se pudo dejar la agenda para la barra (sh " + codigo + ")");
            p.escrituras++;
            if (p.otraVez) {
                p.otraVez = false;
                agenda.escribir();
            }
        }
    }
}
