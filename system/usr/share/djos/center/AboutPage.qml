// Acerca de: versión y equipo
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "About"

    readonly property string info: "DJOS: " + (win.sys.version || "") + "\n"
        + "Kernel: " + (win.sys.kernel || "") + "\n"
        + "Processor: " + (win.sys.cpu || "") + "\n"
        + "Memory: " + (win.sys.memory || 0) + " GB\n"
        + "Graphics: " + (win.sys.gpu || "") + (win.sys.nvidia ? " (NVIDIA " + win.sys.nvidia + ")" : "")

    Image {
        source: "file:///usr/share/djos/logo.png"
        sourceSize.height: Kirigami.Units.gridUnit * 4
        fillMode: Image.PreserveAspectFit
        Layout.preferredHeight: Kirigami.Units.gridUnit * 4
        Layout.topMargin: Kirigami.Units.largeSpacing
    }
    QQC2.Label {
        text: "The operating system for DJs and music producers. Built on Fedora and KDE Plasma, tuned for real-time audio."
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
            QQC2.Label { text: "DJOS"; opacity: 0.6 }
            QQC2.Label { text: (win.sys.name || "") + "  (" + (win.sys.version || "") + ")" }
            QQC2.Label { text: "Kernel"; opacity: 0.6 }
            QQC2.Label { text: win.sys.kernel || "" }
            QQC2.Label { text: "Processor"; opacity: 0.6 }
            QQC2.Label { text: win.sys.cpu || "" }
            QQC2.Label { text: "Memory"; opacity: 0.6 }
            QQC2.Label { text: (win.sys.memory || 0) + " GB" }
            QQC2.Label { text: "Graphics"; opacity: 0.6 }
            QQC2.Label { text: (win.sys.gpu || "") + (win.sys.nvidia ? "  ·  driver " + win.sys.nvidia : "") }
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
            iconName: "claude"
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
