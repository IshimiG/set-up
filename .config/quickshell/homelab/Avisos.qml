import QtQuick
import Quickshell

// Las alertas nuevas del NUC, como notificación del escritorio (E12).
//
// Sale por el mismo notify-send que usa la barra para sus avisos. Nunca abre el
// cajón, y nunca lleva una cantidad de dinero (E11): sólo el título de la alerta
// y su detalle recortado. Está aparte de shell.qml para poder probarlo sin
// lanzar notificaciones de verdad: la prueba cambia «lanzar».
QtObject {
    id: avisos

    // El Api.qml del shell.
    property var api: null

    // Cuánto del detalle cabe en la notificación.
    property int maxDetalle: 160

    // Cómo se lanza la orden. La prueba lo sustituye por otra cosa.
    property var lanzar: args => Quickshell.execDetached(args)

    // La orden entera, como lista de argumentos.
    function argumentos(alerta) {
        let detalle = String(alerta.detalle || "").replace(/\s+/g, " ").trim();
        if (detalle.length > avisos.maxDetalle)
            detalle = detalle.substring(0, avisos.maxDetalle - 1).trimEnd() + "…";
        const orden = ["notify-send", "-a", "Homelab", "-u", alerta.nivel === "error" ? "critical" : "normal", String(alerta.titulo)];
        if (detalle !== "")
            orden.push(detalle);
        return orden;
    }

    property Connections conexion: Connections {
        target: avisos.api

        function onAlertaNueva(alerta) {
            avisos.lanzar(avisos.argumentos(alerta));
        }
    }
}
