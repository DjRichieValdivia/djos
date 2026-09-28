// Discos de música: los discos conectados y los que DJOS deja siempre disponibles (solo lectura)
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Music Disks"
    subtitle: "Keep your music disks (also the Windows ones) always available, read-only: DJOS never changes your music."

    property var disks: []
    function refresh() { disks = JSON.parse(djos.disks()) }
    Component.onCompleted: refresh()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.refresh() }

    function human(bytes) {
        var u = ["B", "KB", "MB", "GB", "TB"], i = 0
        while (bytes >= 1000 && i < u.length - 1) { bytes /= 1000; ++i }
        return (i >= 3 ? bytes.toFixed(1) : Math.round(bytes)) + " " + u[i]
    }

    Card {
        title: "Disks"
        Repeater {
            model: page.disks
            delegate: StatusRow {
                required property var modelData
                iconName: modelData.usb ? "drive-removable-media-usb" : "drive-harddisk"
                title: (modelData.label || modelData.model || modelData.path) + "  ·  " + page.human(modelData.size)
                subtitle: (modelData.music ? "Music disk, always at " + modelData.music
                           : modelData.mounted ? "Open at " + modelData.mounted : "Not set up")
                          + "  ·  " + modelData.fs.toUpperCase() + (modelData.model ? "  ·  " + modelData.model : "")
                QQC2.Button {
                    visible: (modelData.music || modelData.mounted).length > 0
                    icon.name: "document-open-folder"
                    text: "Open"
                    onClicked: djos.launch(["dolphin", modelData.music || modelData.mounted])
                }
            }
        }
        QQC2.Label { visible: page.disks.length === 0; text: "No other disks found."; opacity: 0.7 }
        RowLayout {
            QQC2.Button {
                icon.name: "configure"
                text: "Set up music disks…"
                onClicked: djos.launch(["konsole", "-e", "/usr/libexec/djos/setup-music-disk"])
            }
        }
    }

    Card {
        title: "USB sticks for CDJs / XDJs"
        StatusRow {
            iconName: "drive-removable-media-usb"
            title: "Prepare a USB stick"
            subtitle: "Pioneer players read FAT32 (and exFAT on newer models). Format the stick with Partition Manager, then export your playlists from Richie DJ."
            QQC2.Button {
                icon.name: "partitionmanager"
                text: "Partition Manager"
                onClicked: djos.launch(["partitionmanager"])
            }
        }
    }
}
