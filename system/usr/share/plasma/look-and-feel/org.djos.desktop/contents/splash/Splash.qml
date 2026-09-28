/*
    DJOS: pantalla de carga al iniciar sesión (logo + barra de progreso fina)
*/
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#08090b"

    property int stage

    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Component.onCompleted: opacity = 1

        Image {
            id: logo
            readonly property real size: Kirigami.Units.gridUnit * 7
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: Kirigami.Units.gridUnit
            source: "file:///usr/share/icons/hicolor/scalable/apps/djos.svg"
            sourceSize.width: size
            sourceSize.height: size
            smooth: true
        }

        Text {
            id: name
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: Kirigami.Units.largeSpacing
            text: "DJOS"
            color: "#e6e8eb"
            font.family: "Inter"
            font.weight: Font.ExtraBold
            font.pixelSize: Kirigami.Units.gridUnit * 2.4
            font.letterSpacing: Kirigami.Units.gridUnit * 0.12
        }

        Rectangle {
            id: track
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: name.bottom
            anchors.topMargin: Kirigami.Units.gridUnit * 2
            width: Kirigami.Units.gridUnit * 12
            height: 3
            radius: 1.5
            color: "#1e232b"
            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.min(1, Math.max(0.08, root.stage / 6))
                color: "#ff7a1a"
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }
}
