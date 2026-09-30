// "Which App?": qué app usar para cada cosa (guide.json), con la app lista para abrir o a un clic de instalarse
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Which App?"
    subtitle: "What you want to do, and the app for it. Apps marked Open are already on this PC; the rest install with one click."

    property var tasks: []
    property string message: ""
    property bool failed: false

    function refresh() { tasks = JSON.parse(djos.guide()) }
    Component.onCompleted: refresh()

    Connections {
        target: djos
        function onJobDone(tag, code, output) {
            if (tag.indexOf("app:") !== 0)
                return
            var name = tag.substring(4)
            win.busyApp = ""
            page.failed = code !== 0
            page.message = code === 0 ? name + ": done." : name + ": it didn't work. " + output.split("\n").filter(l => l.length > 0).slice(-1)[0]
            page.refresh()
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: page.message.length > 0
        type: page.failed ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
        text: page.message
        showCloseButton: true
    }

    Repeater {
        model: page.tasks
        delegate: Card {
            required property var modelData
            title: modelData.task
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                Kirigami.Icon {
                    source: modelData.icon
                    fallback: "help-hint"
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                    Layout.alignment: Qt.AlignTop
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: modelData.text
                }
            }
            Repeater {
                model: modelData.apps
                delegate: AppRow {
                    required property var modelData
                    app: modelData
                    compact: true
                }
            }
        }
    }
}
