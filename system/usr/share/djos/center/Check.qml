// Punto de una lista de control: tilde verde o aviso
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

RowLayout {
    id: chk
    property bool ok
    property string text
    property string detail
    Layout.fillWidth: true
    spacing: Kirigami.Units.largeSpacing
    Kirigami.Icon {
        source: chk.ok ? "emblem-ok-symbolic" : "emblem-important-symbolic"
        color: chk.ok ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.neutralTextColor
        isMask: true
        implicitWidth: Kirigami.Units.iconSizes.smallMedium
        implicitHeight: implicitWidth
        Layout.alignment: Qt.AlignTop
    }
    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        QQC2.Label { text: chk.text; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        QQC2.Label {
            visible: chk.detail.length > 0
            text: chk.detail
            opacity: 0.65
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
