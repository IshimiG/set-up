import QtQuick
import Quickshell
import Quickshell.Wayland

// El hueco que las ventanas no deben invadir.
//
// Esto lo reservaba waybar. Al quedarse sin nada que dibujar hubo que hacerlo
// aquí, y no se puede hacer desde las superficies que ya existen: las tres
// están ancladas a los cuatro lados —la isla porque tiene que poder desplegarse
// hacia abajo, los laterales porque tienen que poder enseñar su globo— y
// layer-shell sólo respeta una zona exclusiva cuando la superficie está anclada
// a un borde. Anclada a los cuatro, el compositor la ignora: comprobado,
// `hyprctl monitors` devolvía reserved = [0,0,0,0].
//
// Así que ésta es una franja aparte, del alto de la barra, anclada arriba y a
// los dos lados, invisible y sin máscara de entrada: no pinta nada y no recibe
// nada. Su único trabajo es ocupar sitio.
PanelWindow {
    id: strut

    required property var shell

    readonly property int alto: 29

    WlrLayershell.namespace: "barra-hueco"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: strut.alto

    // Máscara vacía: todos los clics atraviesan la franja y llegan a lo que haya
    // debajo. Sin esto, una banda de 29 px a lo ancho de la pantalla se comería
    // los clics del borde superior de las ventanas.
    mask: Region {}

    color: "transparent"

    // Al esconder la barra con SUPER+SHIFT+V el hueco desaparece con ella y las
    // ventanas recuperan el borde de arriba, que es lo que hacía waybar al
    // morir. No hace falta animarlo: lo que se anima es el cristal, y esto no
    // se ve.
    visible: !strut.shell.hidden
}
