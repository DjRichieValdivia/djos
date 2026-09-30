// Fila: ícono, título, detalle (y una línea "Use it when…" opcional) y botones a la derecha
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: row
    property string iconName
    property string fallbackIcon: "applications-multimedia"   // si el tema no tiene el ícono (p. ej. un Flatpak sin instalar)
    property string title
    property string subtitle
    property string hint                                        // "cuándo usarlo", en el color de acento
    property bool warning: false
    default property alias actions: act.data
    Layout.fillWidth: true
    spacing: Kirigami.Units.largeSpacing

    Kirigami.Icon {
        source: row.warning ? "dialog-warning" : row.iconName
        fallback: row.fallbackIcon
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
        QQC2.Label {
            visible: row.hint.length > 0
            text: "Use it when " + row.hint
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: Kirigami.Theme.activeTextColor
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
    RowLayout { id: act; spacing: Kirigami.Units.smallSpacing; Layout.alignment: Qt.AlignVCenter }
}
