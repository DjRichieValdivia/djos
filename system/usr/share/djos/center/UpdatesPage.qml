// Actualizaciones: sistema, Richie DJ, programas de Flathub y de Arch
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Updates"
    subtitle: "DJOS downloads updates by itself and applies them the next time you restart. Never during a set."

    property bool updatingApps: false
    readonly property bool systemReady: !!(win.updates.system && win.updates.system.staged)

    function appText(state) {
        switch (state) {
        case "up-to-date": return "Up to date"
        case "updated":    return "Updated to the latest version"
        case "ready":      return "New version downloaded: it installs when you close it"
        case "waiting":    return "New version available: it downloads when you're not playing"
        case "unreachable":return "Can't check right now (no internet?)"
        case "error":      return "The last update failed. Try Check now"
        }
        return "Not checked yet"
    }

    Connections {
        target: djos
        function onJobDone(tag, code, output) {
            if (tag === "flatpak-update") { page.updatingApps = false; win.refreshUpdates() }
        }
    }
    Component.onCompleted: win.refreshUpdates()

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: !win.updates.setup
        type: Kirigami.MessageType.Warning
        text: "Updates are not set up yet. Connect this PC to your DJOS updates (only once)."
        actions: [
            Kirigami.Action {
                text: "Set up"
                icon.name: "configure"
                onTriggered: djos.launch(["konsole", "-e", "/usr/libexec/djos/setup-updates"])
            }
        ]
    }

    Card {
        title: "DJOS"
        StatusRow {
            iconName: page.systemReady ? "update-high" : "update-none"
            title: page.systemReady ? "Update downloaded" : "Up to date"
            subtitle: page.systemReady ? "DJOS " + win.updates.system.staged + " is applied when you restart."
                                       : "Running " + (win.updates.system ? win.updates.system.booted : "")
            QQC2.Button {
                visible: page.systemReady
                icon.name: "system-reboot"
                text: "Restart now"
                onClicked: djos.launch(["busctl", "--user", "call", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptReboot"])
            }
            QQC2.Button {
                icon.name: "view-refresh"
                text: win.checkingUpdates ? "Checking…" : "Check now"
                enabled: !win.checkingUpdates && win.updates.setup
                onClicked: { win.checkingUpdates = true; djos.run("check", ["pkexec", "/usr/libexec/djos/update", "--root", "check"]) }
            }
        }
        QQC2.BusyIndicator { visible: win.checkingUpdates; running: visible; Layout.alignment: Qt.AlignHCenter }
        StatusRow {
            visible: (win.sys.newVersion || "").length > 0
            iconName: "system-upgrade"
            title: "DJOS " + win.sys.newVersion + " is available"
            subtitle: "A new Fedora release, already tested by others for 4 weeks. It downloads now and is applied when you restart; the current version stays in the boot menu just in case."
            QQC2.Button {
                icon.name: "system-upgrade"
                text: "Upgrade"
                onClicked: djos.launch(["konsole", "-e", "/usr/libexec/djos/update", "major"])
            }
        }
    }

    Card {
        title: "Your apps"
        visible: (win.updates.apps || []).length > 0
        Repeater {
            model: win.updates.apps || []
            delegate: StatusRow {
                required property var modelData
                iconName: modelData.id === "richiedj" ? "richiedj" : "application-x-executable"
                title: modelData.name
                subtitle: page.appText(modelData.state)
            }
        }
    }

    Card {
        title: "Other apps"
        StatusRow {
            iconName: "plasmadiscover"
            title: "Apps from Flathub"
            subtitle: page.updatingApps ? "Updating…"
                    : win.updates.flatpak > 0 ? win.updates.flatpak + (win.updates.flatpak === 1 ? " update available" : " updates available")
                    : "Up to date (they also update by themselves every day)"
            QQC2.Button {
                visible: win.updates.flatpak > 0 && !page.updatingApps
                icon.name: "update-none"
                text: "Update"
                onClicked: { page.updatingApps = true; djos.run("flatpak-update", ["flatpak", "update", "-y", "--noninteractive"]) }
            }
        }
        StatusRow {
            iconName: "utilities-terminal"
            title: "Apps from Arch (paru)"
            subtitle: "Updates in a terminal window"
            QQC2.Button {
                icon.name: "update-none"
                text: "Update"
                onClicked: djos.launch(["konsole", "-e", "paru", "-Syu"])
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        opacity: 0.6
        wrapMode: Text.WordWrap
        visible: win.updates.checked > 0
        text: "Last check: " + new Date(win.updates.checked * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
    }
}
