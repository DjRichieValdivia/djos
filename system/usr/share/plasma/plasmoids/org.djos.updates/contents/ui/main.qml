// DJOS Updates: ícono en la barra con el estado de las actualizaciones (sistema, Richie DJ, programas) y botones
// para buscar, actualizar programas y reiniciar. El estado lo arma /usr/libexec/djos/updates-status.
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

    property var st: ({ system: { booted: "", staged: "" }, apps: [], flatpak: 0, checked: 0, setup: true })
    property bool checking: false
    property bool updatingApps: false

    readonly property string statusCmd: "/usr/libexec/djos/updates-status"
    readonly property string checkCmd: "pkexec /usr/libexec/djos/update --root check"
    readonly property string appsCmd: "flatpak update -y --noninteractive"
    readonly property string rebootCmd: "busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptReboot"

    readonly property bool systemReady: !!(st.system && st.system.staged)
    readonly property int appsPending: (st.apps || []).filter(a => a.state === "ready" || a.state === "waiting").length
    readonly property int pending: (systemReady ? 1 : 0) + appsPending + (st.flatpak > 0 ? 1 : 0)

    Plasmoid.icon: pending > 0 ? "update-high" : "update-none"
    toolTipMainText: "DJOS Updates"
    toolTipSubText: !st.setup ? "Updates are not set up yet"
                  : pending > 0 ? "Updates are ready — click to see them" : "Everything is up to date"

    function run(cmd) { exec.connectSource(cmd) }
    function refresh() { run(statusCmd) }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            exec.disconnectSource(source)
            if (source === root.statusCmd) {
                try { root.st = JSON.parse(data["stdout"]) } catch (e) { }
            } else if (source === root.checkCmd) {
                root.checking = false
                root.refresh()
            } else if (source === root.appsCmd) {
                root.updatingApps = false
                root.refresh()
            }
        }
    }

    Timer {
        interval: 20 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onExpandedChanged: if (expanded) root.refresh()

    function appText(state) {
        switch (state) {
        case "up-to-date": return "Up to date"
        case "updated":    return "Updated to the latest version"
        case "ready":      return "New version downloaded — it installs when you close it"
        case "waiting":    return "New version available — it downloads when you're not playing"
        case "unreachable":return "Can't check right now (no internet?)"
        case "error":      return "The last update failed — try Check now"
        }
        return "Not checked yet"
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
                    enabled: !root.checking && root.st.setup
                    onClicked: { root.checking = true; root.run(root.checkCmd) }
                }
            }
        }

        contentItem: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // actualizaciones sin configurar
            RowLayout {
                visible: !root.st.setup
                Layout.fillWidth: true
                Kirigami.Icon { source: "dialog-warning"; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: "Updates are not set up yet. Connect this PC to your DJOS updates (only once)."
                }
                PlasmaComponents.Button {
                    text: "Set up"
                    onClicked: root.run("konsole -e /usr/libexec/djos/setup-updates")
                }
            }

            // sistema
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "preferences-system"; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label { text: "DJOS system"; font.bold: true }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        opacity: 0.8
                        text: root.systemReady ? "Update downloaded (" + root.st.system.staged + ") — restart to apply it"
                                               : "Up to date" + (root.st.system && root.st.system.booted ? " (" + root.st.system.booted + ")" : "")
                    }
                }
                PlasmaComponents.Button {
                    visible: root.systemReady
                    icon.name: "system-reboot"
                    text: "Restart"
                    onClicked: root.run(root.rebootCmd)
                }
            }

            // programas privados (Richie DJ)
            Repeater {
                model: root.st.apps || []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Kirigami.Icon { source: modelData.id === "richiedj" ? "richiedj" : "application-x-executable"; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PlasmaComponents.Label { text: modelData.name; font.bold: true }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            opacity: 0.8
                            text: root.appText(modelData.state)
                        }
                    }
                }
            }

            // programas de Flathub
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "plasmadiscover"; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label { text: "Apps (Discover / Flathub)"; font.bold: true }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        opacity: 0.8
                        text: root.updatingApps ? "Updating…"
                              : root.st.flatpak > 0 ? root.st.flatpak + (root.st.flatpak === 1 ? " update available" : " updates available")
                                                    : "Up to date"
                    }
                }
                PlasmaComponents.Button {
                    visible: root.st.flatpak > 0 && !root.updatingApps
                    icon.name: "update-none"
                    text: "Update"
                    onClicked: { root.updatingApps = true; root.run(root.appsCmd) }
                }
            }

            // programas de Arch (paru)
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: "utilities-terminal"; implicitWidth: Kirigami.Units.iconSizes.medium; implicitHeight: implicitWidth }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    PlasmaComponents.Label { text: "Arch apps (paru)"; font.bold: true }
                    PlasmaComponents.Label { opacity: 0.8; text: "Updates in a terminal window" }
                }
                PlasmaComponents.Button {
                    icon.name: "update-none"
                    text: "Update"
                    onClicked: root.run("konsole -e paru -Syu")
                }
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
                text: "DJOS downloads updates by itself and applies them when you restart. Never during a set."
                      + (root.st.checked > 0 ? "\nLast check: " + new Date(root.st.checked * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat) : "")
                wrapMode: Text.WordWrap
            }
        }
        }
    }
}
