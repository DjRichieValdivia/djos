// Acerca de: versiones (DJOS Optimizer, Fedora, Plasma, núcleo, drivers, Richie DJ) y equipo
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "About"

    readonly property var rows: [
        ["DJOS Optimizer", win.sys.version || "not installed"],
        ["System", win.sys.name || ""],
        ["KDE Plasma", win.sys.plasma || ""],
        ["Kernel", win.sys.kernel || ""],
        ["Processor", win.sys.cpu || ""],
        ["Memory", (win.sys.memory || 0) + " GB"],
        ["Graphics", (win.sys.gpu || "") + (win.sys.nvidia ? "  ·  NVIDIA driver " + win.sys.nvidia : "")],
        ["Secure Boot", win.sys.secureBoot ? "On" : "Off"],
        ["Richie DJ", win.sys.richiedj ? (win.sys.richiedjVersion || "installed") : "not installed"]
    ]
    readonly property string info: rows.map(r => r[0] + ": " + r[1]).join("\n")

    // el logo del tema de íconos (con DJOS Glass, en sus colores) y el nombre en el color del texto
    RowLayout {
        Layout.topMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.gridUnit
        Kirigami.Icon {
            source: "djos"
            implicitWidth: Kirigami.Units.gridUnit * 4
            implicitHeight: implicitWidth
        }
        QQC2.Label {
            text: "DJOS"
            font.family: "Inter"
            font.weight: Font.ExtraBold
            font.pixelSize: Kirigami.Units.gridUnit * 2.6
            font.letterSpacing: Kirigami.Units.gridUnit * 0.08
        }
    }
    QQC2.Label {
        text: "DJOS turns Fedora KDE into a PC for DJs and music producers: real-time audio tuning, the DJOS look, DJOS Center, the Self-Test and Richie DJ. Fedora keeps the system itself up to date."
        wrapMode: Text.WordWrap
        opacity: 0.75
        Layout.fillWidth: true
    }

    Card {
        title: "This computer"
        GridLayout {
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing * 2
            rowSpacing: Kirigami.Units.smallSpacing
            Repeater {
                model: page.rows
                delegate: QQC2.Label {
                    required property var modelData
                    required property int index
                    // cada renglón son dos celdas: nombre (gris) y valor
                    text: modelData[0]
                    opacity: 0.6
                    Layout.row: index
                    Layout.column: 0
                }
            }
            Repeater {
                model: page.rows
                delegate: QQC2.Label {
                    required property var modelData
                    required property int index
                    text: modelData[1]
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.row: index
                    Layout.column: 1
                }
            }
        }
        RowLayout {
            QQC2.Button {
                icon.name: "edit-copy"
                text: "Copy"
                onClicked: { copier.text = page.info; copier.selectAll(); copier.copy(); copyDone.visible = true }
            }
            QQC2.Label { id: copyDone; visible: false; text: "Copied"; color: Kirigami.Theme.positiveTextColor }
            TextEdit { id: copier; visible: false }
        }
    }

    Card {
        title: "Help"
        StatusRow {
            iconName: "run-build"
            title: "DJOS Self-Test"
            subtitle: "Checks real-time audio, graphics, sound cards and DJ controllers, and saves a report you can send."
            QQC2.Button {
                icon.name: "run-build"
                text: "Run"
                onClicked: djos.launch(["konsole", "--hide-menubar", "-e", "/usr/libexec/djos/selftest"])
            }
        }
        StatusRow {
            iconName: "utilities-terminal"
            title: "Claude Code"
            subtitle: "An AI assistant in the terminal that knows DJOS: ask it to install, fix or explain anything."
            QQC2.Button {
                icon.name: "utilities-terminal"
                text: "Open"
                onClicked: djos.launch(["konsole", "-e", "/usr/libexec/djos/install-claude"])
            }
        }
    }
}
