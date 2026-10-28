import QtQuick
import "shared"

// El cajón y su asa: todo lo que se mueve.
//
// Es un Item y no una ventana para poder cargarlo también en una prueba sin
// pantalla (un PanelWindow no arranca sin compositor). Borde.qml lo mete en la
// superficie y saca la máscara de entrada de lo que esto dice.
//
// Todo cuelga de un número, «progreso»: 0 escondido, 1 abierto. Mientras se
// arrastra lo pone el ratón; al soltar, una animación lo lleva al 0 o al 1. Así
// el arrastre y la animación son el mismo movimiento, y soltar a medias sigue
// desde donde se quedó en vez de dar un salto.
Item {
    id: cajon

    required property var shell

    // --- Medidas ------------------------------------------------------------
    // El ancho se puede cambiar (SUPER+' / SUPER+¡, IPC, o tirando del canto
    // izquierdo) entre el 15 % y el 100 % de la pantalla. 460 px, el de siempre,
    // caben en el portátil (1440 lógicos a escala 2) y es el de la primera vez.
    //
    // «anchoMeta» es lo que se pide; «anchoAnim» lo persigue con un muelle (rebota
    // pasándose un poco en los dos sentidos); «ancho» es lo que se ve, en px.
    // El ancho del monitor; Borde lo pone. (Sin él vale lo que mida el Item, para la
    // prueba sin pantalla.)
    property real anchoPantalla: cajon.width
    readonly property int anchoDefecto: 460
    property real anchoMeta: cajon.anchoDefecto
    property real anchoAnim: cajon.anchoDefecto
    readonly property int ancho: Math.round(cajon.anchoAnim)
    // El mínimo es el 15 % de la pantalla, con un suelo de 320 px (por debajo el
    // contenido no cabe). El máximo deja el margen derecho: «hasta el final».
    readonly property int anchoMin: Math.max(320, Math.round(cajon.anchoPantalla * 0.15))
    readonly property int anchoMax: Math.max(cajon.anchoMin, cajon.anchoPantalla - 2 * cajon.margen)
    // Para las vistas: compacto (<600), medio (600-1000) o amplio (>=1000). Va por
    // la meta y no por lo que se ve, para que no cambie de disposición a cada
    // fotograma del muelle.
    readonly property string modo: cajon.anchoMeta < 600 ? "compacto" : (cajon.anchoMeta < 1000 ? "medio" : "amplio")
    property bool redimensionando: false

    function limitar(n) {
        return Math.max(cajon.anchoMin, Math.min(cajon.anchoMax, Math.round(n)));
    }

    // Cambia el ancho en píxeles (con el muelle). Lo llaman el IPC y las teclas.
    function cambiarAncho(delta) {
        cajon.anchoMeta = cajon.limitar(cajon.anchoMeta + delta);
        cajon.guardarAncho();
    }

    function fijarAncho(n) {
        cajon.anchoMeta = cajon.limitar(n);
        cajon.guardarAncho();
    }

    function guardarAncho() {
        if (cajon.estadoAncho)
            cajon.estadoAncho.guardar(cajon.anchoMeta);
    }

    property var estadoAncho: estadoAnchoObj

    CajonEstado {
        id: estadoAnchoObj

        onLeido: n => {
            if (n > 0)
                cajon.anchoMeta = cajon.limitar(n);
        }
    }

    // Si la pantalla cambia (otro monitor), el ancho guardado se reajusta.
    onAnchoMinChanged: cajon.anchoMeta = cajon.limitar(cajon.anchoMeta)
    onAnchoMaxChanged: cajon.anchoMeta = cajon.limitar(cajon.anchoMeta)

    onAnchoMetaChanged: {
        if (cajon.redimensionando)
            cajon.anchoAnim = cajon.anchoMeta;
        else
            muelle.restart();
    }

    // El muelle: elástico en ambos sentidos, como el resto del escritorio.
    SpringAnimation {
        id: muelle

        target: cajon
        property: "anchoAnim"
        to: cajon.anchoMeta
        spring: 3.2
        damping: 0.22
        epsilon: 0.4
    }
    // Cuelga como los paneles de la barra: por debajo de ella y a un dedo de
    // los bordes.
    readonly property int margen: Theme.dropSide
    readonly property int arriba: Theme.dropTop
    readonly property int abajo: Theme.dropSide

    readonly property int asaAncho: 8
    readonly property int asaAlto: 96
    // Entre el asa y el cajón abierto.
    readonly property int asaHueco: 6
    // Cuánto sale el asa del borde al asomar: su ancho y un poco de aire.
    readonly property int asomaPx: cajon.asaAncho + 3

    // El centro del borde, el tercio del medio de la altura (decisión E3): sólo
    // ahí asoma el asa. Arriba queda la telemetría de la barra.
    readonly property int bandaAlto: Math.round(cajon.height / 3)
    readonly property int bandaY: Math.round((cajon.height - cajon.bandaAlto) / 2)
    readonly property int anchoFranja: 3
    readonly property int anchoZonaAsa: 28

    // Lo que viaja el cajón de escondido a abierto: hasta que el asa queda justo
    // fuera de la pantalla.
    readonly property int recorrido: cajon.margen + cajon.ancho + cajon.asaHueco + cajon.asaAncho
    // Lo mismo con el ancho pedido, para la máscara de entrada (no sigue al muelle).
    readonly property int recorridoMeta: cajon.margen + Math.max(cajon.anchoMeta, cajon.ancho) + cajon.asaHueco + cajon.asaAncho
    // La superficie mide lo que la pantalla: el cajón puede llegar a cualquier
    // ancho sin que el compositor la redimensione a cada fotograma. Lo que deja
    // pasar los clics de lo que no es cajón es la máscara.
    readonly property int anchoSuperficie: cajon.anchoMax + 2 * cajon.margen
    // Dónde empieza, abierto, lo que tiene que recibir el ratón: el asa con su
    // zona de agarre.
    readonly property int xZonaAbierta: Math.max(0, cajon.width - cajon.recorridoMeta - 10)

    // --- Estado -------------------------------------------------------------
    property real progreso: 0
    property bool arrastrando: false
    // El asa asomando: el ratón se ha parado en el centro del borde.
    property bool asoma: false

    // Mientras sea true, la superficie deja entrar el ratón en todo el cajón
    // (Borde.qml): también mientras termina de irse.
    readonly property bool enJuego: cajon.shell.abierto || cajon.arrastrando || asentando.running || cajon.progreso > 0.001

    // Cuánto ha salido el asa ahora mismo (entre 0 y asomaPx) y su escala:
    // al asomar crece con el respingo de lo que entra.
    property real asomaVisible: 0
    property real asaEscala: 0.7

    readonly property bool asaFuera: cajon.asoma || cajon.shell.abierto || cajon.arrastrando

    // El borde izquierdo del cajón. Con progreso 0 el asa queda justo fuera de
    // la pantalla, o asomando lo que diga asomaVisible; con 1, el cajón está en
    // su sitio. Por encima de 1 (el rebote, o tirar de más) entra un poco más.
    readonly property real xCajon: cajon.width - cajon.margen - cajon.ancho + (1 - cajon.progreso) * (cajon.recorrido - cajon.asomaVisible)

    // --- Asomar -------------------------------------------------------------
    // Un HoverHandler en la raíz y no un MouseArea en la franja: el MouseArea
    // del asa, encima, le quitaría el hover a un hermano de debajo (la nota del
    // escritorio cuenta el parpadeo que eso dio en el panel de la wifi). Un
    // antepasado sigue viendo el ratón.
    HoverHandler {
        id: raton
    }

    // El ratón en la franja del centro del borde. Con la máscara de Borde.qml
    // no puede estar en otro sitio mientras el cajón está escondido, pero se
    // mira igual: así la prueba sin pantalla, que no tiene máscara, prueba lo
    // mismo.
    readonly property bool enFranja: raton.hovered && raton.point.position.x >= cajon.width - cajon.anchoFranja - 1 && raton.point.position.y >= cajon.bandaY && raton.point.position.y <= cajon.bandaY + cajon.bandaAlto

    // Hay que pararse un momento: pasar por el borde de camino a otra cosa no
    // saca nada.
    onEnFranjaChanged: {
        if (cajon.enFranja && !cajon.asoma && !cajon.shell.abierto)
            espera.restart();
        else if (!cajon.enFranja)
            espera.stop();
    }

    Timer {
        id: espera
        interval: 120
        onTriggered: cajon.asoma = true
    }

    // Se recoge un rato después de que el ratón se vaya, no al instante:
    // salirse un píxel de camino al asa no la tiene que esconder.
    Connections {
        target: raton

        function onHoveredChanged() {
            if (raton.hovered)
                retirar.stop();
            else
                retirar.restart();
        }
    }

    Timer {
        id: retirar
        interval: 500
        onTriggered: if (!raton.hovered && !cajon.arrastrando && !cajon.shell.abierto)
            cajon.asoma = false
    }

    onAsaFueraChanged: {
        sacarAsa.fuera = cajon.asaFuera;
        sacarAsa.restart();
    }

    // Lo que aparece rebota al llegar y lo que se va sale liso, como en el resto
    // del escritorio. Las curvas van atadas a «fuera», que se pone antes de
    // arrancar: así ya están al día cuando la animación las lee.
    ParallelAnimation {
        id: sacarAsa

        property bool fuera: false

        NumberAnimation {
            target: cajon
            property: "asomaVisible"
            to: sacarAsa.fuera ? cajon.asomaPx : 0
            duration: sacarAsa.fuera ? 320 : 220
            easing.type: sacarAsa.fuera ? Easing.OutBack : Easing.InOutQuint
            easing.overshoot: Theme.overshootIn
        }
        NumberAnimation {
            target: cajon
            property: "asaEscala"
            to: sacarAsa.fuera ? 1 : 0.7
            duration: sacarAsa.fuera ? 320 : 220
            easing.type: sacarAsa.fuera ? Easing.OutBack : Easing.InOutQuint
            easing.overshoot: Theme.overshootIn
        }
    }

    // --- Arrastrar ----------------------------------------------------------
    property real xInicio: 0
    property real pInicio: 0
    // Lo más que se ha separado el ratón de donde se pulsó: por debajo de 4 px,
    // soltar es un clic.
    property real movido: 0
    // Las últimas posiciones con su hora, para saber a qué velocidad iba al
    // soltar.
    property var muestras: []
    // Si lo último fue un arrastre: cerrar después de soltar sigue el gesto en
    // vez de tomar carrerilla.
    property bool trasArrastre: false

    function empezar(x) {
        asentando.stop();
        cajon.arrastrando = true;
        cajon.xInicio = x;
        cajon.pInicio = cajon.progreso;
        cajon.movido = 0;
        cajon.muestras = [
            {
                x: x,
                t: Date.now()
            }
        ];
    }

    // Tirar de más cede como una goma, y nunca más que el aire que tiene la
    // superficie para el rebote.
    function estirar(p) {
        if (p <= 1)
            return Math.max(0, p);
        return Math.min(1.06, 1 + (p - 1) * 0.3);
    }

    function mover(x) {
        const dx = cajon.xInicio - x;
        const ahora = Date.now();
        cajon.movido = Math.max(cajon.movido, Math.abs(dx));
        cajon.progreso = cajon.estirar(cajon.pInicio + dx / cajon.recorrido);
        cajon.muestras = cajon.muestras.concat([
            {
                x: x,
                t: ahora
            }
        ]).filter(m => ahora - m.t <= 100);
    }

    // Hacia dónde iba al soltar, en píxeles por milisegundo, contando sólo los
    // últimos 100 ms: si se para antes de soltar, la velocidad es cero y manda
    // la posición. Positivo es hacia dentro de la pantalla (abrir).
    function velocidad() {
        const ahora = Date.now();
        const m = cajon.muestras.filter(s => ahora - s.t <= 100);
        if (m.length < 2)
            return 0;
        const dt = m[m.length - 1].t - m[0].t;
        return dt > 0 ? (m[0].x - m[m.length - 1].x) / dt : 0;
    }

    function soltar(esRueda) {
        if (!cajon.arrastrando)
            return;
        cajon.arrastrando = false;
        let abrir;
        if (cajon.movido < 4) {
            // Un clic en el asa abre, o cierra si ya estaba abierto. Un roce de
            // la rueda no hace nada.
            abrir = esRueda ? cajon.shell.abierto : !cajon.shell.abierto;
        } else {
            cajon.trasArrastre = true;
            const v = cajon.velocidad();
            if (v > 0.6)
                abrir = true;
            else if (v < -0.6)
                abrir = false;
            // Despacio, decide hasta dónde ha llegado: con un tercio del camino
            // basta, en los dos sentidos.
            else
                abrir = cajon.shell.abierto ? cajon.progreso > 2 / 3 : cajon.progreso > 1 / 3;
        }
        if (cajon.shell.abierto === abrir)
            cajon.asentar();
        else
            cajon.shell.abierto = abrir;
    }

    // --- Asentarse ----------------------------------------------------------
    // Al soltar, o al cambiar «abierto» desde fuera (SUPER+H, Escape, clic
    // fuera), el cajón va a su sitio desde donde esté. Abrir rebota una vez,
    // como la isla (el mismo 1.4: se pasa un 5 %). Cerrar con el teclado toma
    // carrerilla (InBack, Theme.qml); cerrar después de arrastrarlo continúa el
    // gesto, sin echarse atrás.
    property int curva: Easing.OutBack
    property real rebote: 1.4
    property int duracion: Theme.animIn

    function asentar() {
        const abrir = cajon.shell.abierto;
        asentando.stop();
        cajon.curva = abrir ? Easing.OutBack : (cajon.trasArrastre ? Easing.OutCubic : Easing.InBack);
        cajon.rebote = abrir ? 1.4 : Theme.overshootOut;
        cajon.duracion = abrir ? Theme.animIn : Theme.animOut;
        cajon.trasArrastre = false;
        asentando.from = cajon.progreso;
        asentando.to = abrir ? 1 : 0;
        asentando.start();
    }

    NumberAnimation {
        id: asentando

        target: cajon
        property: "progreso"
        duration: cajon.duracion
        easing.type: cajon.curva
        easing.overshoot: cajon.rebote

        onFinished: if (!cajon.shell.abierto && !raton.hovered)
            cajon.asoma = false
    }

    Connections {
        target: cajon.shell

        function onAbiertoChanged() {
            cajon.asentar();
            cajon.alAbrir();
        }
    }

    // Al abrir se ponen al día los datos (y se reconecta ya, si estaban
    // cortados), no antes: sin sondeos. Va aquí y no en shell.qml para que la
    // prueba, que carga este fichero con un shell falso, lo ejercite.
    function alAbrir() {
        if (cajon.shell.abierto && cajon.shell.api)
            cajon.shell.api.refrescar();
    }

    Component.onCompleted: {
        if (cajon.shell.abierto)
            cajon.asentar();
        cajon.alAbrir();
    }

    // --- El cajón -----------------------------------------------------------
    // La capa exterior es sólo el canto, con el cuerpo de cristal encima dejando
    // 1 px al aire: la única forma de tener un borde con degradado en QML, como
    // en la isla.
    Rectangle {
        id: canto

        x: cajon.xCajon
        y: cajon.arriba
        width: cajon.ancho
        height: cajon.height - cajon.arriba - cajon.abajo
        radius: Theme.radius
        // Escondido del todo no se pinta: está fuera de la pantalla.
        visible: cajon.progreso > 0.001 || cajon.arrastrando

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.edgeTop
            }
            GradientStop {
                position: 1.0
                color: Theme.edgeBottom
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, canto.radius - 1)

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.glassTop
                }
                GradientStop {
                    position: 1.0
                    color: Theme.glassBottom
                }
            }
        }

        Contenido {
            id: contenido

            anchors.fill: parent
            anchors.margins: 1
            shell: cajon.shell
            modo: cajon.modo
            desplegado: cajon.shell.abierto && !cajon.arrastrando && cajon.progreso > 0.98
        }
    }

    // --- Cambiar el ancho ---------------------------------------------------
    // Un canto en el borde izquierdo del cajón: tirando de él se ensancha o se
    // estrecha, siguiendo al ratón sin muelle; al soltar, si se ha pasado del
    // límite, vuelve con rebote. Doble clic: el ancho de siempre.
    // (SUPER+botón derecho no llega aquí: Hyprland se lo queda para las ventanas.)
    MouseArea {
        id: agarre

        property real xIni: 0
        property real anchoIni: 0

        x: cajon.xCajon - 3
        y: cajon.arriba + Theme.radius
        width: 10
        height: Math.max(0, cajon.height - cajon.arriba - cajon.abajo - 2 * Theme.radius)
        visible: cajon.progreso > 0.98
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.SizeHorCursor

        onPressed: m => {
            muelle.stop();
            cajon.redimensionando = true;
            agarre.xIni = agarre.mapToItem(cajon, m.x, 0).x;
            agarre.anchoIni = cajon.anchoMeta;
        }
        onPositionChanged: m => {
            if (!agarre.pressed)
                return;
            const x = agarre.mapToItem(cajon, m.x, 0).x;
            cajon.anchoMeta = cajon.limitar(agarre.anchoIni + (agarre.xIni - x));
        }
        onReleased: {
            cajon.redimensionando = false;
            cajon.guardarAncho();
        }
        onCanceled: cajon.redimensionando = false
        onDoubleClicked: cajon.fijarAncho(cajon.anchoDefecto)
    }

    // --- El asa -------------------------------------------------------------
    // Una pastilla de cristal pegada al lado izquierdo del cajón: asoma del
    // borde cuando está escondido y se queda junto a él cuando está abierto,
    // para poder devolverlo arrastrando hacia la derecha. El punto del centro
    // es el estado del NUC (verde, naranja o rojo).
    Rectangle {
        id: asa

        width: cajon.asaAncho
        height: Math.round(cajon.asaAlto * cajon.asaEscala)
        x: cajon.xCajon - cajon.asaHueco - cajon.asaAncho
        y: Math.round((cajon.height - asa.height) / 2)
        radius: width / 2
        visible: asa.x < cajon.width

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Theme.edgeTop
            }
            GradientStop {
                position: 1.0
                color: Theme.edgeBottom
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, asa.radius - 1)

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.glassTop
                }
                GradientStop {
                    position: 1.0
                    color: Theme.glassBottom
                }
            }
        }

        // Al pasar el ratón o al agarrarla, otra lámina de cristal encima: el
        // resalte de la casa es blanco, no un color.
        Rectangle {
            anchors.fill: parent
            radius: asa.radius
            color: Theme.accent
            opacity: areaAsa.containsMouse || cajon.arrastrando ? 0.18 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 4
            height: 4
            radius: 2
            objectName: "puntoAsa"
            color: contenido.colorEstado
        }
    }

    // La zona de agarre, más generosa que el asa: 8 px de ancho son poco para
    // acertar a la primera.
    MouseArea {
        id: areaAsa

        x: asa.x - 10
        y: asa.y - 20
        width: asa.width + 20
        height: asa.height + 40
        hoverEnabled: true
        preventStealing: true
        cursorShape: cajon.arrastrando ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        // La zona se mueve con el asa mientras se arrastra, así que la posición
        // se pasa siempre a las coordenadas del cajón, que no se mueven.
        // Agarrar el asa a mitad de un gesto de dos dedos se queda con el ratón.
        onPressed: m => {
            finRueda.stop();
            rueda.enCurso = false;
            cajon.empezar(areaAsa.mapToItem(cajon, m.x, m.y).x);
        }
        onPositionChanged: m => {
            if (areaAsa.pressed)
                cajon.mover(areaAsa.mapToItem(cajon, m.x, m.y).x);
        }
        onReleased: cajon.soltar(false)
        onCanceled: cajon.soltar(false)
    }

    // Dos dedos en el touchpad también lo mueven: el gesto empieza sobre el asa
    // (o en cualquier punto del cajón abierto) y sigue aunque el asa se vaya de
    // debajo del puntero, que es lo que pasa en cuanto el cajón se mueve; por
    // eso va en la raíz y no en la zona del asa.
    //
    // Va como un Flickable: el cajón sigue al desplazamiento tal cual llega, así
    // que con el desplazamiento natural del portátil (hyprland.lua) sigue a los
    // dedos. Una rueda no avisa de que se ha soltado, así que el gesto termina
    // cuando dejan de llegar eventos.
    //
    // Sin probar todavía con el touchpad de verdad: si va al revés, es el signo
    // de «acumulado».
    WheelHandler {
        id: rueda

        property real acumulado: 0
        property bool enCurso: false

        target: null
        // Por defecto un WheelHandler sólo atiende la rueda vertical.
        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.TouchPad | PointerDevice.Mouse

        onWheel: ev => {
            const dx = ev.pixelDelta.x !== 0 ? ev.pixelDelta.x : ev.angleDelta.x / 8;
            const dy = ev.pixelDelta.y !== 0 ? ev.pixelDelta.y : ev.angleDelta.y / 8;
            if (!rueda.enCurso) {
                // Sólo un gesto horizontal, y sólo donde tiene sentido empezarlo.
                if (Math.abs(dx) <= Math.abs(dy) || cajon.arrastrando)
                    return;
                if (!areaAsa.containsMouse && !cajon.shell.abierto)
                    return;
                cajon.empezar(0);
                rueda.acumulado = 0;
                rueda.enCurso = true;
            }
            rueda.acumulado -= dx;
            cajon.mover(-rueda.acumulado);
            finRueda.restart();
        }
    }

    Timer {
        id: finRueda
        interval: 150
        onTriggered: {
            rueda.enCurso = false;
            cajon.soltar(true);
        }
    }
}
