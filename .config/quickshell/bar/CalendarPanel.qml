import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "shared"

// El calendario, que es lo que el reloj enseña al crecer.
//
// Antes esto era un tooltip de waybar: un bloque de texto monoespaciado con los
// colores metidos a mano en etiquetas de Pango. Se veía como un tooltip y no
// como parte del escritorio, y encima estaba ilegible, porque la cadena de temas
// heredada de Omarchy dejaba el fondo de los tooltips en blanco.
//
// Aquí la rejilla la da MonthGrid de QtQuick.Controls.Basic, que aporta el
// modelo de días —qué día cae en qué casilla, qué días son del mes de al lado—
// y deja el aspecto entero por pintar, que es justo lo que hacía falta.
Item {
    id: root

    required property var shell

    implicitWidth: 300
    implicitHeight: content.implicitHeight + Theme.pad * 2

    // Qué mes se está mirando, como desplazamiento en meses respecto a hoy. La
    // rueda del ratón lo mueve, igual que hacía el módulo de waybar.
    property int monthOffset: 0

    readonly property var loc: Qt.locale("es_ES")

    readonly property date shown: {
        const d = new Date(root.shell.now);
        d.setDate(1);
        d.setMonth(d.getMonth() + root.monthOffset);
        return d;
    }

    readonly property bool onToday: root.monthOffset === 0

    // Al cerrar la isla se vuelve al mes de hoy: si no, abrir el calendario
    // después de haber estado mirando marzo lo abre otra vez en marzo, que nunca
    // es lo que se quiere.
    Connections {
        target: root.shell
        function onModeChanged() {
            if (root.shell.mode !== "calendar")
                root.monthOffset = 0;
        }
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // El número de semana ISO, que es el que daba waybar con %V. Se calcula a
    // mano porque Qt no tiene marcador de formato para él: un "ww" en la cadena
    // de formato sale tal cual, literalmente "ww".
    //
    // La regla ISO es que la semana la decide su jueves. Así que se salta al
    // jueves de la semana de la fecha dada, se hace lo mismo con el 4 de enero
    // —que por definición cae siempre en la semana 1— y se cuentan las semanas
    // entre los dos.
    function semanaISO(fecha) {
        const jueves = new Date(fecha.getFullYear(), fecha.getMonth(), fecha.getDate());
        jueves.setDate(jueves.getDate() + 3 - ((jueves.getDay() + 6) % 7));
        const primero = new Date(jueves.getFullYear(), 0, 4);
        primero.setDate(primero.getDate() + 3 - ((primero.getDay() + 6) % 7));
        return 1 + Math.round((jueves - primero) / (7 * 24 * 3600 * 1000));
    }

    // La rueda mueve el mes. Va en un WheelHandler y no en un MouseArea para no
    // interceptar los clics, que aquí no significan nada.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.monthOffset += event.angleDelta.y > 0 ? -1 : 1;
        }
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.pad
        spacing: 8

        // Cabecera: el mes que se está mirando, y a la derecha la fecha larga
        // con el número de semana de hoy. Esa fecha larga es la que en waybar
        // salía al hacer clic en el reloj; aquí está siempre a la vista, que es
        // mejor que esconderla detrás de un clic.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: root.shown.toLocaleDateString(root.loc, "MMMM yyyy")
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 13
                font.bold: true
            }

            Item {
                Layout.fillWidth: true
            }

            // Volver a hoy. Sólo aparece cuando se ha movido de mes, porque
            // pulsarlo estando en el mes actual no haría nada.
            Text {
                visible: !root.onToday
                text: "󰄉  hoy"
                color: todayHover.hovered ? Theme.strong : Theme.faint
                font.family: Theme.font
                font.pixelSize: 11

                HoverHandler {
                    id: todayHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.monthOffset = 0
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.shell.now.toLocaleDateString(root.loc, "dddd d 'de' MMMM") + "  ·  semana " + root.semanaISO(root.shell.now)
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 11
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 1
            color: Theme.rule
        }

        // Las iniciales de los días. La semana empieza en lunes porque lo dice
        // la configuración regional española, no porque se fije a mano.
        DayOfWeekRow {
            Layout.fillWidth: true
            locale: root.loc

            delegate: Text {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: true
            }
        }

        MonthGrid {
            id: grid

            Layout.fillWidth: true
            locale: root.loc
            month: root.shown.getMonth()
            year: root.shown.getFullYear()
            spacing: 2

            delegate: Item {
                id: cell

                required property var model

                implicitWidth: 34
                implicitHeight: 28

                readonly property bool esHoy: root.sameDay(cell.model.date, root.shell.now)
                // Los días que MonthGrid pone para cuadrar la rejilla pero
                // pertenecen al mes de al lado.
                readonly property bool esDeFuera: cell.model.month !== grid.month

                // Hoy va marcado con una lámina de cristal, la misma que resalta
                // la fila del menú de sesión, en vez de con un color de marca.
                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 24
                    radius: 8
                    visible: cell.esHoy
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.24)
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.model.day
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: cell.esHoy
                    color: cell.esHoy ? Theme.strong : (cell.esDeFuera ? Qt.rgba(1, 1, 1, 0.18) : Theme.text)
                }
            }
        }
    }
}
