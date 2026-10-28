// Las tareas de 00 Inicio.md en el cajón, al estilo Foco de la web: arriba,
// «Ahora» con las tres más urgentes (o las que fijes a mano) en tarjetas
// grandes con la cuenta atrás; debajo, el resto agrupado por plazo, proyecto o
// prioridad, con los grupos plegables. Se marca una tarea como hecha, se añade,
// se fija, y se edita su texto, sus detalles y sus subtareas.
// Las reglas de qué va en «Ahora» y cómo se agrupa están en TareasLogica.js; lo
// que se pide al NUC, en Api.qml (api.tareas, api.editarTarea…). Aquí solo está
// lo que sobrevive a repintar la lista —la vista, qué grupos están plegados,
// qué está desplegado, cuál está elegida o en edición— y los atajos.

import QtQuick
import QtQuick.Layouts
import "TareasLogica.js" as Logica
import "shared"

// Los atajos (E4 del plan): el teclado es del cajón solo cuando se ha hecho clic
// dentro, así que valen únicamente con el cajón abierto y este bloque con el
// foco de teclado. Escape lo gasta quien tenga algo que cerrar; si no hay
// nada, sube hasta Borde.qml y cierra el cajón.
FocusScope {
    // --- Lo que hacen las filas y las tarjetas (ctrl) ---
    // --- Añadir ---
    // --- Los atajos ---
    // --- La interfaz ---
    // --- Arrastre: el fantasma, la tira de días y el aviso del móvil ---

    id: tareas

    required property var shell
    readonly property var api: tareas.shell.api
    // La línea de conexión de Contenido, si no está «conectado».
    property string lineaConexion: ""
    // "compacto" | "medio" | "amplio", lo pone Contenido según el ancho del
    // cajón. En «amplio» el calendario y la lista van lado a lado; en los demás,
    // el calendario se despliega encima de la lista.
    property string modo: "compacto"
    readonly property bool amplio: tareas.modo === "amplio"
    // --- Lo que llega y lo que se deriva ---
    readonly property var datos: tareas.api ? tareas.api.tareas : null
    readonly property var todas: Logica.entradas(tareas.datos)
    readonly property var listaAhora: Logica.ahora(tareas.todas)
    readonly property var listaGrupos: tareas.datos ? Logica.grupos(tareas.datos, tareas.vista, tareas.filtro, tareas.listaAhora.map((t) => {
        return t.linea;
    })) : []
    // El orden de j y k.
    readonly property var orden: Logica.recorrido(tareas.listaAhora, tareas.listaGrupos, (g) => {
        return tareas.estaPlegado(g);
    })
    readonly property var secciones: tareas.datos ? tareas.datos.secciones : []
    readonly property string hoy: tareas.datos ? tareas.datos.hoy : ""
    // --- Lo que se queda al repintar ---
    property string vista: "plazo"
    property string filtro: ""
    // Los grupos que se han plegado o desplegado a mano ({ clave: plegado }); el
    // resto, como empiezan: plegados «En pausa» y «Hechas».
    property var plegados: ({
    })
    // Los detalles abiertos, como { "a12": true } (ctx + línea).
    property var abiertos: ({
    })
    property var seleccion: ({
        "ctx": "",
        "linea": -1
    })
    property var edicion: ({
        "ctx": "",
        "linea": -1
    })
    property bool ayuda: false
    // --- Calendario (AgendaCalendario.qml): mes que se mira y día elegido ---
    property int calAnio: 2026
    property int calMes: 1
    property string calDia: ""
    property bool calendarioAbierto: false
    readonly property bool calendarioVisible: tareas.amplio || tareas.calendarioAbierto
    // --- Arrastrar tareas ---
    // La tarea que se lleva, o null. El fantasma (más abajo) la acompaña; las
    // zonas de soltar (días, semanas, grupos, la tira) llaman a soltarSobre.
    property var arrastrada: null
    property bool masOpciones: false
    // Cuántos editores hay abiertos (el de la tarea, el de los detalles, el de
    // una subtarea): con alguno, un cambio de fuera no repinta la lista.
    property int editores: 0
    // El teclado: solo con el cajón abierto, este bloque a la vista y con el
    // foco dentro.
    readonly property bool teclasActivas: tareas.shell.abierto && tareas.visible && tareas.activeFocus

    signal abrirWeb()

    function irAMes(anio, mes) {
        tareas.calAnio = anio;
        tareas.calMes = mes;
    }

    function cambiarMes(n) {
        const m = Logica.sumaMes(tareas.calAnio, tareas.calMes, n);
        tareas.irAMes(m.anio, m.mes);
    }

    function irAHoy() {
        const p = tareas.hoy !== "" ? tareas.hoy : Logica.aFecha(new Date().getFullYear(), new Date().getMonth() + 1, new Date().getDate());
        tareas.calDia = p;
        tareas.irAMes(+p.slice(0, 4), +p.slice(5, 7));
    }

    function empezarArrastre(t, escena) {
        tareas.arrastrada = t;
        tareas.moverArrastre(escena);
    }

    function moverArrastre(escena) {
        const p = tareas.mapFromItem(null, escena.x, escena.y);
        fantasma.x = p.x - 28;
        fantasma.y = p.y - fantasma.height - 6;
    }

    function soltarArrastre() {
        if (tareas.arrastrada === null)
            return ;

        fantasma.Drag.drop();
        tareas.arrastrada = null;
        tareas.enfocar();
    }

    // El cambio ({ fecha } | { seccion } | { prioridad }) de lo que se suelta.
    function soltarSobre(cambio) {
        const t = tareas.arrastrada;
        if (t && Logica.esCambio(t, cambio))
            tareas.api.editarTarea(t.id, cambio);

    }

    // Botones de la tarea (TareaDetalle): lo mismo, sin arrastrar.
    function cambiar(t, cambio) {
        if (Logica.esCambio(t, cambio))
            tareas.api.editarTarea(t.id, cambio);

    }

    function actualizar() {
        tareas.api.cargarTareas();
        tareas.api.cargarAvisosMovil();
    }

    // El foco de los atajos va a un item vacío de dentro, no al FocusScope: así,
    // si un campo lo tenía, lo pierde.
    function enfocar() {
        sumidero.forceActiveFocus();
    }

    function seleccionar(ctx, linea) {
        tareas.seleccion = {
            "ctx": ctx,
            "linea": linea
        };
        tareas.enfocar();
    }

    function alternar(ctx, linea) {
        const a = Object.assign({
        }, tareas.abiertos);
        const k = ctx + linea;
        if (a[k])
            delete a[k];
        else
            a[k] = true;
        tareas.abiertos = a;
    }

    function estaPlegado(g) {
        if (tareas.filtro !== "")
            return false;

        return g.clave in tareas.plegados ? tareas.plegados[g.clave] : g.tipo !== "normal";
    }

    function alternarGrupo(g) {
        const p = Object.assign({
        }, tareas.plegados);
        p[g.clave] = !tareas.estaPlegado(g);
        tareas.plegados = p;
    }

    function plegarTodo() {
        const alguno = tareas.listaGrupos.some((g) => {
            return !tareas.estaPlegado(g);
        });
        const p = {
        };
        for (const g of tareas.listaGrupos) p[g.clave] = alguno
        tareas.plegados = p;
    }

    function editor(n) {
        tareas.editores = Math.max(0, tareas.editores + n);
    }

    function marcar(t) {
        tareas.api.marcarTarea(t.id, !t.hecha);
    }

    function fijar(t) {
        tareas.api.editarTarea(t.id, {
            "fijada": !t.fijada
        });
    }

    // Una escritura de las filas (detalles, subtareas): la lista se repinta sola
    // con la respuesta.
    function guardar(t, cambios, alAcabar) {
        tareas.api.editarTarea(t.id, cambios, alAcabar);
    }

    function empezarEdicion(t) {
        const ctx = tareas.seleccion.linea === t.linea ? tareas.seleccion.ctx : (tareas.listaAhora.some((x) => {
            return x.linea === t.linea;
        }) ? "a" : "r");
        tareas.edicion = {
            "ctx": ctx,
            "linea": t.linea
        };
    }

    function terminarEdicion() {
        tareas.edicion = {
            "ctx": "",
            "linea": -1
        };
        tareas.enfocar();
    }

    // El editor guarda por aquí: si sale bien, se cierra (la respuesta ya ha
    // repintado la lista); si no, se queda abierto para corregirlo.
    function guardarEdicion(t, cambios) {
        tareas.api.editarTarea(t.id, cambios, (ok) => {
            if (ok)
                tareas.terminarEdicion();

        });
    }

    // La tarea elegida, o null.
    function elegida() {
        return tareas.todas.find((t) => {
            return t.linea === tareas.seleccion.linea;
        }) || null;
    }

    function moverSeleccion(d) {
        const o = tareas.orden;
        if (o.length === 0)
            return ;

        let i = o.findIndex((x) => {
            return x.ctx === tareas.seleccion.ctx && x.linea === tareas.seleccion.linea;
        });
        i = i < 0 ? (d > 0 ? 0 : o.length - 1) : Math.max(0, Math.min(o.length - 1, i + d));
        tareas.seleccion = o[i];
        Qt.callLater(tareas.verElegida);
    }

    // Que la tarea elegida quede a la vista.
    function verElegida() {
        let hallado = null;
        const buscar = (it) => {
            if (hallado)
                return ;

            if (it.ctx !== undefined && it.t !== undefined && it.ctx === tareas.seleccion.ctx && it.t.linea === tareas.seleccion.linea) {
                hallado = it;
                return ;
            }
            for (let k = 0; k < it.children.length; k++) buscar(it.children[k])
        };
        buscar(lista);
        if (!hallado)
            return ;

        const y = hallado.mapToItem(lista, 0, 0).y;
        if (y < desplazable.contentY)
            desplazable.contentY = Math.max(0, y - 8);
        else if (y + 40 > desplazable.contentY + desplazable.height)
            desplazable.contentY = Math.min(Math.max(0, desplazable.contentHeight - desplazable.height), y + 48 - desplazable.height);
    }

    function seccionPorDefecto() {
        const s = tareas.secciones.find((x) => {
            return x.id === "general";
        }) || tareas.secciones.find((x) => {
            return !x.pausa;
        }) || tareas.secciones[0];
        return s ? s.id : "";
    }

    // Que la sección elegida para la tarea nueva exista (al cargar, o si la
    // quitaron de la nota).
    function ajustarNueva() {
        if (!tareas.secciones.some((s) => {
            return s.id === opcionesNueva.seccion;
        }))
            opcionesNueva.seccion = tareas.seccionPorDefecto();

    }

    function anadir() {
        const texto = campoNueva.texto.trim();
        if (texto === "")
            return ;

        const datos = {
            "seccion": tareas.masOpciones ? opcionesNueva.seccion : tareas.seccionPorDefecto(),
            "texto": texto,
            "prioridad": tareas.masOpciones ? opcionesNueva.prioridad : "media"
        };
        if (tareas.masOpciones) {
            datos.area = opcionesNueva.area.trim();
            datos.fecha = opcionesNueva.fecha;
        }
        tareas.api.anadirTarea(datos, (ok) => {
            if (ok) {
                campoNueva.texto = "";
                opcionesNueva.fecha = "";
                opcionesNueva.area = "";
            }
        });
    }

    // La vista y los grupos plegados se recuerdan entre reinicios.
    onVistaChanged: recuerdo.guardar(tareas.vista, tareas.plegados)
    onPlegadosChanged: recuerdo.guardar(tareas.vista, tareas.plegados)
    onEditoresChanged: {
        if (tareas.api)
            tareas.api.editandoTarea = tareas.editores > 0;

    }
    Component.onDestruction: {
        if (tareas.api)
            tareas.api.editandoTarea = false;

    }
    // Al abrir el cajón o al volver a este bloque, el foco de aquí: lo de los
    // atajos. El teclado de verdad sigue siendo del cajón solo tras un clic.
    onVisibleChanged: {
        if (tareas.visible)
            Qt.callLater(tareas.enfocar);

    }
    // Si la tarea que se edita ya no está (otro la quitó), el editor se cierra.
    onDatosChanged: {
        tareas.ajustarNueva();
        if (tareas.calDia === "" && tareas.hoy !== "")
            tareas.irAHoy();

        if (tareas.edicion.linea >= 0 && !tareas.todas.some((t) => {
            return t.linea === tareas.edicion.linea;
        }))
            tareas.edicion = {
            "ctx": "",
            "linea": -1
        };

        if (tareas.seleccion.linea >= 0 && !tareas.todas.some((t) => {
            return t.linea === tareas.seleccion.linea;
        }))
            tareas.seleccion = {
            "ctx": "",
            "linea": -1
        };

    }
    Keys.onPressed: (event) => {
        if (!tareas.teclasActivas)
            return ;

        if (event.key === Qt.Key_Escape) {
            if (tareas.ayuda) {
                tareas.ayuda = false;
                event.accepted = true;
            } else if (tareas.edicion.linea >= 0) {
                tareas.terminarEdicion();
                event.accepted = true;
            } else if (tareas.seleccion.linea >= 0) {
                // Primero se pliega lo desplegado, luego se suelta la elegida.
                const k = tareas.seleccion.ctx + tareas.seleccion.linea;
                if (tareas.abiertos[k])
                    tareas.alternar(tareas.seleccion.ctx, tareas.seleccion.linea);
                else
                    tareas.seleccion = {
                    "ctx": "",
                    "linea": -1
                };
                event.accepted = true;
            }
            return ;
        }
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return ;

        const tecla = event.text;
        if (tecla === "?") {
            tareas.ayuda = !tareas.ayuda;
            event.accepted = true;
            return ;
        }
        // Con la ayuda a la vista o un editor abierto no se hace nada más.
        if (tareas.ayuda || tareas.edicion.linea >= 0)
            return ;

        if (tecla === "n") {
            event.accepted = true;
            campoNueva.enfocar();
        } else if (tecla === "/") {
            event.accepted = true;
            campoFiltro.enfocar();
        } else if (tecla === "j" || tecla === "k") {
            event.accepted = true;
            tareas.moverSeleccion(tecla === "j" ? 1 : -1);
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || tecla === "o") {
            if (tareas.seleccion.linea >= 0) {
                event.accepted = true;
                tareas.alternar(tareas.seleccion.ctx, tareas.seleccion.linea);
            }
        } else {
            const t = tareas.elegida();
            if (!t)
                return ;

            if (tecla === "x") {
                event.accepted = true;
                tareas.marcar(t);
            } else if (tecla === "p") {
                event.accepted = true;
                tareas.fijar(t);
            } else if (tecla === "e") {
                event.accepted = true;
                tareas.empezarEdicion(t);
            } else if (/^[1-5]$/.test(tecla)) {
                event.accepted = true;
                const nivel = Logica.NIVELES[+tecla - 1];
                if (nivel !== t.prioridad)
                    tareas.api.editarTarea(t.id, {
                    "prioridad": nivel
                });

            }
        }
    }
    Component.onCompleted: {
        tareas.ajustarNueva();
        // Creada ya con los datos (las secciones se crean al mirarlas): onDatosChanged
        // no salta, y el calendario se quedaría en enero.
        if (tareas.calDia === "" && tareas.hoy !== "")
            tareas.irAHoy();
    }

    TareasEstado {
        id: recuerdo

        objectName: "recuerdoTareas"
        onLeido: (vista, plegados) => {
            tareas.vista = vista;
            tareas.plegados = plegados;
        }
    }

    Connections {
        function onAbiertoChanged() {
            if (tareas.shell.abierto && tareas.visible)
                Qt.callLater(tareas.enfocar);

        }

        target: tareas.shell
    }

    Item {
        id: sumidero
    }

    RowLayout {
        anchors.fill: parent
        spacing: 14

        // En «amplio», el calendario a la izquierda.
        Flickable {
            id: lateral

            objectName: "calendarioLateral"
            Layout.preferredWidth: Math.max(260, Math.min(340, tareas.width * 0.42))
            Layout.fillHeight: true
            visible: tareas.amplio && tareas.datos !== null && tareas.datos.habilitado
            clip: true
            contentWidth: width
            contentHeight: calLateral.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            AgendaCalendario {
                id: calLateral

                width: lateral.width
                ctrl: tareas
                modo: tareas.modo
            }

        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // La conexión caída, como en Inicio: lo que haya se ve atenuado.
            RowLayout {
                Layout.fillWidth: true
                visible: tareas.lineaConexion !== ""
                spacing: 8

                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: Theme.muted
                }

                Text {
                    objectName: "lineaConexionTareas"
                    Layout.fillWidth: true
                    text: tareas.lineaConexion
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

            }

            // Sin datos todavía: cargando, o por qué no.
            RowLayout {
                Layout.fillWidth: true
                visible: tareas.datos === null && tareas.lineaConexion === ""
                spacing: 8

                Text {
                    objectName: "tareasSinDatos"
                    Layout.fillWidth: true
                    text: tareas.api && tareas.api.tareasError !== "" ? tareas.api.tareasError : "Cargando las tareas…"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                Chip {
                    objectName: "reintentarTareas"
                    visible: tareas.api && tareas.api.tareasError !== ""
                    texto: "Reintentar"
                    glifo: "\uf021"
                    onActivado: tareas.api.cargarTareas()
                }

            }

            Text {
                Layout.fillWidth: true
                visible: tareas.datos !== null && !tareas.datos.habilitado
                text: "Las tareas no están conectadas: falta «vault» en la configuración del panel."
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: tareas.datos !== null && tareas.datos.error !== ""
                text: tareas.datos ? tareas.datos.error : ""
                color: Theme.warn
                font.family: Theme.font
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            // --- Añadir ---
            ColumnLayout {
                Layout.fillWidth: true
                visible: tareas.datos !== null && tareas.datos.habilitado && tareas.secciones.length > 0
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Campo {
                        id: campoNueva

                        objectName: "campoNueva"
                        Layout.fillWidth: true
                        pista: "Añadir tarea…   ( n )"
                        onAceptado: tareas.anadir()
                        onCancelado: tareas.enfocar()
                    }

                    Chip {
                        objectName: "opcionesAnadir"
                        glifo: tareas.masOpciones ? "" : ""
                        activo: tareas.masOpciones
                        implicitWidth: 30
                        onActivado: tareas.masOpciones = !tareas.masOpciones
                    }

                    Chip {
                        objectName: "botonAnadir"
                        glifo: ""
                        activo: true
                        encendido: !tareas.api.tareasOcupado
                        implicitWidth: 30
                        onActivado: tareas.anadir()
                    }

                }

                Opciones {
                    id: opcionesNueva

                    objectName: "opcionesNueva"
                    Layout.fillWidth: true
                    visible: tareas.masOpciones
                    secciones: tareas.secciones
                    hoy: tareas.hoy
                    prioridad: "media"
                    onAceptado: tareas.anadir()
                    onCancelado: tareas.enfocar()
                }

            }

            // --- Vistas y filtro ---
            ColumnLayout {
                Layout.fillWidth: true
                visible: tareas.datos !== null && tareas.datos.habilitado
                spacing: 8

                // Cuántas hay abiertas y cuántas vencidas, como en la cabecera de la web.
                Text {
                    objectName: "cuentaTareas"
                    Layout.fillWidth: true
                    text: Logica.textoCuenta(Logica.resumenPlazos(tareas.todas))
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: Logica.VISTAS

                        delegate: Chip {
                            required property var modelData

                            objectName: "vista-" + modelData[0]
                            texto: modelData[1]
                            activo: tareas.vista === modelData[0]
                            onActivado: {
                                tareas.vista = modelData[0];
                                tareas.enfocar();
                            }
                        }

                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Chip {
                        objectName: "plegarTodo"
                        texto: tareas.listaGrupos.some((g) => {
                            return !tareas.estaPlegado(g);
                        }) ? "Contraer" : "Expandir"
                        onActivado: {
                            tareas.plegarTodo();
                            tareas.enfocar();
                        }
                    }

                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Campo {
                        id: campoFiltro

                        objectName: "campoFiltro"
                        Layout.fillWidth: true
                        pista: "Filtrar…   ( / )"
                        onTextoChanged: tareas.filtro = texto
                        // Escape vacía el filtro y, ya vacío, suelta el campo.
                        onCancelado: {
                            if (texto !== "")
                                texto = "";
                            else
                                tareas.enfocar();
                        }
                        onAceptado: tareas.enfocar()
                    }

                    Chip {
                        objectName: "actualizarTareas"
                        glifo: "\uf021"
                        implicitWidth: 30
                        encendido: !tareas.api.tareasOcupado
                        onActivado: {
                            tareas.actualizar();
                            tareas.enfocar();
                        }
                    }

                    Chip {
                        objectName: "verCalendario"
                        visible: !tareas.amplio
                        glifo: "\uf073"
                        implicitWidth: 30
                        activo: tareas.calendarioAbierto
                        onActivado: {
                            tareas.calendarioAbierto = !tareas.calendarioAbierto;
                            tareas.enfocar();
                        }
                    }

                    Chip {
                        objectName: "botonAyuda"
                        texto: "?"
                        implicitWidth: 30
                        onActivado: {
                            tareas.ayuda = !tareas.ayuda;
                            tareas.enfocar();
                        }
                    }

                }

            }

            // El calendario, encima de la lista, en compacto y medio.
            Item {
                Layout.fillWidth: true
                implicitHeight: calPleg.height
                visible: calPleg.abierto || calPleg.moviendo

                Plegable {
                    id: calPleg

                    width: parent.width
                    abierto: !tareas.amplio && tareas.calendarioAbierto && tareas.datos !== null && tareas.datos.habilitado

                    AgendaCalendario {
                        id: calArriba

                        width: parent.width
                        ctrl: tareas
                        modo: tareas.modo
                    }

                }

            }

            // --- Ahora y los grupos ---
            Flickable {
                id: desplazable

                objectName: "desplazableTareas"
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: tareas.datos !== null && tareas.datos.habilitado
                clip: true
                contentWidth: width
                contentHeight: lista.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: lista

                    width: desplazable.width
                    spacing: 8
                    // Con la conexión caída, atenuado: no está al día.
                    opacity: tareas.lineaConexion === "" ? 1 : 0.5

                    Etiqueta {
                        text: "AHORA"
                    }

                    Text {
                        objectName: "ahoraVacio"
                        visible: tareas.listaAhora.length === 0
                        text: tareas.todas.some((t) => {
                            return !t.hecha;
                        }) ? "Nada urgente ahora mismo." : "Sin tareas abiertas."
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Repeater {
                        model: tareas.listaAhora

                        delegate: TareaTarjeta {
                            required property var modelData

                            objectName: "tarjetaAhora"
                            t: modelData
                            ctrl: tareas
                            width: lista.width
                        }

                    }

                    Item {
                        width: 1
                        height: 4
                    }

                    Repeater {
                        model: tareas.listaGrupos

                        delegate: Column {
                            id: grupo

                            required property var modelData
                            readonly property bool plegado: tareas.estaPlegado(grupo.modelData)

                            objectName: "grupo-" + modelData.clave
                            width: lista.width
                            spacing: 2
                            opacity: grupo.modelData.tipo === "normal" ? 1 : 0.75

                            Rectangle {
                                objectName: "cabeceraGrupo"
                                width: parent.width
                                height: 30
                                radius: 8
                                color: cabDrop.containsDrag && cabDrop.cambio ? Qt.rgba(1, 1, 1, 0.22) : (sobreGrupo.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                scale: cabDrop.containsDrag && cabDrop.cambio ? 1.03 : 1

                                HoverHandler {
                                    id: sobreGrupo

                                    cursorShape: Qt.PointingHandCursor
                                }

                                // Soltar una tarea aquí le da lo que significa el grupo
                                // en esta vista: el plazo, el proyecto o la prioridad.
                                DropArea {
                                    id: cabDrop

                                    readonly property var cambio: Logica.cambioDeGrupo(tareas.vista, grupo.modelData, tareas.hoy)

                                    objectName: "soltarGrupo"
                                    anchors.fill: parent
                                    keys: ["tarea"]
                                    onDropped: (drop) => {
                                        if (cabDrop.cambio)
                                            tareas.soltarSobre(cabDrop.cambio);

                                    }
                                }

                                TapHandler {
                                    gesturePolicy: TapHandler.ReleaseWithinBounds
                                    onTapped: {
                                        tareas.alternarGrupo(grupo.modelData);
                                        tareas.enfocar();
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: grupo.plegado ? "" : ""
                                        color: Theme.faint
                                        font.family: Theme.font
                                        font.pixelSize: 9
                                    }

                                    // El cuadrado del proyecto o el punto de la prioridad.
                                    Rectangle {
                                        visible: grupo.modelData.cuadrado || grupo.modelData.punto !== "" || grupo.modelData.tipo === "pausa"
                                        implicitWidth: 8
                                        implicitHeight: 8
                                        radius: grupo.modelData.cuadrado ? 2 : 4
                                        color: grupo.modelData.tipo === "pausa" ? Theme.prioPausa : (grupo.modelData.cuadrado ? (grupo.modelData.color !== "" ? grupo.modelData.color : "transparent") : Theme.colorPrioridad(grupo.modelData.punto))
                                        border.width: grupo.modelData.cuadrado && grupo.modelData.color === "" ? 1 : 0
                                        border.color: Theme.muted
                                    }

                                    Text {
                                        text: grupo.modelData.titulo
                                        color: Theme.strong
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        text: grupo.modelData.items.length
                                        color: Theme.muted
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: grupo.modelData.resumen
                                        color: Theme.faint
                                        font.family: Theme.font
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }

                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: cabDrop.containsDrag ? Theme.animIn : Theme.animOut
                                        easing.type: cabDrop.containsDrag ? Easing.OutBack : Easing.InBack
                                        easing.overshoot: Theme.overshootIn
                                    }

                                }

                            }

                            Plegable {
                                width: parent.width
                                abierto: !grupo.plegado

                                Repeater {
                                    model: grupo.modelData.items

                                    delegate: TareaFila {
                                        required property var modelData

                                        t: modelData
                                        ctrl: tareas
                                        width: parent.width
                                    }

                                }

                                Text {
                                    visible: grupo.modelData.items.length === 0
                                    width: parent.width
                                    leftPadding: 10
                                    bottomPadding: 6
                                    text: grupo.modelData.vacio
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 11
                                }

                            }

                        }

                    }

                    Text {
                        objectName: "nadaCoincide"
                        visible: tareas.filtro !== "" && tareas.listaGrupos.length === 0
                        text: "Nada coincide con el filtro."
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    // Lo que el cajón no hace. El clic lo recoge el item de alrededor:
                    // un TapHandler dentro de un Text no recibe.
                    Item {
                        objectName: "enLaWeb"
                        width: parent.width
                        implicitHeight: textoWeb.implicitHeight + 6

                        Text {
                            id: textoWeb

                            y: 6
                            width: parent.width
                            text: "Borrar tareas, nuevas secciones y los colores de los proyectos: en la web"
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
                            onTapped: tareas.abrirWeb()
                        }

                    }

                }

            }

            // Sin datos, que lo de arriba no se estire.
            Item {
                Layout.fillHeight: true
                visible: !desplazable.visible
            }

        }

    }

    // Lo que se lleva puesto: vive aquí, no en la fila, porque la lista recorta.
    Rectangle {
        id: fantasma

        objectName: "fantasmaTarea"
        z: 80
        width: Math.min(220, tareas.width - 20)
        height: 28
        radius: 10
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.4)
        visible: opacity > 0.01
        opacity: tareas.arrastrada ? 0.96 : 0
        scale: tareas.arrastrada ? 1.04 : 0.6
        transformOrigin: Item.BottomLeft
        enabled: false
        Drag.active: tareas.arrastrada !== null
        Drag.dragType: Drag.Internal
        Drag.keys: ["tarea"]
        Drag.hotSpot.x: 28
        Drag.hotSpot.y: height + 6

        Text {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: Text.AlignVCenter
            text: tareas.arrastrada ? tareas.arrastrada.plano : ""
            color: Theme.strong
            font.family: Theme.font
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Behavior on scale {
            NumberAnimation {
                duration: tareas.arrastrada ? Theme.animIn : Theme.animOut
                easing.type: tareas.arrastrada ? Easing.OutBack : Easing.InBack
                easing.overshoot: tareas.arrastrada ? Theme.overshootIn : Theme.overshootOut
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: 160
            }

        }

    }

    // La tira de destinos rápidos: baja desde arriba mientras se arrastra, con
    // los siete próximos días, «+1 sem» y «Sin fecha». Con el calendario a la
    // vista no hace falta.
    Rectangle {
        id: tira

        readonly property bool saca: tareas.arrastrada !== null && !tareas.calendarioVisible

        objectName: "tiraDias"
        x: 0
        width: parent.width
        height: 58
        y: tira.saca ? 0 : -height - 12
        z: 60
        radius: 12
        color: Theme.glassDense
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.22)
        visible: y > -height

        Row {
            anchors.centerIn: parent
            spacing: 5

            Repeater {
                model: 7

                delegate: Destino {
                    required property int index
                    readonly property string f: Logica.fechaMasDias(tareas.hoy, index)

                    objectName: "destinoDia-" + index
                    etiqueta: index === 0 ? "hoy" : "" + Logica.partes(f).d
                    pie: index === 0 ? "" : Logica.DIAS_CORTOS[Logica.diaSemana(f)]
                    cambio: ({
                        "fecha": f
                    })
                }

            }

            Destino {
                objectName: "destinoSemana"
                width: 48
                etiqueta: "+1 s"
                pie: "semana"
                cambio: ({
                    "fecha": Logica.fechaMasDias(tareas.hoy, 7)
                })
            }

            Destino {
                objectName: "destinoSinFecha"
                width: 48
                etiqueta: "sin"
                pie: "fecha"
                cambio: ({
                    "fecha": ""
                })
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: tira.saca ? Theme.animIn : Theme.animOut
                easing.type: tira.saca ? Easing.OutBack : Easing.InBack
                easing.overshoot: tira.saca ? Theme.overshootIn : Theme.overshootOut
            }

        }

        component Destino: Rectangle {
            id: destino

            property string etiqueta: ""
            property string pie: ""
            property var cambio: null

            width: 44
            height: 42
            radius: 9
            color: zona.containsDrag ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.06)
            border.width: zona.containsDrag ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.6)
            scale: zona.containsDrag ? 1.14 : 1

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: destino.etiqueta
                    color: Theme.strong
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: destino.pie
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 8
                }

            }

            DropArea {
                id: zona

                anchors.fill: parent
                keys: ["tarea"]
                onDropped: (drop) => {
                    return tareas.soltarSobre(destino.cambio);
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: zona.containsDrag ? Theme.animIn : Theme.animOut
                    easing.type: zona.containsDrag ? Easing.OutBack : Easing.InBack
                    easing.overshoot: Theme.overshootIn
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }

            }

        }

    }

    AvisoMovilTarjeta {
        id: avisoMovil

        x: 10
        y: 10
        width: parent.width - 20
        api: tareas.api
    }

    TareasAyuda {
        objectName: "ayudaTareas"
        anchors.fill: parent
        visibleAyuda: tareas.ayuda
        onCerrar: {
            tareas.ayuda = false;
            tareas.enfocar();
        }
    }

    component Etiqueta: Text {
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10
        font.letterSpacing: 1.2
    }

}
