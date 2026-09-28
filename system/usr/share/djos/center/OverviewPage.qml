// Resumen: cómo está todo de un vistazo
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Welcome to DJOS"
    subtitle: (win.sys.name || "DJOS") + (win.sys.version ? "  ·  " + win.sys.version : "")

    property var audio: ({ cards: [], rate: 48000, quantum: 256 })
    property string profile: "performance"
    property bool playing: false

    function refresh() {
        audio = JSON.parse(djos.audio())
        profile = djos.powerProfile()
        playing = djos.playing()
        win.refreshSystem()
    }
    Component.onCompleted: refresh()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.refresh() }

    readonly property var mainCard: audio.cards && audio.cards.length > 0 ? audio.cards[0] : null
    readonly property real latencyMs: audio.quantum / audio.rate * 1000

    GridLayout {
        Layout.fillWidth: true
        columns: page.width > Kirigami.Units.gridUnit * 44 ? 2 : 1
        columnSpacing: Kirigami.Units.largeSpacing * 1.5
        rowSpacing: Kirigami.Units.largeSpacing * 1.5

        Card {
            title: "Audio"
            StatusRow {
                iconName: page.mainCard && page.mainCard.usb ? "audio-card" : "audio-speakers"
                title: page.mainCard ? page.mainCard.name : "No sound card found"
                subtitle: (page.audio.rate / 1000) + " kHz  ·  " + page.audio.quantum + " samples  ·  "
                          + page.latencyMs.toFixed(1) + " ms"
                QQC2.Button { text: "Open"; flat: true; onClicked: win.go("audio") }
            }
        }
        Card {
            title: "Performance"
            StatusRow {
                iconName: "speedometer"
                title: page.profile === "performance" ? "Performance mode"
                     : page.profile === "balanced" ? "Balanced mode" : "Power saver mode"
                subtitle: page.playing ? "A set is playing: updates and maintenance are paused"
                                       : (page.profile === "performance" ? "Ready for a set" : "Switch to Performance before a set")
                warning: page.profile !== "performance" && !page.playing
                QQC2.Button { text: "Open"; flat: true; onClicked: win.go("performance") }
            }
        }
        Card {
            title: "Updates"
            StatusRow {
                iconName: win.updates.system && win.updates.system.staged ? "update-high" : "update-none"
                title: !win.updates.setup ? "Updates are not set up"
                     : win.updates.system && win.updates.system.staged ? "Update ready" : "Up to date"
                subtitle: !win.updates.setup ? "Connect this PC to your DJOS updates (only once)"
                        : win.updates.system && win.updates.system.staged ? "Restart to apply DJOS " + win.updates.system.staged
                        : "DJOS updates itself, and never during a set"
                warning: !win.updates.setup
                QQC2.Button { text: "Open"; flat: true; onClicked: win.go("updates") }
            }
        }
        Card {
            title: "Graphics"
            StatusRow {
                iconName: "video-display"
                title: win.sys.gpu || "Graphics card"
                warning: win.sys.nvidiaCard === true && !win.sys.nvidia
                subtitle: !win.sys.nvidiaCard ? "Using the open-source driver"
                        : win.sys.nvidia ? "NVIDIA driver " + win.sys.nvidia + " is running"
                        : win.sys.mokPending ? "Restart, choose Enroll MOK → Continue → Yes, type universalblue and Reboot. Until then only one monitor works."
                        : "The NVIDIA driver is not running. Restart once; if it keeps happening, check Updates."
            }
        }
    }

    Card {
        title: "Richie DJ"
        visible: win.sys.richiedj === true
        StatusRow {
            iconName: "richiedj"
            title: "Richie DJ"
            subtitle: "Installed and kept up to date by DJOS (never while you play)"
            QQC2.Button {
                icon.name: "media-playback-start"
                text: "Open Richie DJ"
                onClicked: djos.launch(["kioclient", "exec", "/usr/local/share/applications/richiedj.desktop"])
            }
        }
    }

    Card {
        title: "Quick actions"
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button { icon.name: "plasmadiscover"; text: "Get apps & plugins"; onClicked: win.go("apps") }
            QQC2.Button { icon.name: "drive-harddisk"; text: "Music disks"; onClicked: win.go("disks") }
            QQC2.Button { icon.name: "org.rncbc.qpwgraph"; text: "Audio connections"; onClicked: djos.launch(["qpwgraph"]) }
            QQC2.Button { icon.name: "run-build"; text: "Self-test this PC"; onClicked: djos.launch(["konsole", "--hide-menubar", "-e", "/usr/libexec/djos/selftest"]) }
            QQC2.Button { icon.name: "preferences-system"; text: "System Settings"; onClicked: djos.launch(["systemsettings"]) }
        }
    }
}
