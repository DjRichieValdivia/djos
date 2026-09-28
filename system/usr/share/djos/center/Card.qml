// Tarjeta: un bloque con título chico en mayúsculas
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Rectangle {
    id: card
    property string title
    default property alias content: inner.data
    Layout.fillWidth: true
    implicitHeight: box.implicitHeight + Kirigami.Units.largeSpacing * 3
    radius: Kirigami.Units.cornerRadius * 2
    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false
    color: Kirigami.Theme.backgroundColor
    border.width: 1
    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)

    ColumnLayout {
        id: box
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Kirigami.Units.largeSpacing * 1.5
        spacing: Kirigami.Units.largeSpacing
        QQC2.Label {
            visible: card.title.length > 0
            text: card.title.toUpperCase()
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
            font.letterSpacing: 1
            opacity: 0.55
        }
        ColumnLayout {
            id: inner
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
        }
    }
}
