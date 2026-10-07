import QtQuick
import QtQuick.Effects

// SDDM login screen in the desktop's own look: the desktop wallpaper, dark
// translucent glass with a white hairline edge, JetBrainsMono, and the same
// elastic motion as the Quickshell surfaces (OutBack in, InBack out).
//
// The palette and timings are copied from
// ~/.config/quickshell/shared/Theme.qml. They cannot be imported: the greeter
// runs as the "sddm" user from /usr/share/sddm/themes and has no access to the
// home directory. If the Theme changes, mirror it in the "Theme" block below.
//
// SDDM creates one instance of this file per monitor. Only the primary one
// gets the login card; the others show the wallpaper and the clock.
Item {
    id: root

    width: 1920
    height: 1080

    // --- Theme (mirror of shared/Theme.qml) ------------------------------
    readonly property color glassTop: Qt.rgba(0, 0, 0, 0.62)
    readonly property color glassBottom: Qt.rgba(0, 0, 0, 0.50)
    readonly property color edgeTop: Qt.rgba(1, 1, 1, 0.30)
    readonly property color edgeBottom: Qt.rgba(1, 1, 1, 0.08)
    readonly property color text: Qt.rgba(1, 1, 1, 0.78)
    readonly property color strong: "#ffffff"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.55)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.35)
    readonly property color rule: Qt.rgba(1, 1, 1, 0.12)
    readonly property color ok: "#6dc89e"
    readonly property color warn: "#e59625"
    readonly property color danger: "#e90b25"
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int animIn: 420
    readonly property int animOut: 300
    readonly property real overshootIn: 1.9
    readonly property real overshootOut: 1.5

    // SDDM exposes "primaryScreen" to each view; older versions do not, and
    // then every screen behaves as primary rather than none of them.
    readonly property bool primary: typeof primaryScreen === "undefined" ? true : primaryScreen

    readonly property var es: Qt.locale("es_ES")

    // --- State ------------------------------------------------------------
    // 0 → 1 once on start, drives the entrance of everything.
    property real shown: 0
    // Set on a successful login so the card can retreat before the session
    // takes the screen.
    property bool leaving: false
    property bool busy: false
    property string error: ""

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property var sessionNames: []

    // The user's login name and display name, read from the model through a
    // delegate: roles are only reachable by name inside one.
    property string userName: userModel.lastUser
    property string realName: ""

    Instantiator {
        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            Component.onCompleted: {
                if (name === root.userName || root.userName === "") {
                    root.userName = name;
                    root.realName = realName;
                }
            }
        }
    }

    Instantiator {
        model: sessionModel
        delegate: QtObject {
            required property int index
            required property string name
            Component.onCompleted: {
                const next = root.sessionNames.slice();
                next[index] = name;
                root.sessionNames = next;
            }
        }
    }

    Behavior on shown {
        NumberAnimation {
            duration: root.animIn
            easing.type: Easing.OutBack
            easing.overshoot: root.overshootIn
        }
    }

    Component.onCompleted: root.shown = 1

    function login() {
        if (root.busy || password.text === "")
            return;
        root.busy = true;
        root.error = "";
        sddm.login(root.userName, password.text, root.sessionIndex);
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.busy = false;
            root.error = "Contraseña incorrecta";
            password.text = "";
            shake.restart();
        }

        function onLoginSucceeded() {
            root.leaving = true;
        }
    }

    // --- Background -------------------------------------------------------
    Image {
        id: wallpaper

        anchors.fill: parent
        source: config.background || "background.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        // Starts slightly zoomed and settles, so the screen does not just
        // blink into existence.
        scale: 1.06 - 0.06 * Math.min(1, root.shown)
    }

    // Darker towards the bottom, where the card and the controls sit, and a
    // touch at the top behind the clock.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }

    // A blurred copy of the wallpaper, rendered once, that glass surfaces cut
    // their own window out of. This is what the compositor blur does on the
    // desktop; here there is no compositor, so it is done by hand.
    MultiEffect {
        id: blurred

        anchors.fill: wallpaper
        source: wallpaper
        scale: wallpaper.scale
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.1
        visible: false
        layer.enabled: true
    }

    // --- Glass ------------------------------------------------------------
    // A rounded pane of frosted wallpaper with the house hairline edge.
    component Glass: Item {
        id: glass

        property real radius: 16

        Item {
            id: frost

            anchors.fill: parent
            visible: false
            layer.enabled: true

            ShaderEffectSource {
                sourceItem: blurred
                // Where this pane sits over the wallpaper, so the frost lines
                // up with what is behind it. Read from the parent's x and y
                // (every Glass fills a direct child of root) rather than
                // mapToItem, which is not reactive and would keep whatever
                // position the pane had before layout finished.
                sourceRect: Qt.rect(glass.parent.x, glass.parent.y, glass.width, glass.height)
                width: glass.width
                height: glass.height
            }
        }

        Rectangle {
            id: shape

            anchors.fill: parent
            radius: glass.radius
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: frost
            maskEnabled: true
            maskSource: shape
        }

        Rectangle {
            anchors.fill: parent
            radius: glass.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: root.edgeTop }
                GradientStop { position: 1.0; color: root.edgeBottom }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: Math.max(0, glass.radius - 1)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.glassTop }
                    GradientStop { position: 1.0; color: root.glassBottom }
                }
            }
        }
    }

    // --- Clock ------------------------------------------------------------
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Column {
        id: clock

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.16
        spacing: 2

        opacity: Math.min(1, root.shown) * (root.leaving ? 0 : 1)
        transform: Translate {
            y: -(1 - root.shown) * 60
        }

        Behavior on opacity {
            NumberAnimation { duration: root.animOut; easing.type: Easing.InBack }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm")
            color: root.strong
            font.family: root.font
            font.pixelSize: Math.round(root.height * 0.13)
            font.weight: Font.Light
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            // Capitalised by hand: Spanish day names come lower-case.
            text: {
                const s = root.es.toString(root.now, "dddd, d 'de' MMMM");
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            color: root.text
            font.family: root.font
            font.pixelSize: Math.round(root.height * 0.022)
        }
    }

    // --- Login card -------------------------------------------------------
    Item {
        id: card

        visible: root.primary
        width: 380
        height: form.implicitHeight + 44
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.58

        property real shakeX: 0

        opacity: Math.min(1, Math.max(0, root.shown))
        scale: root.leaving ? 0.9 : 0.85 + 0.15 * root.shown
        transform: Translate {
            x: card.shakeX
        }

        Behavior on scale {
            enabled: root.leaving
            NumberAnimation {
                duration: root.animOut
                easing.type: Easing.InBack
                easing.overshoot: root.overshootOut
            }
        }

        states: State {
            when: root.leaving
            PropertyChanges { card.opacity: 0 }
        }
        transitions: Transition {
            NumberAnimation { property: "opacity"; duration: root.animOut; easing.type: Easing.InCubic }
        }

        // A head shake: out, back past the middle, and settling, like the
        // OutBack bounce but sideways.
        SequentialAnimation {
            id: shake
            NumberAnimation { target: card; property: "shakeX"; to: -14; duration: 60; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "shakeX"; to: 12; duration: 90; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shakeX"; to: -8; duration: 80; easing.type: Easing.InOutQuad }
            NumberAnimation { target: card; property: "shakeX"; to: 0; duration: 160; easing.type: Easing.OutBack; easing.overshoot: root.overshootIn }
        }

        Glass {
            anchors.fill: parent
            radius: 16
        }

        Column {
            id: form

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 14

            Column {
                spacing: 2

                Text {
                    text: root.realName !== "" ? root.realName : root.userName
                    color: root.strong
                    font.family: root.font
                    font.pixelSize: 18
                }

                Text {
                    text: sddm.hostName ? root.userName + "@" + sddm.hostName : root.userName
                    color: root.muted
                    font.family: root.font
                    font.pixelSize: 11
                }
            }

            // Password pill.
            Rectangle {
                id: field

                width: parent.width
                height: 40
                radius: 10
                color: Qt.rgba(1, 1, 1, password.activeFocus ? 0.10 : 0.06)
                border.width: 1
                border.color: root.error !== "" ? Qt.rgba(0.91, 0.04, 0.15, 0.7) : (password.activeFocus ? Qt.rgba(1, 1, 1, 0.28) : root.rule)

                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰌾"
                    color: root.muted
                    font.family: root.font
                    font.pixelSize: 13
                }

                TextInput {
                    id: password

                    anchors.left: parent.left
                    anchors.leftMargin: 38
                    anchors.right: go.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter

                    focus: root.primary
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.strong
                    selectionColor: Qt.rgba(1, 1, 1, 0.25)
                    font.family: root.font
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    clip: true
                    enabled: !root.busy

                    onTextEdited: root.error = ""
                    onAccepted: root.login()
                    Keys.onEscapePressed: text = ""

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: password.text === ""
                        text: "Contraseña"
                        color: root.faint
                        font.family: root.font
                        font.pixelSize: 13
                    }
                }

                // Enter button: an arrow that only lights up once there is
                // something to send.
                Rectangle {
                    id: go

                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: 8
                    color: goArea.containsMouse && password.text !== "" ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                    scale: goArea.pressed ? 0.9 : 1

                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: root.overshootIn } }

                    Text {
                        anchors.centerIn: parent
                        text: root.busy ? "󰔟" : "󰁔"
                        color: password.text !== "" ? root.strong : root.faint
                        font.family: root.font
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: goArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.login()
                    }
                }
            }

            // Error, or caps lock, or nothing. One line so the card never
            // changes height.
            Text {
                width: parent.width
                text: root.error !== "" ? root.error : (keyboard.capsLock ? "󰪛  Bloq Mayús activado" : "")
                color: root.error !== "" ? root.danger : root.warn
                font.family: root.font
                font.pixelSize: 11
                opacity: text === "" ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }
        }
    }

    // --- Session and power ------------------------------------------------
    // One pill in the bottom-right corner, like the right-hand block of the
    // bar: small glyphs that brighten on hover and show their name.
    component Chip: Item {
        id: chip

        property string glyph: ""
        property string label: ""
        property bool showLabel: false
        signal clicked

        implicitWidth: row.implicitWidth + 16
        implicitHeight: 30

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            Behavior on color { ColorAnimation { duration: 140 } }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: chip.glyph
                color: area.containsMouse ? root.strong : root.text
                font.family: root.font
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                visible: chip.showLabel
                text: chip.label
                color: area.containsMouse ? root.strong : root.text
                font.family: root.font
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        scale: area.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: root.overshootIn } }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
            onContainsMouseChanged: {
                if (containsMouse && !chip.showLabel) {
                    root.hintFrom = chip;
                    root.hint = chip.label;
                }
                else if (root.hint === chip.label)
                    root.hint = "";
            }
        }
    }

    property string hint: ""
    property Item hintFrom: null

    Item {
        id: dock

        visible: root.primary
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        width: dockRow.implicitWidth + 12
        height: 40

        opacity: Math.min(1, Math.max(0, root.shown)) * (root.leaving ? 0 : 1)
        transform: Translate {
            y: (1 - root.shown) * 60
        }
        Behavior on opacity {
            NumberAnimation { duration: root.animOut }
        }

        Glass {
            anchors.fill: parent
            radius: 10
        }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 2

            Chip {
                visible: root.sessionNames.length > 0
                glyph: ""
                label: root.sessionNames[root.sessionIndex] || ""
                showLabel: true
                // Cycles through the installed sessions; there are rarely
                // more than two, so a menu would be more ceremony than use.
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, sessionModel.rowCount())
            }

            Rectangle {
                width: 1
                height: 18
                color: root.rule
                anchors.verticalCenter: parent.verticalCenter
            }

            Chip {
                visible: sddm.canSuspend
                glyph: "󰒲"
                label: "Suspender"
                onClicked: sddm.suspend()
            }

            Chip {
                visible: sddm.canReboot
                glyph: "󰜉"
                label: "Reiniciar"
                onClicked: sddm.reboot()
            }

            Chip {
                visible: sddm.canPowerOff
                glyph: "󰐥"
                label: "Apagar"
                onClicked: sddm.powerOff()
            }
        }
    }

    // The tooltip for the power glyphs, centred above the one being hovered
    // and kept inside the screen.
    Rectangle {
        id: tip

        visible: root.primary
        anchors.bottom: dock.top
        anchors.bottomMargin: 8
        x: {
            // Read explicitly so the binding re-runs when the pill moves;
            // mapToItem on its own is not reactive.
            const dockX = dock.x, dockW = dock.width;
            const from = root.hintFrom;
            if (!from)
                return dockX + dockW - tip.width;
            const centre = from.mapToItem(root, from.width / 2, 0).x;
            return Math.round(Math.min(root.width - 12 - tip.width, centre - tip.width / 2));
        }
        width: hintText.implicitWidth + 20
        height: hintText.implicitHeight + 12
        radius: 8
        color: root.glassTop
        border.width: 1
        border.color: root.rule
        opacity: root.hint !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Text {
            id: hintText
            anchors.centerIn: parent
            text: root.hint
            color: root.text
            font.family: root.font
            font.pixelSize: 11
        }
    }
}
