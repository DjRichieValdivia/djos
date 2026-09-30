// Programas y plugins para DJ y producción: los incluidos y los que se instalan con un clic desde Flathub
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Apps & Plugins"
    subtitle: "Hand-picked tools for DJs and producers. They install with one click and update by themselves with the rest of the PC."

    property var apps: []
    property string message: ""
    property bool failed: false
    readonly property var categories: ["DJ", "Produce", "Plugins", "Edit & tag", "Record & stream", "Tools"]

    function refresh() { apps = JSON.parse(djos.catalog()) }
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
        visible: true
        type: Kirigami.MessageType.Information
        text: "Not sure which one to use? Which App? lists them by task: cut a track, fix tags, record a set…"
        actions: [
            Kirigami.Action {
                text: "Which App?"
                icon.name: "help-hint"
                onTriggered: win.go("guide")
            }
        ]
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: page.message.length > 0
        type: page.failed ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
        text: page.message
        showCloseButton: true
    }

    Repeater {
        model: page.categories
        delegate: Card {
            required property string modelData
            title: modelData
            Repeater {
                model: page.apps.filter(a => a.category === modelData)
                delegate: AppRow { app: modelData }
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.6
        text: "Looking for something else? Discover has thousands of apps, from Fedora and from Flathub."
    }
}
