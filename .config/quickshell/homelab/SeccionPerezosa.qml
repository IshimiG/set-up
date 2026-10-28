import QtQuick

// Una sección del cajón que sólo existe mientras hace falta.
//
// - Se crea (Loader) la primera vez que es la actual, y no antes.
// - Al dejarla, sigue viva `retardoDescarga` ms por si se vuelve enseguida (sin
//   recargar, con su scroll y lo que tuviera abierto) y luego se descarga. Si
//   `conservar` está a true (un borrador, un editor abierto) no se descarga
//   mientras tanto. Los datos viven en Api.qml, no aquí.
// - Mientras está escondida y viva no sigue el ancho del cajón (así no
//   recalcula nada por cada pulsación de «ancho»).
// - Si carga (o espera sus datos: `esperando`) más de `retardoEsqueleto` ms se
//   pinta un Esqueleto en su sitio; si es más rápido no se ve nada (sin parpadeo).
//
// `cargada(item)` salta con la sección creada y antes de que se vea, para
// dejarle encargos (Contenido.verEnRegistro, abrirNota).
Item {
    id: raiz

    // El Component de la sección.
    property Component componente: null
    // Es la sección que se está mirando.
    property bool actual: false
    // Está creada pero aún sin datos (Contenido lo calcula con la API).
    property bool esperando: false
    // No descargar aún (borradores, editores abiertos).
    property bool conservar: false
    property string variante: "filas"
    property int retardoDescarga: 45000
    property int retardoEsqueleto: 150
    // Tope del esqueleto «esperando datos», por si los datos no llegan nunca.
    property int maxEsperando: 8000
    property bool asincrono: true

    // Creada o por crear (Loader.active).
    property bool viva: false
    // La sección ya creada y entregada (cargada() ya salió).
    property bool lista: false
    readonly property var item: cargador.item
    readonly property int estado: cargador.status
    readonly property bool esqueletoVisible: esqueleto.visible

    // Está cargando, o creada y esperando sus datos.
    readonly property bool pendiente: raiz.viva && raiz.actual && (cargador.status === Loader.Loading || (raiz.esperando && raiz.lista))

    property bool lento: false
    property bool vencido: false

    signal cargada(var item)

    visible: raiz.actual

    onActualChanged: {
        if (raiz.actual) {
            descarga.stop();
            raiz.viva = true;
        } else if (raiz.viva) {
            descarga.restart();
        }
    }
    Component.onCompleted: if (raiz.actual)
        raiz.viva = true

    // Escondida, se queda con el tamaño que tenía.
    Binding {
        target: raiz
        property: "width"
        value: raiz.parent ? raiz.parent.width : 0
        when: raiz.actual
    }
    Binding {
        target: raiz
        property: "height"
        value: raiz.parent ? raiz.parent.height : 0
        when: raiz.actual
    }

    Timer {
        id: descarga

        interval: raiz.retardoDescarga
        onTriggered: {
            if (raiz.actual)
                return;
            if (raiz.conservar)
                descarga.restart();
            else
                raiz.viva = false;
        }
    }

    onListaChanged: if (raiz.lista && raiz.lento)
        tope.restart()

    onPendienteChanged: {
        if (raiz.pendiente) {
            retraso.restart();
        } else {
            retraso.stop();
            tope.stop();
            raiz.lento = false;
            raiz.vencido = false;
        }
    }

    Timer {
        id: retraso

        interval: raiz.retardoEsqueleto
        onTriggered: {
            raiz.lento = true;
            if (cargador.status !== Loader.Loading)
                tope.restart();
        }
    }
    Timer {
        id: tope

        interval: raiz.maxEsperando
        onTriggered: raiz.vencido = true
    }

    Loader {
        id: cargador

        objectName: "cargadorSeccion"
        width: raiz.width
        height: raiz.height
        active: raiz.viva
        asynchronous: raiz.asincrono
        sourceComponent: raiz.componente
        visible: raiz.actual && raiz.lista
        // Bajo el esqueleto no se ve (y sigue creada, para recibir los datos).
        opacity: esqueleto.visible ? 0 : 1

        onLoaded: {
            raiz.cargada(cargador.item);
            raiz.lista = true;
        }
        onItemChanged: if (!cargador.item)
            raiz.lista = false
    }

    Esqueleto {
        id: esqueleto

        objectName: "esqueleto"
        anchors.fill: parent
        variante: raiz.variante
        visible: raiz.actual && raiz.lento && !raiz.vencido
    }
}
