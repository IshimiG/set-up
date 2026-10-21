import QtQuick
import "shared"

// Un trozo de texto de una nota (MarkdownLogica.trozo): StyledText ya saneado,
// con sus enlaces. Un clic en un enlace se lo pasa a Notas.qml (ctrl.enlace),
// que decide: otra nota en el cajón o la web en el navegador. Con el cajón a
// medio sacar enseña la copia con los euros tapados (E11).
Text {
    id: texto

    // Notas.qml: enlace(href) y desplegado.
    required property var ctrl
    // { html, oculto }.
    property var trozo: null
    // La clave de una cabecera (para ir a ella desde un [[nota#Cabecera]]).
    property string clave: ""

    text: !texto.trozo ? "" : (texto.ctrl.desplegado ? texto.trozo.html : texto.trozo.oculto)
    textFormat: Text.StyledText
    wrapMode: Text.Wrap
    color: Theme.text
    linkColor: Theme.strong
    font.family: Theme.font
    font.pixelSize: 12
    lineHeight: 1.2

    onLinkActivated: link => texto.ctrl.enlace(link)

    HoverHandler {
        cursorShape: texto.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
