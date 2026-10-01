// DJOS Stats: en la barra de arriba, lo que le sirve a un DJ de un vistazo: la latencia de la salida de audio (y su
// frecuencia), CPU, GPU, RAM y temperatura del procesador, y "SET" mientras suena un set (DJOS frena las actualizaciones
// y el mantenimiento). Clic: el detalle (todas las salidas abiertas, quién las usa, VRAM, potencia…) y DJOS Center.
// Clic derecho: qué mostrar. Barato: los números del sistema vienen de ksystemstats (el mismo servicio del Monitor del
// sistema de Plasma; para NVIDIA corre un solo "nvidia-smi dmon"), el audio de /usr/libexec/djos/audio-now (lee
// /proc) cada 3 s, y nada se repinta si no cambió.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    Plasmoid.icon: "utilities-system-monitor"
    toolTipMainText: "DJOS Stats"
    toolTipSubText: audioLine() + "\nCPU " + pct(cpu.value) + " · GPU " + (hasGpu ? pct(gpu.value) : "—") + " · RAM " + gb(ram.value)

    // ---------------------------------------------------------------- datos
    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: cpuTemp; sensorId: "cpu/all/maximumTemperature"; updateRateLimit: 3000 }
    Sensors.Sensor { id: cpuFreq; sensorId: "cpu/all/averageFrequency"; updateRateLimit: 3000; enabled: root.expanded }
    Sensors.Sensor { id: ram; sensorId: "memory/physical/used"; updateRateLimit: 3000 }
    Sensors.Sensor { id: ramTotal; sensorId: "memory/physical/total"; updateRateLimit: 60000 }
    Sensors.Sensor { id: gpu; sensorId: "gpu/gpu0/usage"; updateRateLimit: 2000 }
    Sensors.Sensor { id: gpuTemp; sensorId: "gpu/gpu0/temperature"; updateRateLimit: 3000; enabled: root.expanded }
    Sensors.Sensor { id: vram; sensorId: "gpu/gpu0/usedVram"; updateRateLimit: 3000; enabled: root.expanded }
    Sensors.Sensor { id: vramTotal; sensorId: "gpu/gpu0/totalVram"; updateRateLimit: 60000 }
    Sensors.Sensor { id: gpuPower; sensorId: "gpu/gpu0/power"; updateRateLimit: 3000; enabled: root.expanded }

    readonly property bool hasGpu: vramTotal.value > 0
    property var audio: ({ set: false, outputs: [], richiedj: null })
    // Richie DJ abierto (publica su estado): su salida, su latencia y sus cortes de audio
    readonly property var rdj: audio.richiedj || null
    // cortes "recientes": si el contador subió en el último minuto, en rojo
    property int lastDrops: -1
    property double dropAtMs: 0
    onRdjChanged: {
        if (!rdj) { lastDrops = -1; return }
        if (lastDrops >= 0 && rdj.dropouts > lastDrops) dropAtMs = Date.now()
        lastDrops = rdj.dropouts
    }
    readonly property bool recentDrops: rdj !== null && Date.now() - dropAtMs < 60000 && dropAtMs > 0
    // la salida que importa: la de Richie DJ (ALSA Direct) si tiene una, si no la principal (la salida por defecto)
    readonly property var mainOut: {
        const o = audio.outputs || []
        for (const x of o)
            if (x.owner !== "pipewire")
                return x
        for (const x of o)
            if (x.main)
                return x
        return o.length > 0 ? o[0] : null
    }

    P5Support.DataSource {
        id: audioSource
        engine: "executable"
        interval: root.audio.set ? 5000 : 3000      // en pleno set, todavía menos trabajo
        connectedSources: ["/usr/libexec/djos/audio-now"]
        onNewData: (source, data) => {
            try { root.audio = JSON.parse(data.stdout || "{}") } catch (e) { }
        }
    }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }

    function pct(v) { return Math.round(v || 0) + "%" }
    function gb(bytes) { return ((bytes || 0) / 1073741824).toFixed(1) + " GB" }
    function deg(v) { return Math.round(v || 0) + "°" }
    function khz(r) { return r ? (r % 1000 === 0 ? (r / 1000) : (r / 1000).toFixed(1)) + " kHz" : "" }
    function ownerName(o) { return o === "pipewire" ? "PipeWire" : o === "Richie DJ" || o === "richiedj" ? "Richie DJ (ALSA Direct)" : o }
    function audioLine() {
        if (rdj && rdj.latencyMs !== undefined)
            return "Richie DJ " + rdj.latencyMs + " ms · " + khz(rdj.rate) + " · " + rdj.device + " · dropouts " + rdj.dropouts
        const m = mainOut
        return m ? "Audio " + m.ms + " ms · " + khz(m.rate) + " · " + m.card : "Audio: no output open"
    }
    // lo que muestra el chip de audio: la latencia de Richie DJ si está abierto (la suya, con el limitador), si no la
    // de la salida en uso
    function audioChip() {
        if (rdj && rdj.latencyMs !== undefined) return rdj.latencyMs + " ms · " + khz(rdj.rate)
        return mainOut ? mainOut.ms + " ms · " + khz(mainOut.rate) : "—"
    }
    // de gris a amarillo y rojo cuando se acerca al límite
    function level(v, warn, bad) { return v >= bad ? Kirigami.Theme.negativeTextColor : v >= warn ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor }

    Plasmoid.contextualActions: [
        PlasmaCore.Action { text: "Show audio latency"; checkable: true; checked: Plasmoid.configuration.showAudio; onTriggered: Plasmoid.configuration.showAudio = checked },
        PlasmaCore.Action { text: "Show CPU"; checkable: true; checked: Plasmoid.configuration.showCpu; onTriggered: Plasmoid.configuration.showCpu = checked },
        PlasmaCore.Action { text: "Show GPU"; checkable: true; checked: Plasmoid.configuration.showGpu; onTriggered: Plasmoid.configuration.showGpu = checked; visible: root.hasGpu },
        PlasmaCore.Action { text: "Show RAM"; checkable: true; checked: Plasmoid.configuration.showRam; onTriggered: Plasmoid.configuration.showRam = checked },
        PlasmaCore.Action { text: "Show CPU temperature"; checkable: true; checked: Plasmoid.configuration.showTemp; onTriggered: Plasmoid.configuration.showTemp = checked }
    ]

    // ---------------------------------------------------------------- en la barra
    component Chip: RowLayout {
        property string label
        property string value
        property color valueColor: Kirigami.Theme.textColor
        spacing: Math.round(Kirigami.Units.smallSpacing * 0.8)
        PlasmaComponents.Label {
            text: parent.label
            opacity: 0.6
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
        }
        PlasmaComponents.Label {
            text: parent.value
            color: parent.valueColor
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
            font.features: { "tnum": 1 }        // números del mismo ancho: no "baila" cuando cambian
            font.weight: Font.Medium
        }
    }

    compactRepresentation: MouseArea {
        id: compact
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: height / 2
            color: Kirigami.Theme.textColor
            opacity: compact.containsMouse || root.expanded ? 0.10 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.largeSpacing
            // SET: suena un set (lo que también frena las actualizaciones)
            Rectangle {
                visible: root.audio.set === true
                Layout.preferredHeight: setText.implicitHeight + 2
                Layout.preferredWidth: setText.implicitWidth + 12
                radius: height / 2
                color: Kirigami.Theme.negativeTextColor
                PlasmaComponents.Label {
                    id: setText
                    anchors.centerIn: parent
                    text: "● SET"
                    color: "white"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.weight: Font.Bold
                }
            }
            Chip {
                visible: Plasmoid.configuration.showAudio
                label: "AUDIO"
                value: root.audioChip()
            }
            Chip {
                visible: Plasmoid.configuration.showAudio && root.rdj !== null
                label: "DROPS"
                value: root.rdj ? String(root.rdj.dropouts) : "0"
                valueColor: root.recentDrops ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            }
            Chip {
                visible: Plasmoid.configuration.showCpu
                label: "CPU"
                value: root.pct(cpu.value)
                valueColor: root.level(cpu.value, 70, 90)
            }
            Chip {
                visible: Plasmoid.configuration.showGpu && root.hasGpu
                label: "GPU"
                value: root.pct(gpu.value)
                valueColor: root.level(gpu.value, 80, 95)
            }
            Chip {
                visible: Plasmoid.configuration.showRam
                label: "RAM"
                value: root.gb(ram.value)
                valueColor: root.level(ramTotal.value > 0 ? ram.value / ramTotal.value * 100 : 0, 80, 92)
            }
            Chip {
                visible: Plasmoid.configuration.showTemp && cpuTemp.value > 0
                label: "TEMP"
                value: root.deg(cpuTemp.value)
                valueColor: root.level(cpuTemp.value, 80, 92)
            }
        }
    }

    // ---------------------------------------------------------------- el detalle
    fullRepresentation: PlasmaExtras.Representation {
        id: rep
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        // todo el contenido, con la cabecera (sin ella, los botones de abajo quedaban cortados)
        Layout.minimumHeight: details.implicitHeight + Kirigami.Units.largeSpacing * 2 + (rep.header ? rep.header.implicitHeight : 0)
        Layout.preferredHeight: Layout.minimumHeight
        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading { level: 3; text: "DJOS Stats"; Layout.fillWidth: true }
                PlasmaComponents.Label {
                    visible: root.audio.set === true
                    text: "● Set playing: updates and maintenance wait"
                    color: Kirigami.Theme.negativeTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
        ColumnLayout {
            id: details
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Heading { level: 5; text: "Richie DJ"; opacity: 0.7; visible: root.rdj !== null }
            ColumnLayout {
                visible: root.rdj !== null
                spacing: 0
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    // el nombre de la placa (con el modo, si el nombre no lo dice ya)
                    text: !root.rdj ? "" : !root.rdj.device ? "No sound card open"
                          : root.rdj.device + (root.rdj.type && root.rdj.device.indexOf(root.rdj.type) < 0 ? " · " + root.rdj.type : "")
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    visible: root.rdj !== null && !!root.rdj.device
                    text: root.rdj && root.rdj.device ? root.rdj.latencyMs + " ms  ·  " + root.khz(root.rdj.rate) + "  ·  " + root.rdj.buffer + " samples" : ""
                    opacity: 0.75
                    font.features: { "tnum": 1 }
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                RowLayout {
                    spacing: 0
                    Layout.fillWidth: true
                    // los cortes en rojo si hubo uno en el último minuto
                    PlasmaComponents.Label {
                        text: root.rdj ? "Dropouts " + root.rdj.dropouts : ""
                        color: root.recentDrops ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        opacity: root.recentDrops ? 1 : 0.75
                        font.features: { "tnum": 1 }
                    }
                    PlasmaComponents.Label {
                        text: !root.rdj ? "" : "  ·  audio load " + Math.round((root.rdj.cpu || 0) * 100) + "%"
                                               + "  ·  " + root.rdj.playing + (root.rdj.playing === 1 ? " deck" : " decks") + " playing"
                                               + (root.rdj.recording ? "  ·  ● recording" : "")
                        opacity: 0.75
                        font.features: { "tnum": 1 }
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
            Kirigami.Heading { level: 5; text: "Audio outputs"; opacity: 0.7 }
            Repeater {
                model: root.audio.outputs || []
                delegate: ColumnLayout {
                    required property var modelData
                    spacing: 0
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: modelData.card
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        text: modelData.ms + " ms  ·  " + root.khz(modelData.rate) + "  ·  " + modelData.bits + "-bit  ·  "
                              + modelData.buffer + " samples  ·  " + root.ownerName(modelData.owner)
                        opacity: 0.75
                        font.features: { "tnum": 1 }
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                }
            }
            PlasmaComponents.Label {
                visible: (root.audio.outputs || []).length === 0
                text: "No sound card is playing right now."
                opacity: 0.7
            }

            Kirigami.Heading { level: 5; text: "Computer"; opacity: 0.7 }
            GridLayout {
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing * 2
                rowSpacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label { text: "Processor"; opacity: 0.75 }
                PlasmaComponents.Label {
                    text: root.pct(cpu.value) + (cpuTemp.value > 0 ? "  ·  " + root.deg(cpuTemp.value) + "C" : "")
                          + (cpuFreq.value > 0 ? "  ·  " + (cpuFreq.value / 1000).toFixed(1) + " GHz" : "")
                    font.features: { "tnum": 1 }
                }
                PlasmaComponents.Label { text: "Graphics"; opacity: 0.75; visible: root.hasGpu }
                PlasmaComponents.Label {
                    visible: root.hasGpu
                    text: root.pct(gpu.value) + (gpuTemp.value > 0 ? "  ·  " + root.deg(gpuTemp.value) + "C" : "")
                          + "  ·  " + root.gb(vram.value) + " of " + root.gb(vramTotal.value)
                          + (gpuPower.value > 0 ? "  ·  " + Math.round(gpuPower.value) + " W" : "")
                    font.features: { "tnum": 1 }
                }
                PlasmaComponents.Label { text: "Memory"; opacity: 0.75 }
                PlasmaComponents.Label {
                    text: root.gb(ram.value) + " of " + root.gb(ramTotal.value)
                    font.features: { "tnum": 1 }
                }
            }

            RowLayout {
                Layout.topMargin: Kirigami.Units.smallSpacing
                PlasmaComponents.Button {
                    icon.name: "audio-card"
                    text: "Sound cards…"
                    onClicked: { exec.connectSource("/usr/libexec/djos/center --page audio"); root.expanded = false }
                }
                PlasmaComponents.Button {
                    icon.name: "utilities-system-monitor"
                    text: "System Monitor"
                    onClicked: { exec.connectSource("plasma-systemmonitor"); root.expanded = false }
                }
            }
        }
    }
}
