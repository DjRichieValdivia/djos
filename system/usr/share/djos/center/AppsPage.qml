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

    function install(a) {
        win.busyApp = a.name
        page.message = ""
        if (a.rpm)   // paquete de Fedora: PackageKit (sin contraseña para los administradores)
            djos.run("app:" + a.name, ["pkcon", "install", "-y", "--noninteractive", a.rpm])
        else if (a.pack)
            djos.run("app:" + a.name, ["/usr/libexec/djos/flatpak-audio", "plugins"].concat(a.flatpaks))
        else
            djos.run("app:" + a.name, ["/usr/libexec/djos/flatpak-audio", "install", a.flatpak])
    }
    function remove(a) {
        win.busyApp = a.name
        page.message = ""
        djos.run("app:" + a.name, ["/usr/libexec/djos/flatpak-audio", "remove"].concat(a.pack ? a.flatpaks : [a.flatpak]))
    }
    function open(a) {
        if (a.native)
            djos.launch(["kioclient", "exec", "/usr/share/applications/" + a.native])
        else
            djos.launch(["flatpak", "run", a.flatpak])
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
                delegate: StatusRow {
                    required property var modelData
                    iconName: modelData.icon
                    title: modelData.name
                    subtitle: modelData.desc

                    QQC2.BusyIndicator {
                        visible: win.busyApp === modelData.name
                        running: visible
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: implicitWidth
                    }
                    QQC2.Label {
                        visible: modelData.pack === true && modelData.installed && win.busyApp !== modelData.name
                        text: "Installed"
                        color: Kirigami.Theme.positiveTextColor
                    }
                    QQC2.Button {
                        visible: modelData.installed && !modelData.pack && win.busyApp !== modelData.name
                        icon.name: "media-playback-start"
                        text: "Open"
                        onClicked: page.open(modelData)
                    }
                    QQC2.Button {
                        visible: !modelData.installed && !modelData.included && win.busyApp !== modelData.name
                        enabled: win.busyApp === ""
                        icon.name: "download"
                        text: "Install"
                        onClicked: page.install(modelData)
                    }
                    QQC2.ToolButton {
                        visible: modelData.installed && !modelData.included && win.busyApp !== modelData.name
                        enabled: win.busyApp === ""
                        icon.name: "edit-delete"
                        display: QQC2.AbstractButton.IconOnly
                        text: "Remove"
                        QQC2.ToolTip.text: "Remove " + modelData.name
                        QQC2.ToolTip.visible: hovered
                        onClicked: page.remove(modelData)
                    }
                }
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
