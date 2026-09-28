// Página con título, subtítulo y contenido con desplazamiento
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC2.ScrollView {
    id: page
    property string title
    property string subtitle
    default property alias content: col.data
    contentWidth: availableWidth
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

    ColumnLayout {
        id: col
        x: Kirigami.Units.gridUnit * 1.5
        width: Math.min(page.availableWidth - Kirigami.Units.gridUnit * 3, Kirigami.Units.gridUnit * 50)
        spacing: Kirigami.Units.largeSpacing * 1.5

        Item { implicitHeight: Kirigami.Units.largeSpacing }
        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true
            Kirigami.Heading { text: page.title; level: 1; font.weight: Font.Bold }
            QQC2.Label {
                visible: page.subtitle.length > 0
                text: page.subtitle
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
