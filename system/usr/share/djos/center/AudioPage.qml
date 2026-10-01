// Audio: las placas (la principal, y para cada una la frecuencia, el buffer y el margen con la latencia que da),
// los valores por defecto de PipeWire, las controladoras DJ y la lista de control de tiempo real
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Audio"
    subtitle: "Your sound cards, and how DJOS keeps the audio free of dropouts."

    property var audio: ({ cards: [], rate: 48000, quantum: 256, configuredRate: 48000, configuredQuantum: 256, followRate: false, irqThreads: [] })
    property string message: ""
    readonly property var rates: [44100, 48000, 88200, 96000]
    readonly property var quanta: [32, 64, 128, 256, 512, 1024]

    property var controllers: []
    property string ctlMessage: ""
    property bool ctlBusy: false
    function refresh() { audio = JSON.parse(djos.audio()); controllers = JSON.parse(djos.controllers()) }

    // ---------------------------------------------------------------- placas
    property var sc: ({ outputs: [], inputs: [], main: "", systemRate: 48000, systemBuffer: 256, set: false })
    property var choices: ({})      // node.name → { rate, buffer, headroom } (0 / -1 = lo del sistema)
    property string mainOut: ""
    property string mainIn: ""
    property bool scDirty: false
    property bool scBusy: false
    property string scMessage: ""
    function loadCards() {
        sc = JSON.parse(djos.soundCards())
        const ch = {}
        for (const o of sc.outputs) {
            const st = o.settings || {}
            ch[o.name] = { rate: st.rate || 0, buffer: st.buffer || 0, headroom: st.headroom !== undefined ? st.headroom : -1 }
        }
        choices = ch
        const mo = sc.outputs.find(o => o.isDefault)
        const mi = sc.inputs.find(i => i.isDefault)
        mainOut = mo ? mo.name : ""
        mainIn = mi ? mi.name : ""
        scDirty = false
    }
    function choose(name, key, value) {
        const c = Object.assign({}, choices)
        c[name] = Object.assign({}, c[name] || { rate: 0, buffer: 0, headroom: -1 })
        c[name][key] = value
        choices = c
        scDirty = true
    }
    // lo que tarda en salir el sonido por esa placa con esa combinación (buffer + margen de PipeWire)
    function latency(o) {
        const c = choices[o.name] || {}
        const rate = c.rate || sc.systemRate
        const buf = c.buffer || sc.systemBuffer
        const hr = c.headroom >= 0 ? c.headroom : o.headroom
        // el margen de PipeWire se sabe recién cuando la placa se abre (en las USB suele ser 1024)
        const unknown = c.headroom < 0 && o.headroom === 0 && o.usb
        return (unknown ? "≥ " : "") + ((buf + hr) / rate * 1000).toFixed(1)
    }
    function khz(r) { return (r % 1000 === 0 ? r / 1000 : (r / 1000).toFixed(1)) + " kHz" }
    function liveOf(cardIndex) {
        const c = (audio.cards || []).find(x => x.index === cardIndex)
        return c ? c.live : null
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: page.controllers = JSON.parse(djos.controllers()) }
    // lo que cada placa está usando ahora (cambia cuando un programa la abre o la cierra)
    Timer {
        interval: 2000; running: page.visible; repeat: true
        onTriggered: { const a = page.audio; a.cards = JSON.parse(djos.cards()); page.audio = a }
    }
    function liveText(live) {
        const parts = []
        for (const kind of ["playback", "capture"]) {
            const l = live ? live[kind] : null
            if (!l) continue
            parts.push((kind === "playback" ? "Output" : "Input") + " now: " + (l.rate / 1000) + " kHz, " + l.bits + "-bit, "
                       + l.channels + " ch, used by " + l.owner)
        }
        return parts.length > 0 ? parts.join("   ·   ") : "Not in use right now"
    }
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
        loadCards()
        rateBox.currentIndex = Math.max(0, rates.indexOf(audio.configuredRate))
        bufBox.currentIndex = Math.max(0, quanta.indexOf(audio.configuredQuantum))
        followBox.checked = audio.followRate === true
    }

    Card {
        title: "Sound cards"
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "The main card is where your apps play. Each card can run at its own sample rate and buffer while it plays (no conversion); the latency is what you hear after you press a key. Richie DJ in “ALSA Direct” mode opens the card with its own settings."
        }
        QQC2.ButtonGroup { id: mainGroup }
        Repeater {
            model: page.sc.outputs
            delegate: ColumnLayout {
                id: cardRow
                required property var modelData
                required property int index
                readonly property var ch: page.choices[modelData.name] || { rate: 0, buffer: 0, headroom: -1 }
                readonly property bool isMain: page.mainOut === modelData.name
                Layout.fillWidth: true
                Layout.topMargin: index > 0 ? Kirigami.Units.largeSpacing : 0
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Separator { Layout.fillWidth: true; visible: cardRow.index > 0; opacity: 0.5 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    QQC2.RadioButton {
                        QQC2.ButtonGroup.group: mainGroup
                        checked: cardRow.isMain
                        onClicked: { page.mainOut = cardRow.modelData.name; page.scDirty = true }
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: "Main card: apps play here"
                    }
                    Kirigami.Icon {
                        source: cardRow.modelData.usb ? "audio-card" : cardRow.modelData.hdmi ? "video-display" : "audio-speakers"
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: implicitWidth
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        RowLayout {
                            QQC2.Label { text: cardRow.modelData.description; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
                            Rectangle {
                                visible: cardRow.isMain
                                radius: height / 2
                                color: Kirigami.Theme.highlightColor
                                implicitWidth: mainBadge.implicitWidth + 14
                                implicitHeight: mainBadge.implicitHeight + 4
                                QQC2.Label { id: mainBadge; anchors.centerIn: parent; text: "MAIN"; color: Kirigami.Theme.highlightedTextColor; font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.Bold }
                            }
                        }
                        QQC2.Label {
                            readonly property var live: page.liveOf(cardRow.modelData.card)
                            text: live && live.playback ? "Now: " + page.khz(live.playback.rate) + ", " + live.playback.bits + "-bit, used by " + live.playback.owner
                                                        : "Not playing right now"
                            opacity: 0.65
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                }
                GridLayout {
                    Layout.leftMargin: Kirigami.Units.gridUnit * 2
                    columns: 4
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: 0
                    QQC2.Label { text: "Sample rate"; opacity: 0.65; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                    QQC2.Label { text: "Buffer"; opacity: 0.65; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                    QQC2.Label { text: "Safety margin"; opacity: 0.65; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                    QQC2.Label { text: "Latency"; opacity: 0.65; font.pointSize: Kirigami.Theme.smallFont.pointSize }
                    QQC2.ComboBox {
                        readonly property var values: [0].concat(cardRow.modelData.rates)
                        model: values.map(v => v === 0 ? "System (" + page.khz(page.sc.systemRate) + ")" : page.khz(v))
                        currentIndex: Math.max(0, values.indexOf(cardRow.ch.rate))
                        onActivated: index => page.choose(cardRow.modelData.name, "rate", values[index])
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    }
                    QQC2.ComboBox {
                        readonly property var values: [0].concat(page.sc.buffers || [])
                        model: values.map(v => v === 0 ? "System (" + page.sc.systemBuffer + ")" : v + " samples")
                        currentIndex: Math.max(0, values.indexOf(cardRow.ch.buffer))
                        onActivated: index => page.choose(cardRow.modelData.name, "buffer", values[index])
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    }
                    QQC2.ComboBox {
                        readonly property var values: [-1].concat(page.sc.headrooms || [])
                        model: values.map(v => v === -1 ? "PipeWire (" + (cardRow.modelData.headroom > 0 || !cardRow.modelData.usb ? cardRow.modelData.headroom : "auto") + ")" : v + " samples")
                        currentIndex: Math.max(0, values.indexOf(cardRow.ch.headroom))
                        onActivated: index => page.choose(cardRow.modelData.name, "headroom", values[index])
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.text: "Extra audio PipeWire keeps ready for this card (USB cards usually get 1024). Less = lower latency; if you hear crackles, go back up."
                    }
                    Kirigami.Heading {
                        level: 4
                        text: page.latency(cardRow.modelData) + " ms"
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
        QQC2.Label {
            visible: page.sc.outputs.length === 0
            text: "No sound cards found."
            opacity: 0.7
        }
        RowLayout {
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: page.sc.inputs.length > 0
            QQC2.Label { text: "Main input" }
            QQC2.ComboBox {
                model: page.sc.inputs.map(i => i.description)
                currentIndex: Math.max(0, page.sc.inputs.findIndex(i => i.name === page.mainIn))
                onActivated: index => { page.mainIn = page.sc.inputs[index].name; page.scDirty = true }
                Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            }
        }
        RowLayout {
            Layout.topMargin: Kirigami.Units.largeSpacing
            QQC2.Button {
                icon.name: "dialog-ok-apply"
                text: page.scBusy ? "Applying…" : "Apply"
                enabled: page.scDirty && !page.scBusy && !page.sc.set
                onClicked: {
                    page.scBusy = true
                    page.scMessage = ""
                    Qt.callLater(() => {
                        const err = djos.setSoundCards(JSON.stringify({ main: page.mainOut, mainInput: page.mainIn, cards: page.choices }))
                        page.scBusy = false
                        page.scMessage = err.length > 0 ? err : "Applied."
                        page.loadCards()
                        page.refresh()
                    })
                }
            }
            QQC2.Button {
                text: "System for all"
                flat: true
                onClicked: {
                    const c = {}
                    for (const o of page.sc.outputs) c[o.name] = { rate: 0, buffer: 0, headroom: -1 }
                    page.choices = c
                    page.scDirty = true
                }
            }
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                opacity: 0.65
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                text: page.sc.set ? "A set is playing: you can change sound cards when it ends."
                                  : "Applying restarts the audio for a second."
                color: page.sc.set ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            }
        }
        QQC2.Label {
            visible: page.scMessage.length > 0
            text: page.scMessage
            color: page.scMessage === "Applied." ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
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
        title: "Defaults for every card"
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.75
            text: "What every card uses unless it has its own setting above: browsers, DAWs and most apps play through PipeWire at this rate and buffer. Richie DJ in “ALSA Direct” mode talks to your card directly, so these settings don’t affect your sets."
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
        QQC2.CheckBox {
            id: followBox
            text: "Follow the sample rate of what's playing (bit-perfect)"
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.65
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            text: followBox.checked
                  ? "The card switches to each app's rate (a 44.1 kHz track plays untouched). Many cards make a “pop” every time it switches."
                  : "Recommended: the card always runs at the rate above and everything else is converted with the best quality, so it never “pops” when an app starts."
        }
        RowLayout {
            QQC2.Button {
                icon.name: "dialog-ok-apply"
                text: "Apply"
                onClicked: {
                    djos.setAudio(page.rates[rateBox.currentIndex], page.quanta[bufBox.currentIndex], followBox.checked)
                    page.refresh()
                    page.message = "Applied: " + (page.rates[rateBox.currentIndex] / 1000) + " kHz" + (followBox.checked ? " (follows what's playing)" : "")
                                   + ", " + page.quanta[bufBox.currentIndex] + " samples."
                }
            }
            QQC2.Button {
                text: "DJOS default"
                flat: true
                onClicked: { rateBox.currentIndex = 1; bufBox.currentIndex = 3; followBox.checked = false }
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
            ok: !page.audio.usbShared || page.audio.usbShared.length === 0
            text: ok ? "Your audio interface has its USB controller to itself" : "A webcam shares the USB controller with your audio interface"
            detail: ok ? "" : page.audio.usbShared.join(", ") + ": plug one of them into a port on another controller (for example a USB-C port), so the camera can't cause dropouts."
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
