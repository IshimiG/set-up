pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "shared"
import "shared/AgendaFormato.js" as Formato

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
//
// Con la agenda del panel del homelab (shell.agenda: las tareas con fecha de
// 00 Inicio y las entregas de Aules, lo mismo que va a Google Calendar), cada
// día con algo lleva puntos de colores, y debajo de la rejilla está la lista
// de hoy o del día que se pulse. Sin agenda, la rejilla sola.
//
// Nada de botones ni formularios a la vista: lo demás aparece al pedirlo.
//   - El mes y el año se eligen con las flechas de la cabecera o con el chip
//     del mes («Octubre 2026»), que abre un desplegable con el año arriba
//     (‹ › lo cambian) y los doce meses debajo. Se cierra al pulsar fuera.
//   - Con el panel del NUC al alcance (shell.tareas, bar/Tareas.qml, que es
//     quien escribe en él), las tareas se editan desde aquí:
//       · doble clic en un día abre en el sitio de la lista la hoja «Nueva
//         tarea» (bar/HojaTarea.qml): el título, todo el día o de una hora a
//         otra, el color, la prioridad (media) y el 🚫🤖 (apagado). Intro
//         guarda, Escape cancela. Con ella abierta, pulsar otro día la lleva
//         a ese día;
//       · pulsar el título de una tarea abre la misma hoja, «Editar tarea»,
//         con lo suyo, y guardar manda solo lo que ha cambiado. Pulsar un día
//         la cierra sin guardar;
//       · en la lista, una tarea con hora lleva su rango («09:00–10:00») en
//         vez del área, y una con color propio, una barrita de ese color;
//       · el punto de una tarea, pulsado, abre un menú con las cinco
//         prioridades;
//       · el 🚫🤖 del final de la fila («Claude no la hace») se enciende y se
//         apaga con un clic; apagado no se ve hasta pasar el ratón por ella;
//       · una tarea se arrastra a otro día de la rejilla y al soltarla cambia
//         su fecha. Si se arrastra sobre las flechas de la cabecera, el mes
//         pasa solo, para llevarla a otra semana o a otro mes.
//     Mover, la prioridad y el 🚫🤖 cambian la vista al momento; si el POST
//     falla, vuelven a como estaban y se avisa.
Item {
    id: root

    required property var shell

    // 320 y no 300: la cabecera (flechas, el chip de «Septiembre 2026» y
    // «hoy») y las filas con su 🚫🤖 no caben en 300. La isla toma este ancho
    // sola (panelW).
    implicitWidth: 320
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

    // Ir a un mes y un año concretos (mes de 0 a 11).
    function irA(anio, mes) {
        const n = root.shell.now;
        root.monthOffset = (anio - n.getFullYear()) * 12 + (mes - n.getMonth());
    }

    function mover(meses) {
        root.monthOffset += meses;
    }

    function mayus(t) {
        return t.charAt(0).toUpperCase() + t.slice(1);
    }

    // --- El desplegable de mes y año ------------------------------------------
    // Arriba el año, que ‹ › cambian sin moverse todavía de mes; debajo, los
    // doce meses: elegir uno lleva a ese mes de ese año y lo cierra.
    property bool selectorAbierto: false
    // El año que enseña el desplegable (al abrirlo, el que se está mirando).
    property int selectorAnio: 0

    function abrirSelector() {
        if (root.selectorAbierto) {
            root.cerrarSelector();
            return;
        }
        root.cerrarPrioridad();
        root.selectorAnio = root.shown.getFullYear();
        root.selectorAbierto = true;
    }

    function cerrarSelector() {
        root.selectorAbierto = false;
    }

    // --- Editar tareas ----------------------------------------------------------
    // El cliente del panel (bar/Tareas.qml); en las pruebas, uno falso o null.
    readonly property var tareas: root.shell.tareas ?? null
    readonly property bool puedeEscribir: root.tareas !== null && root.tareas.puedeEscribir
    // La tarea que se lleva en la mano (un evento de la agenda), o null.
    property var arrastrada: null
    // Lo que se dice tras escribir: «Movida al 24 oct», «Añadida al 30 oct»…
    // o por qué no pudo ser.
    property string aviso: ""

    // La hoja de una tarea (bar/HojaTarea.qml), una sola a la vez: "" sin
    // ella, "nueva" o "editar".
    property string hojaModo: ""
    // Su día ("2026-10-30").
    property string hojaDia: ""
    // La tarea que se edita (el evento, tal como era al abrir la hoja), o null.
    property var hojaTarea: null
    // Con qué se abre (HojaTarea.inicial), para saber al guardar qué cambió.
    property var hojaInicial: null
    // Esperando al panel.
    property bool guardando: false
    // Lo que contestó el panel al no aceptarla.
    property string hojaError: ""
    // Cuenta las hojas abiertas y cerradas: lo que el panel contesta tarde,
    // con la hoja ya cerrada, va al aviso de la lista y no a otra hoja.
    property int hojaVez: 0
    // Quien tenía el teclado al abrir la hoja (la isla, que cierra con
    // Escape): se le devuelve al cerrarla.
    property Item tecladoAntes: null

    // La prioridad: la tarea cuyo menú está abierto (un evento), o null.
    property var menuDe: null

    // Las del panel, de la más alta a la más baja, con el nombre de su color
    // (Theme.colorPrioridad) y lo que se lee en el menú.
    readonly property var prioridades: [
        {
            valor: "highest",
            nombre: "maxima",
            etiqueta: "Máxima"
        },
        {
            valor: "high",
            nombre: "alta",
            etiqueta: "Alta"
        },
        {
            valor: "medium",
            nombre: "media",
            etiqueta: "Media"
        },
        {
            valor: "low",
            nombre: "baja",
            etiqueta: "Baja"
        },
        {
            valor: "lowest",
            nombre: "minima",
            etiqueta: "Mínima"
        }
    ]

    // Con la hoja de una nueva abierta, el día que se mira es el suyo; la de
    // editar se cierra si se mira otro.
    onDiaVistoChanged: {
        if (root.hojaModo === "nueva")
            root.hojaDia = root.diaVisto;
        else if (root.hojaModo === "editar")
            root.cerrarHoja();
    }

    // La prioridad del panel ("high") de su nombre ("alta"); "" sin ella.
    function valorDe(nombre) {
        const p = root.prioridades.find(x => x.nombre === nombre);
        return p ? p.valor : "";
    }

    // Doble clic en un día: la hoja de una tarea nueva para él. Si ya está
    // abierta, solo cambia de día (lo tecleado se queda).
    function abrirNueva(dia) {
        if (!root.puedeEscribir)
            return;
        root.cerrarSelector();
        root.cerrarPrioridad();
        root.elegido = dia === root.hoy ? "" : dia;
        if (root.hojaModo === "nueva") {
            root.hojaDia = dia;
            return;
        }
        root.abrirHoja("nueva", dia, null, {
            texto: "",
            horaInicio: "",
            horaFin: "",
            color: "",
            prioridad: "medium",
            claudeOff: false
        });
    }

    // El título de una tarea, pulsado: la hoja para editarla, con lo suyo.
    function abrirEdicion(e) {
        if (!root.puedeEscribir || !e || e.id === "")
            return;
        root.cerrarSelector();
        root.cerrarPrioridad();
        const conHora = !e.todoElDia && e.hora !== "";
        root.abrirHoja("editar", e.dia, e, {
            texto: e.texto || e.titulo,
            horaInicio: conHora ? e.hora : "",
            horaFin: conHora ? (e.horaFin || Formato.sumarMinutos(e.hora, 60)) : "",
            color: e.colorPropio || "",
            prioridad: root.valorDe(e.prioridadPropia),
            claudeOff: e.claudeOff === true
        });
    }

    function abrirHoja(modo, dia, tarea, inicial) {
        // Una sola: la que hubiera se va sin guardar.
        root.cerrarHoja();
        root.hojaVez++;
        root.hojaError = "";
        root.guardando = false;
        root.hojaInicial = inicial;
        root.hojaTarea = tarea;
        root.hojaDia = dia;
        root.hojaModo = modo;
    }

    function cerrarHoja() {
        if (root.hojaModo === "")
            return;
        root.hojaVez++;
        if (root.tecladoAntes)
            root.tecladoAntes.forceActiveFocus();
        root.tecladoAntes = null;
        root.hojaModo = "";
        root.hojaTarea = null;
        root.hojaInicial = null;
        root.guardando = false;
        root.hojaError = "";
    }

    // Lo que ha cambiado entre lo que tenía la hoja al abrirse y lo que se
    // guarda (los nombres de Tareas.cambiar). Las horas van juntas.
    function cambiosDe(ini, v) {
        const c = {};
        const plano = t => String(t || "").replace(/\s+/g, " ").trim();
        if (plano(v.texto) !== plano(ini.texto))
            c.texto = v.texto;
        if (v.horaInicio !== ini.horaInicio || v.horaFin !== ini.horaFin) {
            c.horaInicio = v.horaInicio;
            c.horaFin = v.horaFin;
        }
        if (v.color !== ini.color)
            c.color = v.color;
        if (v.prioridad !== ini.prioridad)
            c.prioridad = v.prioridad;
        if (v.claudeOff !== ini.claudeOff)
            c.claudeOff = v.claudeOff;
        return c;
    }

    // Guardar en la hoja. Una nueva se crea (no es optimista: sale al
    // contestar el panel, ya con su id); una editada manda solo lo que
    // cambió, y si no cambió nada, solo se cierra. Si el panel no la acepta,
    // la hoja se queda abierta, con lo tecleado y lo que ha dicho.
    function guardarHoja(v) {
        const cli = root.tareas;
        if (!cli || root.guardando || root.hojaModo === "")
            return;
        const vez = root.hojaVez;
        const modo = root.hojaModo;
        const dia = root.hojaDia;
        const cambios = modo === "editar" ? root.cambiosDe(root.hojaInicial, v) : null;
        if (cambios !== null && Object.keys(cambios).length === 0) {
            root.cerrarHoja();
            return;
        }
        root.hojaError = "";
        root.guardando = true;
        const alAcabar = ok => {
            const abierta = vez === root.hojaVez;
            if (abierta)
                root.guardando = false;
            if (!ok) {
                const motivo = cli.error || (modo === "nueva" ? "No se pudo crear la tarea" : "No se pudo guardar la tarea");
                if (abierta)
                    root.hojaError = motivo;
                else
                    root.avisar(motivo);
                return;
            }
            if (abierta)
                root.cerrarHoja();
            root.avisar(modo === "nueva" ? "Añadida al " + Formato.diaCorto(dia) : "Guardada");
        };
        if (modo === "nueva")
            cli.crear(Object.assign({
                dia: dia
            }, v), alAcabar);
        else
            cli.cambiar(root.hojaTarea.id, cambios, alAcabar);
    }

    // El menú sale debajo del punto si cabe y, si no (lo normal, porque la
    // lista va al final de la isla), encima de la fila.
    function abrirPrioridad(evento, punto) {
        if (!root.puedeEscribir)
            return;
        if (root.menuDe !== null && root.menuDe.id === evento.id) {
            root.cerrarPrioridad();
            return;
        }
        root.cerrarSelector();
        const q = punto.mapToItem(root, 0, 0);
        const abajo = q.y + punto.height + 4;
        menuPrio.arriba = abajo + menuPrio.height > root.height - 6;
        menuPrio.y = menuPrio.arriba ? q.y - menuPrio.height - 4 : abajo;
        menuPrio.x = Math.min(Math.max(Theme.pad - 6, q.x - 6), root.width - menuPrio.width - 6);
        menuPrio.de = evento;
        root.menuDe = evento;
    }

    function cerrarPrioridad() {
        root.menuDe = null;
    }

    function elegirPrioridad(p) {
        const t = root.menuDe;
        root.cerrarPrioridad();
        if (!t || !root.tareas || p.nombre === t.prioridadPropia)
            return;
        const cli = root.tareas;
        cli.prioridad(t.id, p.valor, ok => {
            root.avisar(ok ? "Prioridad " + p.etiqueta.toLowerCase() : (cli.error || "No se pudo cambiar la prioridad"));
        });
    }

    function cambiarClaudeOff(evento) {
        if (!root.puedeEscribir)
            return;
        const cli = root.tareas;
        const activo = evento.claudeOff !== true;
        cli.claudeOff(evento.id, activo, ok => {
            root.avisar(ok ? (activo ? "Claude no la hará" : "Claude ya puede hacerla") : (cli.error || "No se pudo cambiar «Claude no la hace»"));
        });
    }

    function avisar(texto) {
        root.aviso = texto;
        avisoReloj.restart();
    }

    // `escena`, dónde está el puntero (en la escena): el fantasma se pone
    // ahí antes de echar a andar, para que el primer DropArea que se entere
    // sea el de debajo del puntero y no el del sitio donde acabó el anterior.
    function empezarArrastre(evento, escena) {
        root.arrastrada = evento;
        ghost.titulo = evento.titulo;
        ghost.punto = root.colorTipo(Formato.tipo(evento, root.hoy));
        root.seguirArrastre(escena);
        ghost.Drag.active = true;
    }

    // El fantasma va encima del puntero y no debajo, para no tapar el día
    // sobre el que se va a soltar, que es el que se resalta; arriba del todo
    // (las flechas de la cabecera), por debajo de él, para que la isla no lo
    // recorte. Sin salirse por los lados. El punto caliente del arrastre, lo
    // que miran los DropArea, sigue siendo el puntero.
    function seguirArrastre(escena) {
        const q = root.mapFromItem(null, escena.x, escena.y);
        const x = Math.max(4, Math.min(root.width - ghost.width - 4, q.x - ghost.width / 2));
        const encima = q.y - ghost.height - 10;
        const y = encima >= 4 ? encima : q.y + 16;
        ghost.Drag.hotSpot = Qt.point(q.x - x, q.y - y);
        ghost.x = x;
        ghost.y = y;
    }

    // Suelta: el DropArea que haya debajo recibe onDropped (soltarEn) antes de
    // que esto siga; si no había ninguno, no pasa nada y la tarea se queda.
    function terminarArrastre() {
        if (ghost.Drag.active)
            ghost.Drag.drop();
        root.arrastrada = null;
    }

    function cancelarArrastre() {
        if (ghost.Drag.active)
            ghost.Drag.cancel();
        root.arrastrada = null;
    }

    function soltarEn(dia) {
        const t = root.arrastrada;
        if (!t || !root.tareas || dia === t.dia)
            return;
        root.tareas.mover(t.id, dia, ok => {
            root.avisar(ok ? "Movida al " + Formato.diaCorto(dia) : (root.tareas.error || "No se pudo mover la tarea"));
        });
    }

    // --- La agenda ----------------------------------------------------------
    // La lee bar/Agenda.qml de un fichero que deja el cajón del homelab; el
    // formato está en shared/AgendaFormato.js. null sin ella.
    readonly property var agenda: root.shell.agenda ?? null

    readonly property string hoy: Formato.claveDe(root.shell.now)

    // El día pulsado ("2026-10-23"), o "" para hoy.
    property string elegido: ""

    readonly property string diaVisto: root.elegido !== "" ? root.elegido : root.hoy

    // Lo de ese día, ordenado; el de hoy lleva delante lo vencido que sigue
    // sin hacer.
    readonly property var lista: Formato.delDia(root.agenda, root.diaVisto, root.hoy)

    // Las filas que caben; el resto se cuenta.
    readonly property int maxFilas: 6

    // Al cerrar la isla se vuelve al mes de hoy: si no, abrir el calendario
    // después de haber estado mirando marzo lo abre otra vez en marzo, que nunca
    // es lo que se quiere. Lo mismo con el día pulsado.
    Connections {
        target: root.shell
        function onModeChanged() {
            if (root.shell.mode !== "calendar") {
                root.monthOffset = 0;
                root.elegido = "";
                root.cerrarSelector();
                root.cerrarPrioridad();
                root.cerrarHoja();
                root.cancelarArrastre();
            } else if (root.tareas) {
                // Se lee al abrir (y solo si lo que hay es viejo), no se sondea.
                root.tareas.refrescar(false);
            }
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

    // Pulsar un día enseña lo suyo; pulsar otra vez el mismo, o hoy, vuelve a
    // hoy. Con la hoja de una nueva abierta, la lleva a ese día; la de editar
    // se cierra sin guardar.
    function elegir(dia) {
        if (root.hojaModo === "nueva") {
            root.elegido = dia === root.hoy ? "" : dia;
            root.hojaDia = dia;
            return;
        }
        root.cerrarHoja();
        root.elegido = dia === root.hoy || dia === root.elegido ? "" : dia;
    }

    function volverAHoy() {
        root.monthOffset = 0;
        root.elegido = "";
        root.cerrarSelector();
    }

    // El día a `n` días de hoy, como clave.
    function desdeHoy(n) {
        const d = new Date(root.shell.now);
        d.setDate(d.getDate() + n);
        return Formato.claveDe(d);
    }

    // «Hoy», «Mañana», «Ayer» o «Jueves 22 de octubre» (con el año si no es
    // este).
    function tituloDia(dia) {
        if (dia === root.hoy)
            return "Hoy";
        if (dia === root.desdeHoy(1))
            return "Mañana";
        if (dia === root.desdeHoy(-1))
            return "Ayer";
        const f = Formato.fechaDe(dia);
        if (!f)
            return "";
        const t = f.toLocaleDateString(root.loc, f.getFullYear() === root.shell.now.getFullYear() ? "dddd d 'de' MMMM" : "dddd d 'de' MMMM 'de' yyyy");
        return t.charAt(0).toUpperCase() + t.slice(1);
    }

    // El color de un punto o de una fila: lo vencido en el rojo de «máxima»,
    // como en el cajón; lo hecho, apagado; el resto, el de su prioridad.
    function colorTipo(tipo) {
        if (tipo === "vencida")
            return Theme.prioMaxima;
        if (tipo === "hecha")
            return Theme.faint;
        return Theme.colorPrioridad(tipo);
    }

    // Lo que va a la derecha de una fila: cuándo venció si es de otro día, la
    // hora si la tiene («09:00–10:00», o solo la de inicio si no tiene fin), y
    // si no, su área o su sección («Clase» en las entregas de Aules).
    function etiqueta(e) {
        if (e.deAntes)
            return "venció " + Formato.diaCorto(e.dia);
        if (Formato.tipo(e, root.hoy) === "vencida")
            return "vencida";
        if (!e.todoElDia && e.hora !== "")
            return e.hora + (e.horaFin ? "–" + e.horaFin : "");
        return e.area !== "" ? e.area : e.seccion;
    }

    // Un botón de texto de la cabecera (el mes y el año) con su flecha de
    // desplegable.
    component Chip: Rectangle {
        id: chip

        property string texto
        property bool abierto: false
        signal pulsado

        implicitWidth: etiquetaChip.implicitWidth + 16
        implicitHeight: 24
        radius: 8
        color: Qt.rgba(1, 1, 1, chip.abierto ? 0.14 : (chipHover.hovered ? 0.08 : 0))
        border.width: chip.abierto ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.2)

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Text {
            id: etiquetaChip

            anchors.centerIn: parent
            text: chip.texto + "  " + (chip.abierto ? "󰅃" : "󰅀")
            color: Theme.strong
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
        }

        HoverHandler {
            id: chipHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: chip.pulsado()
        }
    }

    // Una flecha de mes: pulsada cambia de mes; con una tarea encima, lo
    // cambia sola cada medio segundo.
    component Flecha: Rectangle {
        id: flecha

        property string texto
        property int paso: 1
        // Pulsada (las de paso 0 solo avisan; las de paso ±1 además cambian
        // de mes).
        signal pulsada

        implicitWidth: 24
        implicitHeight: 24
        radius: 8
        color: Qt.rgba(1, 1, 1, flecha.encima ? 0.18 : (flechaHover.hovered ? 0.08 : 0))
        readonly property bool encima: flechaDrop.containsDrag

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }

        Text {
            anchors.centerIn: parent
            text: flecha.texto
            color: flecha.encima || flechaHover.hovered ? Theme.strong : Theme.muted
            font.family: Theme.font
            font.pixelSize: 14
        }

        HoverHandler {
            id: flechaHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                if (flecha.paso !== 0)
                    root.mover(flecha.paso);
                flecha.pulsada();
            }
        }

        DropArea {
            id: flechaDrop

            anchors.fill: parent
            keys: ["tarea"]
            enabled: root.arrastrada !== null && flecha.paso !== 0
            onContainsDragChanged: {
                if (flechaDrop.containsDrag)
                    cadencia.restart();
                else
                    cadencia.stop();
            }
        }

        Timer {
            id: cadencia

            interval: 550
            repeat: true
            onTriggered: root.mover(flecha.paso)
        }
    }

    // La rueda mueve el mes. Va en un WheelHandler y no en un MouseArea para no
    // quitarles los clics a los días, que con la agenda eligen qué día se ve.
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

        // Cabecera: flechas, el mes y el año que se están mirando (el chip abre
        // su desplegable) y, a la derecha, volver a hoy. Las flechas aceptan
        // también una tarea arrastrada: con ella encima, el mes pasa solo.
        RowLayout {
            id: cabecera

            Layout.fillWidth: true
            spacing: 4

            Flecha {
                objectName: "mesAnterior"
                texto: "󰅁"
                paso: -1
            }

            Chip {
                id: chipMes

                objectName: "chipMes"
                texto: root.mayus(root.loc.monthName(root.shown.getMonth(), Locale.LongFormat)) + " " + root.shown.getFullYear()
                abierto: root.selectorAbierto
                onPulsado: root.abrirSelector()
            }

            Flecha {
                objectName: "mesSiguiente"
                texto: "󰅂"
                paso: 1
            }

            Item {
                Layout.fillWidth: true
            }

            // Volver a hoy. Sólo aparece cuando se ha movido de mes o se ha
            // pulsado otro día, porque si no, pulsarlo no haría nada.
            Text {
                objectName: "botonHoy"
                visible: !root.onToday || root.elegido !== ""
                text: "󰄉"
                color: todayHover.hovered ? Theme.strong : Theme.faint
                font.family: Theme.font
                font.pixelSize: 11

                HoverHandler {
                    id: todayHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.volverAHoy()
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

                objectName: "dia-" + cell.clave
                implicitWidth: 34
                implicitHeight: 28

                readonly property bool esHoy: root.sameDay(cell.model.date, root.shell.now)
                // Los días que MonthGrid pone para cuadrar la rejilla pero
                // pertenecen al mes de al lado.
                readonly property bool esDeFuera: cell.model.month !== grid.month
                readonly property string clave: Formato.claveDe(cell.model.date)
                // Lo que tiene el día en la agenda: un punto por cosa, tres
                // como mucho, en el orden de la lista.
                readonly property var puntos: Formato.puntos(root.agenda, cell.clave, root.hoy, 3)
                readonly property bool esElegido: root.elegido !== "" && cell.clave === root.elegido

                // El día pulsado, y el que está bajo el ratón, llevan una
                // lámina más tenue que la de hoy.
                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 24
                    radius: 8
                    visible: !cell.esHoy && (cell.esElegido || hover.hovered)
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, cell.esElegido ? 0.10 : 0.05)
                    border.width: cell.esElegido ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.18)
                }

                // El día sobre el que está la tarea que se arrastra: un halo
                // sutil, una lámina apenas más clara que la del día pulsado
                // con un canto fino, que crece con rebote al entrar y se
                // encoge sin rebote al salir. El día de la propia tarea no es
                // destino: no se resalta (su DropArea está apagado).
                Rectangle {
                    id: objetivo

                    objectName: "destino"
                    anchors.centerIn: parent
                    width: 30
                    height: 26
                    radius: 9
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.34)
                    opacity: 0
                    scale: 0.8
                    visible: opacity > 0

                    states: State {
                        name: "sobre"
                        when: dropDia.containsDrag
                        PropertyChanges {
                            objetivo.opacity: 1
                            objetivo.scale: 1.0
                        }
                    }

                    transitions: [
                        Transition {
                            to: "sobre"
                            NumberAnimation {
                                properties: "opacity,scale"
                                duration: 320
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.9
                            }
                        },
                        Transition {
                            from: "sobre"
                            NumberAnimation {
                                properties: "opacity,scale"
                                duration: 220
                                easing.type: Easing.InOutQuint
                            }
                        }
                    ]
                }

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
                    // Con agenda, sube un poco para dejar sitio a los puntos;
                    // en todos los días, para que la fila no baile.
                    anchors.verticalCenterOffset: root.agenda !== null ? -2 : 0
                    text: cell.model.day
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: cell.esHoy
                    color: cell.esHoy || dropDia.containsDrag ? Theme.strong : (cell.esDeFuera ? Qt.rgba(1, 1, 1, 0.18) : Theme.text)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    spacing: 2
                    opacity: cell.esDeFuera ? 0.45 : 1

                    Repeater {
                        model: cell.puntos

                        Rectangle {
                            required property string modelData

                            objectName: "punto"
                            width: 4
                            height: 4
                            radius: 2
                            color: root.colorTipo(modelData)
                        }
                    }
                }

                // Sin agenda los días no hacen nada al pulsarlos.
                HoverHandler {
                    id: hover
                    enabled: root.agenda !== null
                    cursorShape: Qt.PointingHandCursor
                }

                // Un clic elige el día; doble clic abre la hoja para crear
                // una tarea en él. Va en un MouseArea y no en un TapHandler
                // porque el doble toque de un TapHandler no hay forma de
                // provocarlo desde QtTest (separa cada clic del siguiente más
                // que el intervalo de doble clic), y el doble clic de un
                // MouseArea sí. Y de paso, en un doble clic el segundo no
                // cuenta como otro clic: el día no se elige y se suelta en el
                // mismo gesto.
                MouseArea {
                    anchors.fill: parent
                    enabled: root.agenda !== null
                    onClicked: root.elegir(cell.clave)
                    onDoubleClicked: root.abrirNueva(cell.clave)
                }

                DropArea {
                    id: dropDia

                    anchors.fill: parent
                    keys: ["tarea"]
                    enabled: root.arrastrada !== null && root.arrastrada.dia !== cell.clave
                    onDropped: drop => {
                        drop.accept();
                        root.soltarEn(cell.clave);
                    }
                }
            }
        }

        // --- Lo del día -----------------------------------------------------
        // Con la hoja de una tarea abierta, en su sitio está la hoja.
        ColumnLayout {
            objectName: "agendaDia"
            Layout.fillWidth: true
            visible: root.agenda !== null && root.hojaModo === ""
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.rule
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    objectName: "tituloDia"
                    text: root.tituloDia(root.diaVisto)
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }

                // Lo que pasó al escribir en el panel (mover, crear…), a la
                // derecha, con lo que quede de sitio y recortado si no cabe.
                // Sin el ancho preferido y el mínimo a cero, un aviso largo
                // (los del panel lo son) pediría su ancho entero a la fila, y
                // la columna de fuera ensancharía con ella todo el calendario
                // por encima de los 320 de la isla.
                Text {
                    objectName: "avisoMover"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    visible: root.aviso !== ""
                    text: root.aviso
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }

                // El cajón la dejó sin conexión con el panel: puede no estar al
                // día. Igual que el aviso.
                Text {
                    objectName: "sinConexion"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    visible: root.aviso === "" && root.agenda !== null && !root.agenda.conectado
                    text: "sin conexión con el panel"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }

            // Las filas, con sitio para tres aunque haya menos: así pulsar un
            // día u otro casi nunca cambia el alto de la isla.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumHeight: 3 * 16 + 2 * 4
                spacing: 4

                Repeater {
                    model: root.lista.slice(0, root.maxFilas)

                    RowLayout {
                        id: fila

                        required property var modelData

                        readonly property string tipo: Formato.tipo(fila.modelData, root.hoy)
                        // El punto enseña la prioridad que se le ha puesto, no la
                        // «efectiva» (que el panel sube según la fecha): si no,
                        // elegir otra en el menú no se vería en lo cercano.
                        readonly property string tipoPunto: fila.tipo === "vencida" || fila.tipo === "hecha" ? fila.tipo : (fila.modelData.prioridadPropia || fila.tipo)

                        objectName: "filaAgenda"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                        spacing: 8

                        // Se puede editar: con el panel al alcance y con id
                        // (lo que viene del fichero del cajón no lo tiene).
                        readonly property bool movible: root.puedeEscribir && fila.modelData.id !== ""
                        readonly property bool enMano: root.arrastrada !== null && root.arrastrada.id === fila.modelData.id

                        opacity: fila.enMano ? 0.35 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 160
                            }
                        }

                        // Arrastrar la fila lleva la tarea a otro día; la fila no
                        // se mueve (target null), lo que viaja es el fantasma.
                        HoverHandler {
                            id: filaHover

                            enabled: fila.movible
                            cursorShape: dragFila.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        }

                        DragHandler {
                            id: dragFila

                            enabled: fila.movible
                            target: null
                            onActiveChanged: {
                                if (dragFila.active)
                                    root.empezarArrastre(fila.modelData, dragFila.centroid.scenePosition);
                                else
                                    root.terminarArrastre();
                            }
                            onCentroidChanged: if (dragFila.active)
                                root.seguirArrastre(dragFila.centroid.scenePosition)
                        }

                        Component.onDestruction: if (dragFila.active)
                            root.cancelarArrastre()

                        // El punto, con el color de la prioridad de hoy. Pulsado
                        // abre el menú de prioridades; la zona que se pulsa es
                        // algo mayor que el punto, que crece un poco al pasar
                        // por encima para decir que se puede.
                        Item {
                            id: puntoFila

                            objectName: "puntoFila"
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: -3
                            implicitWidth: 12
                            implicitHeight: 16

                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: 3
                                color: root.colorTipo(fila.tipoPunto)
                                scale: puntoHover.hovered || (root.menuDe !== null && root.menuDe.id === fila.modelData.id) ? 1.5 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.9
                                    }
                                }
                            }

                            // El color propio de la tarea, si lo tiene: una
                            // barrita a la izquierda del punto, en el margen,
                            // para no mover el título de sitio.
                            Rectangle {
                                objectName: "colorFila"
                                x: -4
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 14
                                radius: 1.5
                                visible: (fila.modelData.colorPropio || "") !== ""
                                color: fila.modelData.colorPropio || "transparent"
                                opacity: fila.modelData.hecha ? 0.45 : 1
                            }

                            HoverHandler {
                                id: puntoHover

                                enabled: fila.movible
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                enabled: fila.movible
                                onTapped: root.abrirPrioridad(fila.modelData, puntoFila)
                            }
                        }

                        // Pulsado, abre la hoja para editarla. Arrastrar desde
                        // él sigue moviéndola: el TapHandler suelta en cuanto
                        // el DragHandler de la fila echa a andar.
                        Text {
                            objectName: "tituloFila"
                            Layout.fillWidth: true
                            text: fila.modelData.titulo
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: fila.modelData.hecha ? Theme.faint : (tituloHover.hovered ? Theme.strong : Theme.text)
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.strikeout: fila.modelData.hecha

                            HoverHandler {
                                id: tituloHover
                                enabled: fila.movible
                            }

                            TapHandler {
                                enabled: fila.movible
                                onTapped: root.abrirEdicion(fila.modelData)
                            }
                        }

                        Text {
                            objectName: "etiquetaFila"
                            Layout.maximumWidth: 110
                            text: root.etiqueta(fila.modelData)
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            color: fila.tipo === "vencida" ? Theme.prioMaxima : Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10
                        }

                        // 🚫🤖 «Claude no la hace» (el robot tachado de la
                        // fuente de la barra). Apagado no está hasta que el
                        // ratón pasa por la fila, y entonces tenue; encendido,
                        // siempre. Ocupa su sitio aunque no se vea, para que la
                        // fila no baile.
                        Text {
                            id: robot

                            readonly property bool activo: fila.modelData.claudeOff === true

                            objectName: "claudeOffFila"
                            Layout.alignment: Qt.AlignVCenter
                            visible: fila.modelData.id !== ""
                            text: "󱚧"
                            color: robot.activo || robotHover.hovered ? Theme.strong : Theme.muted
                            opacity: robot.activo || robotHover.hovered ? 1 : (filaHover.hovered ? 0.55 : 0)
                            font.family: Theme.font
                            font.pixelSize: 12

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 140
                                }
                            }

                            HoverHandler {
                                id: robotHover

                                enabled: fila.movible
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                enabled: fila.movible
                                onTapped: root.cambiarClaudeOff(fila.modelData)
                            }
                        }
                    }
                }

                Text {
                    objectName: "masFilas"
                    visible: root.lista.length > root.maxFilas
                    text: "y " + (root.lista.length - root.maxFilas) + " más"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                }

                Text {
                    objectName: "diaVacio"
                    visible: root.lista.length === 0
                    text: root.diaVisto === root.hoy ? "Nada para hoy" : "Nada para este día"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }

        // --- La hoja de una tarea --------------------------------------------
        // Solo existe mientras está abierta. Coge el teclado al aparecer y se
        // lo devuelve a quien lo tenía al cerrarse (cerrarHoja).
        Loader {
            id: hojaCarga

            Layout.fillWidth: true
            active: root.hojaModo !== ""
            visible: active
            sourceComponent: Component {
                HojaTarea {
                    objectName: "hoja"
                    modo: root.hojaModo
                    dia: root.hojaDia
                    inicial: root.hojaInicial
                    prioridades: root.prioridades
                    ocupada: root.guardando
                    error: root.hojaError
                    conPanel: root.puedeEscribir || root.guardando
                    onGuardar: valores => root.guardarHoja(valores)
                    onCancelar: root.cerrarHoja()
                    onTocada: root.hojaError = ""
                }
            }
            onLoaded: {
                root.tecladoAntes = root.Window.activeFocusItem;
                hojaCarga.item.enfocar();
            }
        }
    }

    Timer {
        id: avisoReloj
        interval: 3500
        onTriggered: root.aviso = ""
    }

    // --- Lo que flota: el desplegable de mes y año y el menú de prioridades ----
    // Pulsar fuera de ellos (pero dentro del calendario) los cierra; pulsar
    // fuera de la isla la cierra entera, como siempre. Con el desplegable
    // abierto, la cabecera sigue a mano: el chip lo cierra y las flechas
    // cambian de mes.
    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.selectorAbierto ? content.y + cabecera.y + cabecera.height : 0
        z: 4
        enabled: root.selectorAbierto || root.menuDe !== null
        onPressed: {
            root.cerrarSelector();
            root.cerrarPrioridad();
        }
    }

    Rectangle {
        id: popup

        objectName: "selector"
        z: 5
        // Pequeño y bajo el chip, sin salirse del calendario.
        width: 204
        x: Math.max(Theme.pad, Math.min(root.width - Theme.pad - popup.width, content.x + cabecera.x + chipMes.x + chipMes.width / 2 - popup.width / 2))
        y: content.y + cabecera.y + cabecera.height + 6
        implicitHeight: popupContenido.implicitHeight + 16
        height: implicitHeight
        radius: 12
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        opacity: 0
        scale: 0.9
        transformOrigin: Item.Top
        visible: opacity > 0

        states: State {
            name: "abierto"
            when: root.selectorAbierto
            PropertyChanges {
                popup.opacity: 1
                popup.scale: 1.0
            }
        }

        // Abre con rebote, cierra sin él (el vocabulario de la isla).
        transitions: [
            Transition {
                to: "abierto"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 320
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.9
                }
            },
            Transition {
                from: "abierto"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 200
                    easing.type: Easing.InOutQuint
                }
            }
        ]

        // Se come los clics para que no lleguen a los días de debajo.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: popupContenido

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 6

            // El año, con sus flechitas.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Flecha {
                    objectName: "anioAnterior"
                    texto: "󰅁"
                    paso: 0
                    onPulsada: root.selectorAnio -= 1
                }

                Text {
                    objectName: "anioSelector"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: String(root.selectorAnio)
                    color: root.selectorAnio === root.shown.getFullYear() ? Theme.strong : Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                }

                Flecha {
                    objectName: "anioSiguiente"
                    texto: "󰅂"
                    paso: 0
                    onPulsada: root.selectorAnio += 1
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.rule
            }

            // Los meses, de tres en tres. Resaltado el que se está mirando;
            // en negrita, el de hoy.
            GridLayout {
                columns: 3
                rowSpacing: 4
                columnSpacing: 4
                Layout.fillWidth: true

                Repeater {
                    model: 12

                    Rectangle {
                        id: opcion

                        required property int index

                        readonly property bool actual: root.selectorAnio === root.shown.getFullYear() && opcion.index === root.shown.getMonth()
                        readonly property bool deHoy: root.selectorAnio === root.shell.now.getFullYear() && opcion.index === root.shell.now.getMonth()

                        objectName: "opcionSelector"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 26
                        radius: 8
                        color: Qt.rgba(1, 1, 1, opcion.actual ? 0.16 : (opcionHover.hovered ? 0.08 : 0))
                        border.width: opcion.actual ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.28)

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        // Los nombres cortos, de AgendaFormato.js y no de la
                        // configuración regional: según la versión de sus
                        // datos, septiembre es «sep», «sept» o «sept.».
                        Text {
                            anchors.centerIn: parent
                            text: root.mayus(Formato.MESES[opcion.index])
                            color: opcion.actual ? Theme.strong : (opcion.deHoy ? Theme.text : Theme.muted)
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: opcion.actual || opcion.deHoy
                        }

                        HoverHandler {
                            id: opcionHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                root.irA(root.selectorAnio, opcion.index);
                                root.cerrarSelector();
                            }
                        }
                    }
                }
            }
        }
    }

    // El menú de prioridades de una tarea (al pulsar su punto). Lo que enseña
    // sale de `de`, que se queda puesto al cerrar, para que no cambie mientras
    // se va.
    Rectangle {
        id: menuPrio

        property var de: null
        // Si sale encima del punto (crece desde abajo) o debajo.
        property bool arriba: true
        readonly property int alto: 22

        objectName: "menuPrioridad"
        z: 5
        width: 132
        height: root.prioridades.length * (menuPrio.alto + 2) - 2 + 12
        radius: 10
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        opacity: 0
        scale: 0.9
        transformOrigin: menuPrio.arriba ? Item.BottomLeft : Item.TopLeft
        visible: opacity > 0

        states: State {
            name: "abierto"
            when: root.menuDe !== null
            PropertyChanges {
                menuPrio.opacity: 1
                menuPrio.scale: 1.0
            }
        }

        transitions: [
            Transition {
                to: "abierto"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 320
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.9
                }
            },
            Transition {
                from: "abierto"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 200
                    easing.type: Easing.InOutQuint
                }
            }
        ]

        MouseArea {
            anchors.fill: parent
        }

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: root.prioridades

                Rectangle {
                    id: opcionPrio

                    required property var modelData

                    // La que tiene puesta, no la de hoy: una tarea que vence
                    // mañana sale roja aunque sea de prioridad baja.
                    readonly property bool actual: menuPrio.de !== null && menuPrio.de.prioridadPropia === opcionPrio.modelData.nombre

                    objectName: "opcionPrioridad"
                    width: parent.width
                    height: menuPrio.alto
                    radius: 6
                    color: Qt.rgba(1, 1, 1, opcionPrioHover.hovered ? 0.08 : 0)

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.colorPrioridad(opcionPrio.modelData.nombre)
                    }

                    Text {
                        objectName: "etiquetaPrioridad"
                        anchors.left: parent.left
                        anchors.leftMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: opcionPrio.modelData.etiqueta
                        color: opcionPrio.actual || opcionPrioHover.hovered ? Theme.strong : Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.bold: opcionPrio.actual
                    }

                    Text {
                        objectName: "marcaPrioridad"
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: opcionPrio.actual
                        text: "󰄬"
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    HoverHandler {
                        id: opcionPrioHover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.elegirPrioridad(opcionPrio.modelData)
                    }
                }
            }
        }
    }

    // --- La tarea que se lleva en la mano ---------------------------------------
    // Un fantasma de cristal que sigue al puntero (seguirArrastre); al
    // soltarlo, el DropArea de la casilla de debajo del puntero recibe el
    // drop. Sin soltar sobre un día, se funde.
    Rectangle {
        id: ghost

        property string titulo: ""
        property color punto: Theme.text

        objectName: "fantasma"
        z: 20
        width: Math.min(190, fantasmaTexto.implicitWidth + 32)
        height: 24
        radius: 9
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.3)
        opacity: 0
        scale: 0.8
        visible: opacity > 0

        Drag.keys: ["tarea"]

        states: State {
            name: "llevado"
            when: root.arrastrada !== null
            PropertyChanges {
                ghost.opacity: 0.96
                ghost.scale: 1.0
            }
        }

        transitions: [
            Transition {
                to: "llevado"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.9
                }
            },
            Transition {
                from: "llevado"
                NumberAnimation {
                    properties: "opacity,scale"
                    duration: 200
                    easing.type: Easing.InOutQuint
                }
            }
        ]

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            radius: 3
            color: ghost.punto
        }

        Text {
            id: fantasmaTexto

            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: ghost.titulo
            elide: Text.ElideRight
            textFormat: Text.PlainText
            color: Theme.strong
            font.family: Theme.font
            font.pixelSize: 11
        }
    }
}
