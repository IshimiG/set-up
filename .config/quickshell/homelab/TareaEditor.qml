import QtQuick
import QtQuick.Layouts
import "shared"

// El formulario de editar una tarea, en el sitio de su fila o su tarjeta:
// el texto, el área, la sección, la prioridad y la fecha. Solo se manda lo que
// ha cambiado. Si la nota cambió en otro sitio mientras se escribía, el NUC
// contesta 409 y Api.qml recarga la lista y avisa: no se pisa nada.
ColumnLayout {
    id: editor

    required property var t
    required property var ctrl

    spacing: 8

    // Mientras está abierto, la lista no se repinta por cambios de fuera.
    Component.onCompleted: {
        editor.ctrl.editor(1);
        texto.enfocar();
    }
    Component.onDestruction: editor.ctrl.editor(-1)

    function guardar() {
        const nuevo = texto.texto.trim();
        if (nuevo === "") {
            opciones.error = "El texto no puede quedar vacío.";
            return;
        }
        if (opciones.fecha !== "" && !/^\d{4}-\d{2}-\d{2}$/.test(opciones.fecha)) {
            opciones.error = "La fecha es AAAA-MM-DD.";
            return;
        }
        const c = {};
        if (nuevo !== editor.t.texto)
            c.texto = nuevo;
        if (opciones.area.trim() !== editor.t.area)
            c.area = opciones.area.trim();
        if (opciones.fecha !== editor.t.vence)
            c.fecha = opciones.fecha;
        if (opciones.prioridad !== editor.t.prioridad)
            c.prioridad = opciones.prioridad;
        if (opciones.seccion !== editor.t.seccionId)
            c.seccion = opciones.seccion;
        if (Object.keys(c).length === 0) {
            editor.ctrl.terminarEdicion();
            return;
        }
        opciones.error = "";
        // Si sale bien, la lista nueva sustituye a esto y Tareas cierra el
        // editor; si no, se queda para corregir (un 409 ya lo ha recargado todo
        // y avisa). Lo cierra Tareas porque esto se reconstruye con la lista.
        editor.ctrl.guardarEdicion(editor.t, c);
    }

    Campo {
        id: texto

        objectName: "editorTexto"
        Layout.fillWidth: true
        texto: editor.t.texto
        pista: "La tarea"
        onAceptado: editor.guardar()
        onCancelado: editor.ctrl.terminarEdicion()
    }

    Opciones {
        id: opciones

        objectName: "editorOpciones"
        Layout.fillWidth: true
        secciones: editor.ctrl.secciones
        hoy: editor.ctrl.hoy
        seccion: editor.t.seccionId
        prioridad: editor.t.prioridad
        fecha: editor.t.vence
        Component.onCompleted: opciones.area = editor.t.area
        onAceptado: editor.guardar()
        onCancelado: editor.ctrl.terminarEdicion()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Item {
            Layout.fillWidth: true
        }

        Chip {
            objectName: "editorCancelar"
            texto: "Cancelar"
            onActivado: editor.ctrl.terminarEdicion()
        }

        Chip {
            objectName: "editorGuardar"
            texto: "Guardar"
            activo: true
            encendido: !editor.ctrl.api.tareasOcupado
            onActivado: editor.guardar()
        }
    }
}
