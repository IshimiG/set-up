import QtQuick
import QtQuick.Layouts
import "shared"
import "TareasLogica.js" as Logica

// Clase: el botón «Actualizar Aules» y su línea de estado. El botón lanza en
// el NUC la actualización de las notas de clase (aules-sync), que de paso pasa
// las entregas con fecha a las tareas (sección Clase) y al calendario «Clase».
// La línea dice cómo va: en marcha, cuándo acabó la última y qué cambió. Sale
// de api.clase, que se pone al día con el evento «clase» si el servidor lo
// manda, o al abrir el cajón y justo después de pulsar el botón si no.
Item {
    id: clase

    required property var shell
    readonly property var api: clase.shell.api
    readonly property var estado: clase.api ? clase.api.clase : null
    readonly property bool ejecutando: clase.estado !== null && clase.estado.ejecutando
    property string lineaConexion: ""

    // Lo que hizo la última actualización, en unas palabras.
    function resumenTareas(m) {
        if (!m)
            return "";
        const partes = [];
        if (m.anadidas)
            partes.push(Logica.plural(m.anadidas, "tarea nueva", "tareas nuevas"));
        if (m.fechas)
            partes.push(Logica.plural(m.fechas, "fecha cambiada", "fechas cambiadas"));
        if (m.completadas)
            partes.push(Logica.plural(m.completadas, "entregada", "entregadas"));
        return partes.join(", ");
    }

    function resumenCalendario(c) {
        if (!c || c.error)
            return "";
        const partes = [];
        if (c.creados)
            partes.push(Logica.plural(c.creados, "nuevo", "nuevos"));
        if (c.cambiados)
            partes.push(Logica.plural(c.cambiados, "cambiado", "cambiados"));
        if (c.borrados)
            partes.push(Logica.plural(c.borrados, "quitado", "quitados"));
        return partes.length ? "calendario: " + partes.join(", ") : "";
    }

    // La línea de estado: { nivel ("ok", "mal" o ""), texto }.
    readonly property var linea: {
        const st = clase.estado;
        if (!st)
            return {
                nivel: "",
                texto: clase.api && clase.api.conexion === "conectado" ? "Mirando cómo está Aules…" : ""
            };
        if (st.ejecutando)
            return {
                nivel: "",
                texto: "Actualizando Aules… puede tardar un par de minutos."
            };
        if (st.estado === "sin-unidad" || st.estado === "error")
            return {
                nivel: "mal",
                texto: (st.error || "Falló la última actualización de Aules.") + (st.terminado ? " (" + Logica.hace(st.terminado) + ")" : "")
            };
        if (st.estado === "nunca")
            return {
                nivel: "",
                texto: "Aules todavía no se ha actualizado desde el panel."
            };
        const resumen = [clase.resumenTareas(st.tareas), clase.resumenCalendario(st.calendario)].filter(x => x !== "").join(" · ");
        let t = "Aules actualizado " + Logica.hace(st.terminado) + (resumen ? " · " + resumen : "");
        if (st.tareas && st.tareas.error)
            t += " · pero no pude pasar las entregas a las tareas: " + st.tareas.error;
        if (st.calendario && st.calendario.error)
            t += " · pero no pude actualizar el calendario: " + st.calendario.error;
        return {
            nivel: "ok",
            texto: t
        };
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            visible: clase.lineaConexion !== ""
            spacing: 8

            Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Theme.muted
            }

            Text {
                Layout.fillWidth: true
                text: clase.lineaConexion
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Actualiza en el NUC las notas de clase y pasa las entregas con fecha a las tareas (sección Clase) y al calendario."
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }

        Chip {
            objectName: "botonAules"
            texto: clase.ejecutando ? "Actualizando…" : "Actualizar Aules"
            glifo: ""
            tamano: 12
            implicitHeight: 32
            activo: clase.ejecutando
            encendido: clase.api && clase.api.conexion === "conectado" && !clase.ejecutando && !(clase.estado && clase.estado.estado === "sin-unidad")
            onActivado: clase.api.actualizarAules()
        }

        RowLayout {
            Layout.fillWidth: true
            visible: clase.linea.texto !== ""
            spacing: 8

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 4
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: clase.linea.nivel === "ok" ? Theme.ok : (clase.linea.nivel === "mal" ? Theme.danger : Theme.muted)

                SequentialAnimation on opacity {
                    running: clase.ejecutando
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0.25
                        duration: 600
                        easing.type: Easing.InOutQuint
                    }

                    NumberAnimation {
                        to: 1
                        duration: 600
                        easing.type: Easing.InOutQuint
                    }
                }
            }

            Text {
                objectName: "lineaAules"
                Layout.fillWidth: true
                text: clase.linea.texto
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        // El calendario «Personal» solo sale si su última actualización falló.
        RowLayout {
            Layout.fillWidth: true
            visible: !clase.ejecutando && clase.estado !== null && clase.estado.calendarioPersonalError !== ""
            spacing: 8

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 4
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Theme.danger
            }

            Text {
                objectName: "lineaCalPersonal"
                Layout.fillWidth: true
                text: clase.estado ? "No pude poner las tareas en el calendario «Personal»: " + clase.estado.calendarioPersonalError : ""
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }
}
