/*
    DJOS Glass: pantalla de carga al iniciar sesión, como el arranque de un Mac: fondo negro, el logo de DJOS en blanco
    y una barra fina blanca (sin naranja: el acento de DJOS Glass es el azul, y la carga es neutra)
*/
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#000000"

    property int stage

    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        Component.onCompleted: opacity = 1

        Image {
            id: logo
            readonly property real size: Kirigami.Units.gridUnit * 6
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: Kirigami.Units.gridUnit * 0.5
            source: "file:///usr/share/icons/Papirus-Dark-DJOS/scalable/apps/djos-menu.svg"
            sourceSize.width: size
            sourceSize.height: size
            smooth: true
        }

        Rectangle {
            id: track
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: Kirigami.Units.gridUnit * 3
            width: Kirigami.Units.gridUnit * 10
            height: 4
            radius: 2
            color: "#2a2a2c"
            Rectangle {
                height: parent.height
                radius: parent.radius
                width: parent.width * Math.min(1, Math.max(0.06, root.stage / 6))
                color: "#f2f2f4"
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }
}
