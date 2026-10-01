// Resumen: cómo está todo de un vistazo
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Welcome to DJOS"
    subtitle: (win.sys.name || "Fedora Linux") + (win.sys.version ? "  ·  DJOS Optimizer " + win.sys.version : "")

    property var audio: ({ cards: [], rate: 48000, quantum: 256 })
    property var now: ({ outputs: [] })      // audio-now: lo que suena en cada placa, con la latencia de verdad
    property string profile: "performance"
    property bool playing: false

    function refresh() {
        audio = JSON.parse(djos.audio())
        try { now = JSON.parse(djos.audioNow()) } catch (e) { now = { outputs: [] } }
        profile = djos.powerProfile()
        playing = djos.playing()
        win.refreshSystem()
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: win.refreshUpdates() }
    Component.onCompleted: refresh()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.refresh() }

    // la placa que importa: la que usa Richie DJ (ALSA Direct) o la principal, con lo que suena ahora; si ninguna está
    // abierta, la primera placa con los valores de PipeWire
    readonly property var mainOut: {
        const o = now.outputs || []
        return o.find(x => x.owner !== "pipewire") || o.find(x => x.main) || o[0] || null
    }
    readonly property var mainCard: {
        const c = audio.cards || []
        return (mainOut ? c.find(x => x.index === mainOut.index) : null) || c[0] || null
    }
    readonly property real latencyMs: audio.quantum / audio.rate * 1000
    function khz(r) { return (r % 1000 === 0 ? r / 1000 : (r / 1000).toFixed(1)) + " kHz" }

    GridLayout {
        Layout.fillWidth: true
        columns: page.width > Kirigami.Units.gridUnit * 44 ? 2 : 1
        columnSpacing: Kirigami.Units.largeSpacing * 1.5
        rowSpacing: Kirigami.Units.largeSpacing * 1.5

        Card {
            Layout.fillHeight: true
            title: "Audio"
            StatusRow {
                iconName: page.mainCard && page.mainCard.usb ? "audio-card" : "audio-speakers"
                title: page.mainCard ? page.mainCard.name : "No sound card found"
                subtitle: page.mainOut ? page.khz(page.mainOut.rate) + "  ·  " + page.mainOut.bits + "-bit  ·  " + page.mainOut.ms + " ms"
                                         + (page.mainOut.owner === "pipewire" ? "" : "  ·  " + (/richie/i.test(page.mainOut.owner) ? "Richie DJ (ALSA Direct)" : page.mainOut.owner))
                                       : page.khz(page.audio.rate) + "  ·  " + page.audio.quantum + " samples  ·  " + page.latencyMs.toFixed(1) + " ms"
                QQC2.Button { text: "Open"; flat: true; onClicked: win.go("audio") }
            }
        }
        Card {
            Layout.fillHeight: true
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
            Layout.fillHeight: true
            title: "Updates"
            StatusRow {
                readonly property var u: win.updates
                readonly property bool releaseReady: !!(u.release && u.release.ready && !u.release.prepared)
                iconName: win.updatesReady || releaseReady ? "update-high" : "update-none"
                // lo listo para instalar (Fedora no necesita GitHub) va antes que el aviso de conectar GitHub
                title: win.updatesReady ? (u.release && u.release.prepared ? "Fedora " + u.release.available + " ready to install"
                                                                          : u.system.count + (u.system.count === 1 ? " update" : " updates") + " ready to install")
                     : !u.connected ? "Connect GitHub"
                     : win.updatesChecking ? "Checking for updates…"
                     : releaseReady ? "Fedora " + u.release.available + " is available"
                     : u.system && u.system.state === "error" ? "The last check failed"
                     : u.time > 0 ? "Up to date" : "Not checked yet"
                subtitle: win.updatesReady ? "Install them when you restart or shut down (from Updates)"
                        : !u.connected ? "A DJOS download needs GitHub access: connect this PC once"
                        : "DJOS prepares updates by itself, never during a set, and installs them only when you choose"
                warning: !u.connected || (u.system && u.system.state === "error")
                QQC2.Button { text: "Open"; flat: true; onClicked: win.go("updates") }
            }
        }
        Card {
            Layout.fillHeight: true
            title: "Graphics"
            StatusRow {
                iconName: "video-display"
                title: win.sys.gpu || "Graphics card"
                warning: win.sys.nvidiaCard === true && !win.sys.nvidia
                subtitle: !win.sys.nvidiaCard ? "Using the open-source driver"
                        : win.sys.nvidia ? "NVIDIA driver " + win.sys.nvidia + " is running"
                        : win.sys.mokPending ? "Restart; when the blue screen says \"Press any key\", press the space bar, then choose Enroll MOK → Continue → Yes, type the password djosdjos and choose Reboot. Until then only one monitor works."
                        : "The NVIDIA driver is not running. Restart once; if it keeps happening, run the DJOS Self-Test."
            }
        }
    }

    Card {
        title: "Richie DJ"
        visible: win.sys.richiedj === true
        StatusRow {
            iconName: "richiedj"
            title: "Richie DJ"
            subtitle: (win.sys.richiedjVersion ? "Version " + win.sys.richiedjVersion + ". " : "")
                      + "Kept up to date by DJOS (never while you play)"
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
