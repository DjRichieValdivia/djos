// DJOS Updates: ícono en la barra con el estado de las actualizaciones (Fedora, Richie DJ, DJOS Optimizer) y los
// botones para buscar, instalar lo preparado (reiniciando o apagando) y abrir DJOS Center. El estado lo da
// "/usr/libexec/djos/update status" (update-status.json); instalar y buscar van por pkexec (polkit, sin contraseña).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var st: ({ time: 0, system: { state: "up-to-date", count: 0, error: "" }, apps: {},
                        optimizer: { state: "", installed: "", available: "" },
                        release: { available: "", ready: false, prepared: false }, connected: true })
    property bool busy: false          // una búsqueda o una instalación pedida desde acá
    property string confirm: ""        // "install-shutdown" / "install-reboot" mientras se pide confirmación
    property string message: ""

    readonly property string statusCmd: "/usr/libexec/djos/update status"
    readonly property string checkCmd: "pkexec /usr/libexec/djos/update check"
    readonly property string sysState: st.system ? st.system.state : ""
    readonly property bool checking: busy || sysState === "checking"
    readonly property bool ready: sysState === "ready"
    readonly property var apps: Object.keys(st.apps || {}).map(k => Object.assign({ id: k }, st.apps[k]))
    readonly property bool appsPending: apps.some(a => a.state === "ready" || a.state === "waiting")

    Plasmoid.icon: ready || appsPending || (st.release && st.release.ready && !st.release.prepared) ? "update-high"
                 : sysState === "error" || !st.connected ? "update-medium" : "update-none"
    toolTipMainText: "DJOS Updates"
    toolTipSubText: stateLine()

    function stateLine() {
        switch (sysState) {
        case "ready":
            return st.release && st.release.prepared ? "Fedora " + st.release.available + " is downloaded, ready to install"
                                                     : st.system.count + (st.system.count === 1 ? " update" : " updates")
                                                       + " downloaded, ready to install"
        case "checking":   return "Checking for updates…"
        case "offline":    return "No internet connection"
        case "error":      return "The last check failed" + (st.system.error ? ": " + st.system.error : "")
        }
        return st.time > 0 ? "Everything is up to date" : "Not checked yet"
    }
    function appText(state) {
        switch (state) {
        case "up-to-date":  return "Up to date"
        case "updated":     return "Updated to the latest version"
        case "ready":       return "New version downloaded: it installs when you close it"
        case "waiting":     return "New version available: it downloads when you're not playing"
        case "unreachable": return st.connected ? "Can't check right now (no internet, or no access on GitHub)" : "Connect GitHub to get it"
        case "error":       return "The last update failed. Try Check now"
        }
        return "Not checked yet"
    }

    function run(cmd) { exec.connectSource(cmd) }
    function refresh() { run(statusCmd) }
    function lastLine(text) { return (text || "").split("\n").filter(l => l.trim().length > 0).slice(-1)[0] || "" }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            exec.disconnectSource(source)
            if (source === root.statusCmd) {
                try { root.st = JSON.parse(data["stdout"]) } catch (e) { }
                return
            }
            if (source === root.checkCmd || source.indexOf("/usr/libexec/djos/update install-") >= 0) {
                root.busy = false
                // 3 = está sonando un set; 4 = no había nada para instalar
                root.message = data["exit code"] === 0 ? "" : root.lastLine(data["stdout"]) || root.lastLine(data["stderr"])
            }
            root.refresh()
        }
    }

    Timer {   // cada 5 minutos, y cada 10 segundos mientras se busca
        interval: root.checking ? 10 * 1000 : 5 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onExpandedChanged: function (isExpanded) {
        if (isExpanded) { root.refresh(); root.confirm = "" }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 20
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading {
                    level: 3
                    text: "DJOS Updates"
                    Layout.fillWidth: true
                }
                PlasmaComponents.Button {
                    icon.name: "view-refresh"
                    text: root.checking ? "Checking…" : "Check now"
                    enabled: !root.checking
                    onClicked: { root.busy = true; root.message = ""; root.run(root.checkCmd) }
                }
            }
        }

        contentItem: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // sin conexión a GitHub: Richie DJ y el optimizador no se pueden bajar
            RowLayout {
                visible: !root.st.connected
                Layout.fillWidth: true
                Kirigami.Icon { source: "dialog-warning"; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Connect this PC to GitHub (only once) to get Richie DJ and the DJOS updates."
                }
                PlasmaComponents.Button {
                    text: "Connect"
                    onClicked: root.run("konsole --hide-menubar -e /usr/libexec/djos/connect")
                }
            }

            // Fedora
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: root.ready ? "update-high" : root.sysState === "error" ? "dialog-warning" : "preferences-system"
                    implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label { text: "Fedora"; font.bold: true }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        opacity: 0.8
                        text: root.stateLine()
                    }
                }
                PlasmaComponents.BusyIndicator {
                    visible: root.checking
                    running: visible
                    implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth
                }
            }

            // instalar lo preparado: se confirma antes (la PC se reinicia)
            RowLayout {
                visible: root.ready && !root.checking && root.confirm === ""
                Layout.fillWidth: true
                PlasmaComponents.Button {
                    icon.name: "system-shutdown"
                    text: "Install & shut down"
                    onClicked: root.confirm = "install-shutdown"
                }
                PlasmaComponents.Button {
                    icon.name: "system-reboot"
                    text: "Install & restart"
                    onClicked: root.confirm = "install-reboot"
                }
            }
            ColumnLayout {
                visible: root.confirm !== "" && !root.checking   // si empezó a buscar, primero que termine
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Save your work and close Richie DJ. The PC restarts, installs the updates"
                          + (root.st.release && root.st.release.prepared ? " (20-40 minutes, don't turn it off)" : " (a few minutes)")
                          + (root.confirm === "install-shutdown" ? " and then shuts down." : " and starts again.")
                }
                RowLayout {
                    PlasmaComponents.Button {
                        icon.name: root.confirm === "install-shutdown" ? "system-shutdown" : "system-reboot"
                        text: root.confirm === "install-shutdown" ? "Install & shut down now" : "Install & restart now"
                        onClicked: {
                            root.busy = true
                            root.run("pkexec /usr/libexec/djos/update " + root.confirm)
                            root.confirm = ""
                        }
                    }
                    PlasmaComponents.Button { text: "Cancel"; onClicked: root.confirm = "" }
                }
            }

            // Richie DJ (y otros programas privados)
            Repeater {
                model: root.apps
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Kirigami.Icon { source: modelData.id === "richiedj" ? "richiedj" : "application-x-executable"; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents.Label { text: (modelData.name || modelData.id) + (modelData.version ? "  ·  " + modelData.version : ""); font.bold: true }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: 0.8
                            text: root.appText(modelData.state)
                        }
                    }
                }
            }

            // la versión nueva de Fedora (se pasa desde DJOS Center, en una ventana que muestra el avance)
            RowLayout {
                visible: !!(root.st.release && root.st.release.ready && !root.st.release.prepared)
                Layout.fillWidth: true
                Kirigami.Icon { source: "system-upgrade"; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Fedora " + (root.st.release ? root.st.release.available : "") + " is available and ready for this PC."
                }
            }

            PlasmaComponents.Label {
                visible: root.message.length > 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.neutralTextColor
                text: root.message
            }

            Item { Layout.fillHeight: true }

            PlasmaComponents.Button {
                icon.name: "djoscenter"
                text: "Open DJOS Center"
                onClicked: root.run("setsid -f /usr/libexec/djos/center --page updates")
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                opacity: 0.6
                font: Kirigami.Theme.smallFont
                text: "DJOS downloads updates by itself, never during a set, and installs them only when you choose."
                      + (root.st.time > 0 ? "\nLast check: " + new Date(root.st.time * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat) : "")
                      + (root.st.optimizer && root.st.optimizer.installed ? "  ·  DJOS Optimizer " + root.st.optimizer.installed : "")
                wrapMode: Text.WordWrap
            }
        }
        }
    }
}
