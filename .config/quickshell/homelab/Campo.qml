import QtQuick
import "shared"

// Un campo de texto de cristal. Intro acepta (en multilínea, Ctrl+Intro, y
// Intro es un salto de línea) y Escape cancela; las dos cosas se avisan con
// señales y lo que hacer lo decide quien lo usa. Mientras tiene el foco se
// come las teclas de escribir: los atajos de las tareas no se enteran.
Rectangle {
    id: campo

    property alias texto: edit.text
    property string pista: ""
    property bool multilinea: false
    readonly property bool enfocado: edit.activeFocus
    property int tamano: 12

    signal aceptado
    signal cancelado

    function enfocar() {
        edit.forceActiveFocus();
    }

    // El cursor tras el último carácter (para seguir escribiendo).
    function alFinal() {
        edit.cursorPosition = edit.length;
    }

    function seleccionarTodo() {
        edit.selectAll();
    }

    implicitHeight: Math.max(30, edit.contentHeight + 16)
    radius: 8
    color: edit.activeFocus ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
    border.width: 1
    border.color: edit.activeFocus ? Qt.rgba(1, 1, 1, 0.3) : Theme.rule
    clip: true

    Behavior on border.color {
        ColorAnimation {
            duration: 140
        }
    }

    Text {
        anchors.fill: edit
        visible: edit.text === "" && !edit.preeditText
        text: campo.pista
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: campo.tamano
        elide: Text.ElideRight
    }

    TextEdit {
        id: edit

        anchors.fill: parent
        anchors.margins: 8
        color: Theme.strong
        selectionColor: Qt.rgba(1, 1, 1, 0.3)
        selectedTextColor: Theme.strong
        font.family: Theme.font
        font.pixelSize: campo.tamano
        wrapMode: TextEdit.Wrap
        selectByMouse: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (!campo.multilinea || (event.modifiers & Qt.ControlModifier)) {
                    event.accepted = true;
                    campo.aceptado();
                }
            } else if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                campo.cancelado();
            }
        }
    }
}
