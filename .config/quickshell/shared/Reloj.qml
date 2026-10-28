pragma Singleton
import QtQuick

// El reloj único de los esqueletos de carga (Esqueleto.qml): un solo Timer
// para todos, que sólo corre mientras algún esqueleto lo pide (`usuarios` > 0).
// Máximo ~24 fps (cada 42 ms). `t` son los segundos desde que arrancó y
// `ticks` cuenta los avisos (para medir).
Item {
    id: reloj

    property int usuarios: 0
    property real t: 0
    property int ticks: 0
    readonly property int intervalo: 42
    readonly property bool corriendo: reloj.usuarios > 0
    property double inicio: 0

    function pedir(): void {
        reloj.usuarios++;
    }
    function soltar(): void {
        reloj.usuarios = Math.max(0, reloj.usuarios - 1);
    }

    Timer {
        interval: reloj.intervalo
        repeat: true
        running: reloj.corriendo
        triggeredOnStart: true
        onRunningChanged: if (running)
            reloj.inicio = Date.now()
        onTriggered: {
            reloj.t = (Date.now() - reloj.inicio) / 1000;
            reloj.ticks++;
        }
    }
}
