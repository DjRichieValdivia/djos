// Fila: ícono, título, detalle y botones a la derecha
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: row
    property string iconName
    property string title
    property string subtitle
    property bool warning: false
    default property alias actions: act.data
    Layout.fillWidth: true
    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        source: row.warning ? "dialog-warning" : row.iconName
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: implicitWidth
        Layout.alignment: Qt.AlignTop
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        QQC2.Label { text: row.title; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
        QQC2.Label {
            visible: row.subtitle.length > 0
            text: row.subtitle
            opacity: 0.72
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: row.warning ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
        }
    }
    RowLayout { id: act; spacing: Kirigami.Units.smallSpacing; Layout.alignment: Qt.AlignVCenter }
}
