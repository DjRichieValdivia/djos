// Rendimiento: modo de energía y protección durante los sets
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Performance"
    subtitle: "How hard the processor works, and how DJOS protects your sets."

    property string profile: "performance"
    property bool playing: false
    function refresh() { profile = djos.powerProfile(); playing = djos.playing() }
    Component.onCompleted: refresh()
    Timer { interval: 4000; running: true; repeat: true; onTriggered: page.refresh() }

    Card {
        title: "Power mode"
        Repeater {
            model: [
                { key: "performance", name: "Performance", desc: "Processor always at full speed and ready. Best for sets and recording. Recommended." },
                { key: "balanced", name: "Balanced", desc: "Saves energy when idle. Fine for browsing and editing; switch back before a set." },
                { key: "power-saver", name: "Power saver", desc: "Lowest energy use. Not for playing live." }
            ]
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                QQC2.RadioButton {
                    checked: page.profile === modelData.key
                    Layout.alignment: Qt.AlignTop
                    onClicked: { djos.setPowerProfile(modelData.key); page.refresh() }
                }
                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    QQC2.Label { text: modelData.name; font.weight: Font.DemiBold }
                    QQC2.Label { text: modelData.desc; opacity: 0.7; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }
        }
    }

    Card {
        title: "Set protection"
        StatusRow {
            iconName: page.playing ? "media-playback-start" : "media-playback-stopped"
            title: page.playing ? "A set is playing" : "Nothing is playing right now"
            subtitle: "While Richie DJ is playing, DJOS pauses system updates, app updates and disk maintenance, and hides notifications over full-screen apps. Everything runs later, when you stop."
        }
    }

    Card {
        title: "Tools"
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button { icon.name: "utilities-system-monitor"; text: "System Monitor"; onClicked: djos.launch(["plasma-systemmonitor"]) }
            QQC2.Button { icon.name: "nvtop"; text: "GPU monitor"; onClicked: djos.terminal("nvtop") }
        }
    }
}
