import QtQuick
import QtQuick.Layouts
import Quickshell
import "shared"

// Lo de dentro del cajón.
//
// Fase 1: la forma, con datos de prueba inventados. La tira de secciones de la
// izquierda es la de la web (su menú plegado), y cada sección dice en qué fase
// del plan llega. Desde la fase 2 los datos salen de la API del panel y esto
// sólo los pinta: las reglas (la prioridad que sube con la fecha, qué se puede
// escribir) siguen en el NUC.
Item {
    id: contenido

    required property var shell
    // El cajón entero fuera y quieto. Los euros de Finanzas sólo se enseñan así
    // (decisión E11): con el cajón escondido o a medio sacar, nunca.
    property bool desplegado: false

    property string seccion: "inicio"

    // El color del punto del asa: el estado del NUC. En la fase 2 lo ponen las
    // alertas de /api/events; de momento, el verde de «todo bien».
    readonly property color colorEstado: Theme.ok

    // «web» es la ruta de la misma sección en la web del panel.
    readonly property var secciones: [
        {
            id: "inicio",
            icono: "",
            nombre: "Inicio",
            fase: 2,
            web: "#/"
        },
        {
            id: "tareas",
            icono: "",
            nombre: "Tareas",
            fase: 3,
            web: "#/"
        },
        {
            id: "clase",
            icono: "",
            nombre: "Clase",
            fase: 3,
            web: "#/"
        },
        {
            id: "proyectos",
            icono: "",
            nombre: "Proyectos",
            fase: 4,
            web: "#/proyectos"
        },
        {
            id: "servidor",
            icono: "",
            nombre: "Servidor",
            fase: 4,
            web: "#/servidor"
        },
        {
            id: "revisiones",
            icono: "",
            nombre: "Revisiones",
            fase: 5,
            web: "#/revisiones"
        },
        {
            id: "finanzas",
            icono: "",
            nombre: "Finanzas",
            fase: 5,
            web: "#/finanzas"
        }
    ]

    readonly property var actual: contenido.secciones.find(s => s.id === contenido.seccion) || contenido.secciones[0]

    // Datos de prueba: nada de esto sale del NUC.
    readonly property var prueba: ({
            servidor: "9 contenedores en marcha · sin alertas",
            meta: 34,
            ahora: [
                {
                    texto: "Entrega de prueba con fecha",
                    seccion: "Clase",
                    color: "#b48cff",
                    prioridad: "maxima",
                    cuando: "vence mañana"
                },
                {
                    texto: "Revisar la copia de seguridad",
                    seccion: "Homelab",
                    color: "#6aa8ff",
                    prioridad: "alta",
                    cuando: "vence en 3 días"
                },
                {
                    texto: "Una tarea sin fecha",
                    seccion: "General",
                    color: "",
                    prioridad: "media",
                    cuando: "sin fecha"
                }
            ]
        })

    // Los colores de prioridad son los de la web (Theme.qml), para que una
    // tarea se vea igual en los dos sitios.
    function colorPrioridad(p) {
        switch (p) {
        case "maxima":
            return Theme.prioMaxima;
        case "alta":
            return Theme.prioAlta;
        case "media":
            return Theme.prioMedia;
        case "baja":
            return Theme.prioBaja;
        case "pausa":
            return Theme.prioPausa;
        default:
            return Theme.prioMinima;
        }
    }

    // La semana ISO, la misma que usan las revisiones del vault.
    function semana(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const dia = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - dia);
        const inicio = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - inicio) / 86400000 + 1) / 7);
    }

    function hoy() {
        const d = new Date();
        return Qt.locale("es_ES").toString(d, "dddd d 'de' MMMM") + " · semana " + contenido.semana(d);
    }

    // Lo que el cajón aún no tiene, en la web, que ya pide la contraseña en el
    // navegador.
    function abrirEnLaWeb() {
        Quickshell.execDetached(["xdg-open", "https://panel.lab.ishimi.es/" + contenido.actual.web]);
        if (!contenido.shell.fijado)
            contenido.shell.abierto = false;
    }

    // --- Piezas -------------------------------------------------------------

    // Un botón de icono de la cabecera: el glifo atenuado y, al pasar el ratón,
    // la lámina blanca de siempre debajo.
    component Icono: Rectangle {
        id: icono

        property string glifo: ""
        property bool activo: false
        signal activado

        implicitWidth: 28
        implicitHeight: 28
        radius: 8
        color: icono.activo ? Qt.rgba(1, 1, 1, 0.14) : (sobreIcono.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        border.width: icono.activo ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.22)

        Text {
            anchors.centerIn: parent
            text: icono.glifo
            color: icono.activo || sobreIcono.hovered ? Theme.strong : Theme.muted
            font.family: Theme.font
            font.pixelSize: 13
        }

        HoverHandler {
            id: sobreIcono
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: icono.activado()
        }
    }

    // El título pequeño de cada bloque, en mayúsculas y atenuado.
    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.pad
        spacing: Theme.gap

        // --- La tira de secciones ---
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: 6

            Repeater {
                model: contenido.secciones

                delegate: Rectangle {
                    id: boton

                    required property var modelData
                    readonly property bool elegida: contenido.seccion === boton.modelData.id

                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 10
                    color: boton.elegida ? Qt.rgba(1, 1, 1, 0.14) : (sobreBoton.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                    border.width: boton.elegida ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.22)

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: boton.modelData.icono
                        color: boton.elegida ? Theme.strong : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    HoverHandler {
                        id: sobreBoton
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: contenido.seccion = boton.modelData.id
                    }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Theme.rule
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14

            // --- La cabecera ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: contenido.actual.nombre
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 15
                    }

                    Text {
                        text: "datos de prueba · fase 1"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Icono {
                    glifo: ""
                    onActivado: contenido.abrirEnLaWeb()
                }

                Icono {
                    glifo: ""
                    activo: contenido.shell.fijado
                    onActivado: contenido.shell.fijado = !contenido.shell.fijado
                }

                Icono {
                    glifo: ""
                    onActivado: contenido.shell.abierto = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.rule
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: contenido.seccion === "inicio" ? inicio : pronto
            }
        }
    }

    // --- Inicio, de prueba ---
    Component {
        id: inicio

        ColumnLayout {
            spacing: 18

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7

                Etiqueta {
                    text: "DÓNDE ESTÁS"
                }

                Text {
                    text: contenido.hoy()
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                RowLayout {
                    spacing: 8

                    Rectangle {
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: 3
                        color: contenido.colorEstado
                    }

                    Text {
                        text: contenido.prueba.servidor
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                // Sólo el porcentaje, como el mosaico de la web (F12).
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Meta"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Rectangle {
                        id: barraMeta

                        Layout.fillWidth: true
                        implicitHeight: 4
                        radius: 2
                        color: Theme.rule

                        Rectangle {
                            width: barraMeta.width * contenido.prueba.meta / 100
                            height: parent.height
                            radius: 2
                            color: Theme.text
                        }
                    }

                    Text {
                        text: contenido.prueba.meta + " %"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Etiqueta {
                    text: "AHORA"
                }

                Repeater {
                    model: contenido.prueba.ahora

                    delegate: Rectangle {
                        id: tarjeta

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 56
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Theme.rule

                        // La barra de la prioridad, a la izquierda, como en la web.
                        Rectangle {
                            id: barra

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: parent.height - 22
                            radius: 1.5
                            color: contenido.colorPrioridad(tarjeta.modelData.prioridad)
                        }

                        ColumnLayout {
                            anchors.left: barra.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: tarjeta.modelData.texto
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                spacing: 6

                                // El cuadrado del proyecto, con su color, o sólo
                                // el borde si no tiene (como en la web).
                                Rectangle {
                                    implicitWidth: 8
                                    implicitHeight: 8
                                    radius: 2
                                    color: tarjeta.modelData.color || "transparent"
                                    border.width: tarjeta.modelData.color ? 0 : 1
                                    border.color: Theme.muted
                                }

                                Text {
                                    text: tarjeta.modelData.seccion + " · " + tarjeta.modelData.cuando
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Text {
                Layout.fillWidth: true
                text: "Todo esto es de prueba. Desde la fase 2 sale del panel del NUC."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }
    }

    // --- Lo que todavía no está ---
    Component {
        id: pronto

        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: contenido.actual.icono
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 28
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Llega en la fase " + contenido.actual.fase + " del plan"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Mientras tanto, en la web"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.underline: sobreWeb.hovered

                    HoverHandler {
                        id: sobreWeb
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: contenido.abrirEnLaWeb()
                    }
                }
            }
        }
    }
}
