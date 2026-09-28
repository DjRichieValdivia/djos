// DJOS Center: ventana principal (barra lateral + páginas)
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: win
    title: "DJOS Center"
    width: Kirigami.Units.gridUnit * 58
    height: Kirigami.Units.gridUnit * 40
    minimumWidth: Kirigami.Units.gridUnit * 42
    minimumHeight: Kirigami.Units.gridUnit * 28

    // estado compartido entre páginas (lo refrescan las páginas que lo usan)
    property var sys: ({})
    property var updates: ({ system: { booted: "", staged: "" }, apps: [], flatpak: 0, checked: 0, setup: true })
    property bool checkingUpdates: false
    property string busyApp: ""

    readonly property var pages: [
        { key: "overview", title: "Overview", icon: "djos", file: "OverviewPage.qml" },
        { key: "audio", title: "Audio", icon: "audio-card", file: "AudioPage.qml" },
        { key: "performance", title: "Performance", icon: "speedometer", file: "PerformancePage.qml" },
        { key: "updates", title: "Updates", icon: "update-none", file: "UpdatesPage.qml" },
        { key: "apps", title: "Apps & Plugins", icon: "plasmadiscover", file: "AppsPage.qml" },
        { key: "disks", title: "Music Disks", icon: "drive-harddisk", file: "DisksPage.qml" },
        { key: "about", title: "About", icon: "help-about", file: "AboutPage.qml" }
    ]

    function go(key) {
        for (var i = 0; i < pages.length; ++i)
            if (pages[i].key === key) { nav.currentIndex = i; return }
    }
    function refreshSystem() { sys = JSON.parse(djos.system()) }
    function refreshUpdates() { djos.run("status", ["/usr/libexec/djos/updates-status"]) }

    Connections {
        target: djos
        function onJobDone(tag, code, output) {
            if (tag === "status") {
                try { win.updates = JSON.parse(output) } catch (e) { }
            } else if (tag === "check") {
                win.checkingUpdates = false
                win.refreshUpdates(); win.refreshSystem()
            }
        }
    }

    Component.onCompleted: { refreshSystem(); refreshUpdates(); go(startPage) }

    pageStack.initialPage: Kirigami.Page {
        padding: 0
        globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // barra lateral
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 13
                Kirigami.Theme.colorSet: Kirigami.Theme.Header
                Kirigami.Theme.inherit: false
                color: Kirigami.Theme.backgroundColor

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.margins: Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.largeSpacing * 2
                        spacing: Kirigami.Units.largeSpacing
                        Kirigami.Icon {
                            source: "djos"
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: implicitWidth
                        }
                        ColumnLayout {
                            spacing: 0
                            Kirigami.Heading { text: "DJOS"; level: 2; font.weight: Font.ExtraBold }
                            QQC2.Label { text: "Center"; opacity: 0.6 }
                        }
                    }

                    ListView {
                        id: nav
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: win.pages
                        spacing: 2
                        currentIndex: 0
                        delegate: QQC2.ItemDelegate {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            highlighted: ListView.isCurrentItem
                            icon.name: modelData.icon
                            text: modelData.title
                            onClicked: nav.currentIndex = index
                        }
                    }
                }
            }

            Kirigami.Separator { Layout.fillHeight: true }

            // página actual
            Loader {
                id: content
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: win.pages[nav.currentIndex].file
            }
        }
    }
}
