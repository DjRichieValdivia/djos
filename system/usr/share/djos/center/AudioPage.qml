// Audio: placas, frecuencia y buffer de PipeWire, lista de control de tiempo real
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Audio"
    subtitle: "Your sound cards, and how DJOS keeps the audio free of dropouts."

    property var audio: ({ cards: [], rate: 48000, quantum: 256, configuredRate: 48000, configuredQuantum: 256, irqThreads: [] })
    property string message: ""
    readonly property var rates: [44100, 48000, 88200, 96000]
    readonly property var quanta: [32, 64, 128, 256, 512, 1024]

    property var controllers: []
    property string ctlMessage: ""
    property bool ctlBusy: false
    function refresh() { audio = JSON.parse(djos.audio()); controllers = JSON.parse(djos.controllers()) }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.controllers = JSON.parse(djos.controllers()) }
    Connections {
        target: djos
        function onJobDone(tag, code, output) {
            if (tag !== "controller") return
            page.ctlBusy = false
            page.ctlMessage = output.trim()
            page.refresh()
        }
    }
    Component.onCompleted: {
        refresh()
        rateBox.currentIndex = Math.max(0, rates.indexOf(audio.configuredRate))
        bufBox.currentIndex = Math.max(0, quanta.indexOf(audio.configuredQuantum))
    }

    Card {
        title: "Sound cards"
        Repeater {
            model: page.audio.cards
            delegate: StatusRow {
                required property var modelData
                iconName: modelData.usb ? "audio-card" : modelData.hdmi ? "video-display" : "audio-speakers"
                title: modelData.name
                subtitle: modelData.usb ? "USB audio interface or DJ controller: gets top interrupt priority"
                        : modelData.hdmi ? "Monitor or TV audio (HDMI / DisplayPort)"
                        : "Motherboard audio"
            }
        }
        QQC2.Label {
            visible: page.audio.cards.length === 0
            text: "No sound cards found."
            opacity: 0.7
        }
    }

    Card {
        title: "DJ controller audio"
        visible: page.controllers.length > 0
        Repeater {
            model: page.controllers
            delegate: StatusRow {
                required property var modelData
                iconName: "audio-card"
                warning: !modelData.audio
                title: modelData.name + (modelData.audio ? (modelData.enabled ? ": audio on (compatible mode)" : ": audio on") : ": audio not supported by Linux yet")
                subtitle: modelData.audio
                          ? (modelData.enabled ? "Using the " + modelData.match + " recipe. If it sounds wrong, turn it off." : "")
                          : modelData.match.length > 0
                            ? "Its MIDI works. DJOS can drive its sound card with the recipe of the " + modelData.match
                              + " (same Pioneer family: " + modelData.out + " outputs, " + modelData.in + " inputs). Turn the master and headphone volume down before trying."
                            : "Its MIDI works, but no known recipe matches its sound card (" + modelData.out + " outputs, " + modelData.in + " inputs). Save the device info and send it so support can be added."
                QQC2.Button {
                    visible: !modelData.audio && modelData.match.length > 0
                    enabled: !page.ctlBusy
                    icon.name: "audio-card"
                    text: "Try compatible mode"
                    onClicked: { page.ctlBusy = true; djos.run("controller", ["pkexec", "/usr/libexec/djos/controller-audio", "enable", modelData.id]) }
                }
                QQC2.Button {
                    visible: modelData.enabled
                    enabled: !page.ctlBusy
                    text: "Turn off"
                    onClicked: { page.ctlBusy = true; djos.run("controller", ["pkexec", "/usr/libexec/djos/controller-audio", "disable", modelData.id]) }
                }
                QQC2.Button {
                    visible: !modelData.audio
                    icon.name: "document-save"
                    text: "Save device info"
                    onClicked: djos.run("controller", ["/usr/libexec/djos/controller-audio", "info"])
                }
            }
        }
        QQC2.Label {
            visible: page.ctlMessage.length > 0
            text: page.ctlMessage
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            color: Kirigami.Theme.positiveTextColor
        }
    }

    Card {
        title: "Desktop audio engine (PipeWire)"
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "Used by browsers, DAWs and most apps. Richie DJ in “ALSA Direct” mode talks to your card directly with its own buffer, so these settings don’t affect your sets."
        }
        GridLayout {
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: Kirigami.Units.largeSpacing
            QQC2.Label { text: "Sample rate" }
            QQC2.ComboBox {
                id: rateBox
                model: page.rates.map(r => (r / 1000) + " kHz")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 10
            }
            QQC2.Label { text: "Buffer size" }
            QQC2.ComboBox {
                id: bufBox
                model: page.quanta.map(q => q + " samples  (" + (q / page.rates[Math.max(0, rateBox.currentIndex)] * 1000).toFixed(1) + " ms)")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            }
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.65
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            text: "Smaller buffer means less delay but more work for the processor. 256 is safe for everything; use 64 or 128 to play instruments live through a DAW."
        }
        RowLayout {
            QQC2.Button {
                icon.name: "dialog-ok-apply"
                text: "Apply"
                onClicked: {
                    djos.setAudio(page.rates[rateBox.currentIndex], page.quanta[bufBox.currentIndex])
                    page.refresh()
                    page.message = "Applied: " + (page.rates[rateBox.currentIndex] / 1000) + " kHz, " + page.quanta[bufBox.currentIndex] + " samples."
                }
            }
            QQC2.Button {
                text: "DJOS default"
                flat: true
                onClicked: { rateBox.currentIndex = 1; bufBox.currentIndex = 3 }
            }
        }
        QQC2.Label { visible: page.message.length > 0; text: page.message; color: Kirigami.Theme.positiveTextColor }
    }

    Card {
        title: "Real-time checklist"
        Check {
            ok: page.audio.kernelRt === true
            text: "Low-latency kernel (full preemption, threaded interrupts)"
        }
        Check {
            ok: page.audio.rtLimits === true
            text: "Real-time priority and locked memory for audio apps"
            detail: ok ? "" : "Log out and back in once (your user was just added to the audio group)."
        }
        Check {
            ok: page.audio.irqThreads !== undefined && page.audio.irqThreads.length > 0
            text: ok ? "Sound card interrupts run at top priority" : "Connect your audio interface or controller"
            detail: ok ? page.audio.irqThreads.join(",  ") : "DJOS gives its USB port top priority as soon as you plug it in."
        }
        Check {
            ok: (page.audio.tuned || "").indexOf("djos") === 0
            text: "Processor tuned for audio (" + (page.audio.tuned || "unknown") + ")"
            detail: ok ? "" : "Switch to Performance mode on the Performance page."
        }
    }

    Card {
        title: "Tools"
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button { icon.name: "org.rncbc.qpwgraph"; text: "Audio & MIDI connections"; onClicked: djos.launch(["qpwgraph"]) }
            QQC2.Button { icon.name: "audio-volume-high"; text: "Sound settings"; onClicked: djos.launch(["systemsettings", "kcm_pulseaudio"]) }
            QQC2.Button {
                icon.name: "utilities-terminal"
                text: "Measure latency…"
                onClicked: djos.terminal("sudo djos-latency-test; echo; read -r -p 'Press Enter to close.' _")
            }
        }
    }
}
