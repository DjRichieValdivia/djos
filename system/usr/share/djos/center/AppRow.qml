// Una app del catálogo (apps.json): ícono, para qué sirve, cuándo usarla y Abrir / Instalar / Sacar.
// La usan "Apps & Plugins" y "Which App?"; instalar y sacar van por win (Main.qml) y avisan con jobDone("app:…")
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

StatusRow {
    id: r
    property var app: ({})
    property bool compact: false          // en "Which App?": sin la descripción larga
    iconName: app.icon || ""
    fallbackIcon: app.fallback || "applications-multimedia"
    title: app.name || ""
    subtitle: compact ? "" : (app.desc || "")
    hint: app.use || ""

    QQC2.BusyIndicator {
        visible: win.busyApp === r.app.name
        running: visible
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: implicitWidth
    }
    QQC2.Label {
        visible: r.app.pack === true && r.app.installed && win.busyApp !== r.app.name
        text: "Installed"
        color: Kirigami.Theme.positiveTextColor
    }
    QQC2.Label {   // Richie DJ todavía no bajó (llega con las actualizaciones de DJOS)
        visible: r.app.managed === true && !r.app.installed
        text: "Comes with the DJOS updates"
        opacity: 0.7
    }
    QQC2.Button {
        visible: r.app.installed && !r.app.pack && win.busyApp !== r.app.name
        icon.name: "media-playback-start"
        text: "Open"
        onClicked: win.openApp(r.app)
    }
    QQC2.Button {
        visible: !r.app.installed && !r.app.included && !r.app.managed && win.busyApp !== r.app.name
        enabled: win.busyApp === ""
        icon.name: "download"
        text: "Install"
        onClicked: win.installApp(r.app)
    }
    QQC2.ToolButton {
        visible: r.app.installed && !r.app.included && win.busyApp !== r.app.name
        enabled: win.busyApp === ""
        icon.name: "edit-delete"
        display: QQC2.AbstractButton.IconOnly
        text: "Remove"
        QQC2.ToolTip.text: "Remove " + r.app.name
        QQC2.ToolTip.visible: hovered
        onClicked: win.removeApp(r.app)
    }
}
