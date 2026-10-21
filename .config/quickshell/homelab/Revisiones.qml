import QtQuick
import QtQuick.Layouts
import "shared"

// Revisiones, como en la web: el reminder de cada noche de la semana, la retro
// y el planning del domingo por apartados, la tarjeta del domingo y el
// selector de semana. El cajón no genera nada: enseña las notas del usuario y
// guarda exactamente lo que escribe, un apartado cada vez (un reminder, o un
// apartado de la retro o del planning). Si no existe la nota, se crea desde la
// plantilla; el NUC decide qué se puede escribir y contesta con lo que no.
//
// Ctrl+Intro guarda y Escape cancela, en el campo. Si la nota cambió por otro
// lado mientras se escribía, el NUC contesta 409, no escribe nada y manda la
// semana como está: se recarga y se avisa, y lo escrito se queda en el campo
// (sustituirá el apartado si se vuelve a guardar). Sale de api.revisiones.
FocusScope {
    id: revisiones

    required property var shell
    readonly property var api: revisiones.shell.api
    readonly property var datos: revisiones.api ? revisiones.api.revisiones : null
    readonly property bool conectado: revisiones.api !== null && revisiones.api.conexion === "conectado"
    readonly property bool ocupado: revisiones.api !== null && revisiones.api.revisionesOcupado
    // Lo que se ve de verdad: la sección, con el cajón abierto.
    readonly property bool activa: revisiones.visible && revisiones.shell.abierto

    property string lineaConexion: ""

    signal abrirWeb
    signal irATareas

    // Lo que se está escribiendo: "r:2026-10-20" (un reminder) o "retro:3" /
    // "planning:3" (el apartado i). El texto del que se partió («antes», para
    // que el NUC vea si cambió) y el borrador, que sobrevive a que la lista se
    // reconstruya.
    property string editando: ""
    property string base: ""
    property string borrador: ""
    // El NUC dijo 409 y se recargó: lo escrito se conserva, con su aviso.
    property bool conflicto: false
    property bool planningAbierto: false
    property bool retroAbierto: false
    // Al entrar en la sección: abrir el reminder de hoy para escribir si está
    // vacío. Y, tras cambiar de semana desde la tarjeta, qué nota abrir.
    property bool abrirHoy: false
    property var pendiente: null
    property string semanaVista: ""

    readonly property var dias: ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]
    readonly property var meses: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    readonly property var titulos: ({
            planning: "WEEKLY PLANNING",
            retro: "WEEKLY RETROSPECTIVE"
        })

    function numSemana(id) {
        return parseInt(String(id).slice(6), 10);
    }

    function fechaCorta(iso) {
        return +iso.slice(8) + " " + revisiones.meses[+iso.slice(5, 7) - 1];
    }

    function rango() {
        const d = revisiones.datos;
        if (!d || d.lunes === "")
            return "";
        const a = d.lunes, b = d.domingo;
        return (a.slice(5, 7) === b.slice(5, 7) ? +a.slice(8) : revisiones.fechaCorta(a)) + "–" + revisiones.fechaCorta(b);
    }

    // El título de un apartado sin las marcas de Markdown ni los [[enlaces]].
    function plano(texto) {
        return String(texto).replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, (_, a, b) => (b || a.split("#")[0].split("/").pop()).trim()).replace(/\*\*|~~|`/g, "");
    }

    function nota(tipo) {
        return tipo === "planning" ? revisiones.datos.planning : revisiones.datos.retro;
    }

    function abierta(tipo) {
        return (tipo === "planning" ? revisiones.planningAbierto : revisiones.retroAbierto) || revisiones.editando.indexOf(tipo + ":") === 0;
    }

    function plegar(tipo, abierto) {
        if (tipo === "planning")
            revisiones.planningAbierto = abierto;
        else
            revisiones.retroAbierto = abierto;
    }

    // El texto de lo que se edita, tal como está ahora en los datos; null si
    // ya no está.
    function textoDe(clave) {
        const d = revisiones.datos;
        if (!d)
            return null;
        if (clave.indexOf("r:") === 0) {
            const r = d.reminders.find(x => x.fecha === clave.slice(2));
            return r ? r.texto : null;
        }
        const tipo = clave.split(":")[0], i = +clave.split(":")[1];
        const s = revisiones.nota(tipo).secciones.find(x => x.i === i);
        return s ? s.cuerpo : null;
    }

    function escribir(clave, texto) {
        if (revisiones.ocupado)
            return;
        revisiones.conflicto = false;
        revisiones.base = texto;
        revisiones.borrador = texto;
        revisiones.editando = clave;
    }

    function cancelar() {
        revisiones.editando = "";
        revisiones.conflicto = false;
        sumidero.forceActiveFocus();
    }

    function guardar() {
        const clave = revisiones.editando;
        if (clave === "" || revisiones.ocupado || !revisiones.datos)
            return;
        const alAcabar = res => {
            if (res === "ok") {
                revisiones.cancelar();
            } else if (res === "obsoleta") {
                // Lo nuevo de las notas pasa a ser la base: si se guarda otra
                // vez, es porque se ha visto el aviso y se quiere eso.
                const fresco = revisiones.textoDe(clave);
                if (fresco === null)
                    revisiones.cancelar();
                else {
                    revisiones.base = fresco;
                    revisiones.conflicto = true;
                }
            }
        };
        const d = revisiones.datos;
        if (clave.indexOf("r:") === 0) {
            revisiones.api.guardarRecordatorio(clave.slice(2), revisiones.base, revisiones.borrador, alAcabar);
            return;
        }
        const tipo = clave.split(":")[0], i = +clave.split(":")[1];
        const s = revisiones.nota(tipo).secciones.find(x => x.i === i);
        if (s)
            revisiones.api.guardarApartado(tipo, d.semana, i, s.titulo, revisiones.base, revisiones.borrador, alAcabar);
    }

    // Crea la retro o el planning de la semana y lo deja a la vista.
    function crear(tipo) {
        if (revisiones.ocupado || !revisiones.datos)
            return;
        revisiones.plegar(tipo, true);
        revisiones.api.crearNotaRevision(tipo, revisiones.datos.semana, res => {});
    }

    // Abre una nota de la semana: la crea si falta y baja hasta ella.
    function abrirNota(tipo) {
        if (!revisiones.datos)
            return;
        revisiones.plegar(tipo, true);
        if (!revisiones.nota(tipo).existe)
            revisiones.crear(tipo);
        Qt.callLater(() => revisiones.bajarA(tipo));
    }

    function bajarA(tipo) {
        const b = tipo === "planning" ? bloquePlanning : bloqueRetro;
        const y = b.mapToItem(desplazable.contentItem, 0, 0).y;
        desplazable.contentY = Math.max(0, Math.min(y, desplazable.contentHeight - desplazable.height));
    }

    function cambiarSemana(id) {
        if (!revisiones.datos || revisiones.ocupado)
            return;
        if (revisiones.editando !== "")
            revisiones.cancelar();
        revisiones.api.cargarRevisiones(id === revisiones.datos.semanaActual ? "" : id);
    }

    // El reminder de hoy, si es de esta semana y se puede escribir vacío.
    function abrirReminderDeHoy() {
        const d = revisiones.datos;
        if (!revisiones.abrirHoy || !d || !d.actual || revisiones.editando !== "" || revisiones.pendiente !== null)
            return;
        revisiones.abrirHoy = false;
        const r = d.reminders.find(x => x.fecha === d.hoy);
        if (r && r.editable && r.texto === "")
            revisiones.escribir("r:" + r.fecha, "");
    }

    function ponerAlDia() {
        if (!revisiones.activa || !revisiones.conectado || !revisiones.api || revisiones.editando !== "")
            return;
        const c = revisiones.api.revisionesCargadas;
        if (revisiones.api.revisionesPedida !== "" || !c || Date.now() - c.getTime() > 60000)
            revisiones.api.cargarRevisiones(revisiones.abrirHoy ? "" : undefined);
        else
            revisiones.abrirReminderDeHoy();
    }

    onActivaChanged: {
        if (revisiones.activa) {
            revisiones.abrirHoy = true;
            revisiones.ponerAlDia();
            Qt.callLater(() => {
                if (revisiones.editando === "")
                    sumidero.forceActiveFocus();
            });
        }
    }

    onConectadoChanged: revisiones.ponerAlDia()

    onDatosChanged: {
        const d = revisiones.datos;
        if (!d)
            return;
        // Otra semana: lo que estaba abierto o escribiéndose ya no es de aquí.
        if (d.semana !== revisiones.semanaVista) {
            revisiones.semanaVista = d.semana;
            revisiones.editando = "";
            revisiones.conflicto = false;
            revisiones.planningAbierto = false;
            revisiones.retroAbierto = false;
        }
        const p = revisiones.pendiente;
        if (p !== null && d.semana === p.semana) {
            revisiones.pendiente = null;
            // Fuera del cambio de datos: abrirla puede crearla, y eso los cambia otra vez.
            Qt.callLater(() => revisiones.abrirNota(p.tipo));
            return;
        }
        revisiones.abrirReminderDeHoy();
    }

    Item {
        id: sumidero
        focus: true
    }

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

    // Un paso: número, título y subtítulo, y su botón.
    component Paso: RowLayout {
        id: paso

        property string numero: ""
        property string titulo: ""
        property string subtitulo: ""
        property string boton: ""
        property string nombre: ""

        signal activado

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: paso.numero
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: paso.titulo
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: paso.subtitulo
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Chip {
            objectName: paso.nombre
            texto: paso.boton
            encendido: !revisiones.ocupado
            onActivado: paso.activado()
        }
    }

    // El texto de un reminder o de un apartado: Markdown (listas, tablas,
    // negritas); los enlaces [[…]] salen tal cual.
    component Cuerpo: Text {
        Layout.fillWidth: true
        textFormat: Text.MarkdownText
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    // El campo con Guardar y Cancelar.
    component Editor: ColumnLayout {
        id: editor

        property string etiqueta: ""

        spacing: 6

        Campo {
            id: campo

            objectName: "campoRevision"
            Layout.fillWidth: true
            Layout.minimumHeight: 84
            multilinea: true
            pista: "Escribe aquí…"
            Component.onCompleted: {
                campo.texto = revisiones.borrador;
                // Ya dentro de la ventana (el Loader aún no lo ha colocado).
                Qt.callLater(() => {
                    campo.enfocar();
                    campo.alFinal();
                });
            }
            onTextoChanged: revisiones.borrador = campo.texto
            onAceptado: revisiones.guardar()
            onCancelado: revisiones.cancelar()
        }

        Text {
            objectName: "avisoConflicto"
            Layout.fillWidth: true
            visible: revisiones.conflicto
            text: "Esto cambió en tus notas; lo de arriba es lo que escribías. Si guardas, sustituye lo que hay."
            color: Theme.warn
            font.family: Theme.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Chip {
                objectName: "revisionGuardar"
                texto: revisiones.ocupado ? "Guardando…" : "Guardar"
                activo: true
                encendido: !revisiones.ocupado
                onActivado: revisiones.guardar()
            }

            Chip {
                objectName: "revisionCancelar"
                texto: "Cancelar"
                encendido: !revisiones.ocupado
                onActivado: revisiones.cancelar()
            }

            Text {
                Layout.fillWidth: true
                text: "Ctrl+Intro guarda · Esc cancela"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    Component {
        id: editorComp

        Editor {}
    }

    // Una tarjeta de cristal.
    component Tarjeta: Rectangle {
        default property alias contenido: pila.data
        property bool resaltada: false

        implicitHeight: pila.implicitHeight + 20
        radius: 12
        color: Qt.rgba(1, 1, 1, resaltada ? 0.08 : 0.05)
        border.width: 1
        border.color: resaltada ? Qt.rgba(1, 1, 1, 0.3) : Theme.rule

        ColumnLayout {
            id: pila

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            anchors.leftMargin: 12
            spacing: 6
        }
    }

    // --- La interfaz ---

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            visible: revisiones.lineaConexion !== ""
            spacing: 8

            Rectangle {
                implicitWidth: 6
                implicitHeight: 6
                radius: 3
                color: Theme.muted
            }

            Text {
                objectName: "lineaConexionRevisiones"
                Layout.fillWidth: true
                text: revisiones.lineaConexion
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }

        Text {
            objectName: "revisionesSinDatos"
            Layout.fillWidth: true
            visible: revisiones.datos === null && revisiones.lineaConexion === ""
            text: revisiones.api && revisiones.api.revisionesError !== "" ? revisiones.api.revisionesError : "Cargando las revisiones…"
            color: revisiones.api && revisiones.api.revisionesError !== "" ? Theme.warn : Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Text {
            objectName: "revisionesDesconectadas"
            Layout.fillWidth: true
            visible: revisiones.datos !== null && !revisiones.datos.habilitado
            text: "Las revisiones no están conectadas: falta «vault» en la configuración del panel."
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        // --- El selector de semana ---
        RowLayout {
            Layout.fillWidth: true
            visible: revisiones.datos !== null && revisiones.datos.habilitado
            spacing: 6

            Chip {
                objectName: "revisionAnterior"
                glifo: "‹"
                tamano: 13
                encendido: revisiones.datos !== null && revisiones.datos.anterior !== "" && !revisiones.ocupado
                onActivado: revisiones.cambiarSemana(revisiones.datos.anterior)
            }

            Chip {
                objectName: "revisionSiguiente"
                glifo: "›"
                tamano: 13
                // Una semana por delante de la de hoy es lo más lejos.
                encendido: revisiones.datos !== null && revisiones.datos.siguiente !== "" && revisiones.datos.semana <= revisiones.datos.semanaActual && !revisiones.ocupado
                onActivado: revisiones.cambiarSemana(revisiones.datos.siguiente)
            }

            Text {
                objectName: "revisionSemana"
                Layout.fillWidth: true
                text: revisiones.datos ? "Semana " + revisiones.numSemana(revisiones.datos.semana) + " · " + revisiones.rango() : ""
                color: Theme.strong
                font.family: Theme.font
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Chip {
                objectName: "revisionEstaSemana"
                visible: revisiones.datos !== null && !revisiones.datos.actual
                texto: "Esta semana"
                encendido: !revisiones.ocupado
                onActivado: revisiones.cambiarSemana(revisiones.datos.semanaActual)
            }
        }

        Text {
            objectName: "revisionesError"
            Layout.fillWidth: true
            visible: revisiones.datos !== null && (revisiones.datos.error !== "" || (revisiones.api && revisiones.api.revisionesError !== ""))
            text: revisiones.datos ? (revisiones.datos.error !== "" ? revisiones.datos.error : (revisiones.api ? "Datos antiguos: " + revisiones.api.revisionesError : "")) : ""
            color: Theme.warn
            font.family: Theme.font
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        Flickable {
            id: desplazable

            objectName: "desplazableRevisiones"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: revisiones.datos !== null && revisiones.datos.habilitado
            clip: true
            contentWidth: width
            contentHeight: columna.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: columna

                width: desplazable.width
                spacing: 8
                opacity: revisiones.lineaConexion === "" ? 1 : 0.5

                // --- La tarjeta del domingo ---
                Tarjeta {
                    id: tarjetaDomingo

                    objectName: "tarjetaDomingo"
                    Layout.fillWidth: true
                    visible: revisiones.datos !== null && revisiones.datos.actual
                    resaltada: revisiones.datos !== null && revisiones.datos.hoy === revisiones.datos.domingo

                    Etiqueta {
                        text: "REVISIÓN DEL DOMINGO · " + (tarjetaDomingo.resaltada ? "ES HOY" : "DE UNA SENTADA")
                    }

                    Paso {
                        nombre: "pasoRetro"
                        numero: "1"
                        titulo: revisiones.datos ? "Retro de S" + revisiones.numSemana(revisiones.datos.semana) : ""
                        subtitulo: "Lee los reminders de la semana y escribe la retro."
                        boton: revisiones.datos && revisiones.datos.retro.existe ? "Abrir" : "Crear y abrir"
                        onActivado: revisiones.abrirNota("retro")
                    }

                    Paso {
                        nombre: "pasoPlanning"
                        numero: "2"
                        titulo: revisiones.datos ? "Planning de S" + revisiones.numSemana(revisiones.datos.siguiente) : ""
                        subtitulo: "La semana que empieza."
                        boton: "Abrir"
                        onActivado: {
                            revisiones.pendiente = {
                                tipo: "planning",
                                semana: revisiones.datos.siguiente
                            };
                            revisiones.cambiarSemana(revisiones.datos.siguiente);
                        }
                    }

                    Paso {
                        nombre: "pasoTareas"
                        numero: "3"
                        titulo: "Ordenar tareas"
                        subtitulo: "Pasa por tus pendientes."
                        boton: "Ir a Tareas"
                        onActivado: revisiones.irATareas()
                    }
                }

                // --- El planning ---
                ColumnLayout {
                    id: bloquePlanning

                    objectName: "bloquePlanning"
                    Layout.fillWidth: true
                    visible: revisiones.datos !== null
                    spacing: 6

                    NotaBloque {
                        tipo: "planning"
                    }
                }

                // --- Los reminders ---
                Etiqueta {
                    Layout.topMargin: 4
                    visible: revisiones.datos !== null
                    text: "REMINDERS · CADA NOCHE, ANTES DE DORMIR"
                }

                Repeater {
                    model: revisiones.datos ? revisiones.datos.reminders : []

                    delegate: Tarjeta {
                        id: dia

                        required property int index
                        required property var modelData
                        readonly property string clave: "r:" + dia.modelData.fecha
                        readonly property bool hoy: revisiones.datos.actual && dia.modelData.fecha === revisiones.datos.hoy
                        readonly property bool futuro: dia.modelData.fecha > revisiones.datos.hoy
                        readonly property bool escribiendo: revisiones.editando === dia.clave

                        objectName: "reminder-" + dia.modelData.fecha
                        Layout.fillWidth: true
                        resaltada: dia.hoy || dia.escribiendo

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: dia.hoy ? "Hoy" : revisiones.dias[dia.index]
                                color: Theme.strong
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: true
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (dia.hoy ? revisiones.dias[dia.index] + " " : "") + revisiones.fechaCorta(dia.modelData.fecha)
                                color: Theme.faint
                                font.family: Theme.font
                                font.pixelSize: 10
                            }

                            Chip {
                                objectName: "escribir-" + dia.modelData.fecha
                                visible: dia.modelData.editable && !dia.escribiendo
                                texto: dia.modelData.texto !== "" ? "Editar" : "Escribir"
                                encendido: !revisiones.ocupado
                                onActivado: revisiones.escribir(dia.clave, dia.modelData.texto)
                            }
                        }

                        // El campo existe sólo mientras se escribe. Sin «active»:
                        // con el valor de antes de enlazar, el Loader cargaría el
                        // campo en todas las tarjetas.
                        Loader {
                            Layout.fillWidth: true
                            visible: dia.escribiendo === true
                            sourceComponent: dia.escribiendo === true ? editorComp : null
                        }

                        Cuerpo {
                            visible: !dia.escribiendo && dia.modelData.texto !== ""
                            text: dia.modelData.texto
                        }

                        Text {
                            visible: !dia.escribiendo && dia.modelData.texto === ""
                            text: dia.futuro ? "Todavía no" : "Sin escribir"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: !dia.modelData.editable && dia.modelData.existe
                            text: "Este reminder no tiene el apartado «Hoy»; ábrelo en Obsidian para editarlo."
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // --- La retro ---
                ColumnLayout {
                    id: bloqueRetro

                    objectName: "bloqueRetro"
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: revisiones.datos !== null
                    spacing: 6

                    NotaBloque {
                        tipo: "retro"
                    }
                }

                Item {
                    objectName: "revisionesEnLaWeb"
                    Layout.fillWidth: true
                    implicitHeight: textoWeb.implicitHeight + 6

                    Text {
                        id: textoWeb

                        y: 6
                        width: parent.width
                        text: "Todo esto, también en la web"
                        color: sobreWeb.hovered ? Theme.text : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.underline: sobreWeb.hovered
                        wrapMode: Text.WordWrap
                    }

                    HoverHandler {
                        id: sobreWeb
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: revisiones.abrirWeb()
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            visible: !desplazable.visible
        }
    }

    // Una nota de la semana (retro o planning): la cabecera, y por apartados
    // el título y el cuerpo, que se escriben uno a uno. Sin nota, el botón de
    // crearla desde la plantilla.
    component NotaBloque: ColumnLayout {
        id: bloque

        required property string tipo
        readonly property var n: revisiones.datos ? revisiones.nota(bloque.tipo) : null
        readonly property bool abierto: revisiones.abierta(bloque.tipo)

        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Etiqueta {
                Layout.fillWidth: true
                text: revisiones.titulos[bloque.tipo] + (revisiones.datos ? " · " + revisiones.datos.etiqueta.toUpperCase() : "")
                elide: Text.ElideRight
            }

            Chip {
                objectName: "plegar-" + bloque.tipo
                visible: bloque.n !== null && bloque.n.existe
                texto: bloque.abierto ? "Plegar" : "Ver y escribir"
                onActivado: revisiones.plegar(bloque.tipo, !bloque.abierto)
            }
        }

        Tarjeta {
            Layout.fillWidth: true
            visible: bloque.n !== null && !bloque.n.existe

            Text {
                Layout.fillWidth: true
                text: revisiones.datos ? "Aún no hay " + (bloque.tipo === "planning" ? "el planning" : "la retro") + " de la semana " + revisiones.numSemana(revisiones.datos.semana) + "." : ""
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            Chip {
                objectName: "crear-" + bloque.tipo
                texto: "Crear desde la plantilla"
                activo: true
                encendido: !revisiones.ocupado
                onActivado: revisiones.crear(bloque.tipo)
            }
        }

        Repeater {
            model: bloque.abierto && bloque.n ? bloque.n.secciones : []

            delegate: Tarjeta {
                id: apartado

                required property var modelData
                readonly property string clave: bloque.tipo + ":" + apartado.modelData.i
                readonly property bool escribiendo: revisiones.editando === apartado.clave

                objectName: "apartado-" + apartado.clave
                Layout.fillWidth: true
                Layout.leftMargin: Math.max(0, apartado.modelData.nivel - 2) * 10
                resaltada: apartado.escribiendo

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: apartado.modelData.titulo !== "" ? revisiones.plano(apartado.modelData.titulo) : ""
                        color: Theme.strong
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Chip {
                        objectName: "escribir-" + apartado.clave
                        visible: !apartado.escribiendo
                        texto: apartado.modelData.cuerpo === "" ? "Escribir" : "Editar"
                        encendido: !revisiones.ocupado
                        onActivado: revisiones.escribir(apartado.clave, apartado.modelData.cuerpo)
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    visible: apartado.escribiendo === true
                    sourceComponent: apartado.escribiendo === true ? editorComp : null
                }

                Cuerpo {
                    visible: !apartado.escribiendo && apartado.modelData.cuerpo !== ""
                    text: apartado.modelData.cuerpo
                }

                Text {
                    visible: !apartado.escribiendo && apartado.modelData.cuerpo === ""
                    text: "—"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }
}
