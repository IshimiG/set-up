import QtQuick

// Una Api.qml falsa para la prueba: cumple el contrato de la fase 2 entero
// (propiedades, señal y funciones) con datos inventados. La prueba cambia las
// propiedades a mano, y las llamadas a refrescar/marcarVista quedan apuntadas.
QtObject {
    id: api

    property string conexion: "conectado"
    property string usuario: "portatil"
    property var permisos: ({
            acciones_docker: false,
            login_traderepublic: false
        })
    property var alertas: [
        {
            id: "a1",
            nivel: "error",
            titulo: "Contenedor caído: caddy",
            detalle: "caddy lleva 3 minutos parado",
            desde: new Date(Date.now() - 12 * 60000),
            vista: false
        },
        {
            id: "a2",
            nivel: "warn",
            titulo: "Disco al 85 % en /srv",
            detalle: "Quedan 40 GB libres",
            desde: new Date(Date.now() - 3 * 3600000),
            vista: false
        },
        {
            id: "a3",
            nivel: "warn",
            titulo: "Copia de seguridad lenta",
            detalle: "",
            desde: new Date(Date.now() - 2 * 86400000),
            vista: true
        }
    ]
    property string nivelAlertas: "error"
    property var servidor: ({
            enMarcha: 8,
            total: 9,
            problemas: 1
        })
    property var inicio: ({
            hoy: "martes 20 de octubre",
            semana: "semana 43",
            metaPorcentaje: 34,
            tareas: [
                {
                    texto: "Entrega de prueba con fecha",
                    seccion: "Clase",
                    color: "#b48cff",
                    prioridad: "maxima",
                    cuando: "vencida hace 2 días",
                    vencida: true
                },
                {
                    texto: "Revisar la copia de seguridad",
                    seccion: "Homelab",
                    color: "#6aa8ff",
                    prioridad: "alta",
                    cuando: "hoy",
                    vencida: false
                },
                {
                    texto: "Una tarea sin proyecto",
                    seccion: "General",
                    color: "",
                    prioridad: "media",
                    cuando: "mañana",
                    vencida: false
                }
            ]
        })
    property var inicioCargado: new Date()
    property string error: ""
    property string baseUrl: "https://panel.prueba.invalid"

    signal alertaNueva(var alerta)

    // Lo que ha pasado, para que la prueba lo mire.
    property int refrescos: 0
    property var vistas: []
    property var abiertas: []

    function refrescar() {
        api.refrescos++;
    }

    function marcarVista(id) {
        api.vistas = api.vistas.concat([id]);
    }

    function urlWeb(ruta) {
        return api.baseUrl + "/" + ruta;
    }
}
