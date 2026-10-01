// Actualizaciones: Fedora (preparadas sin instalar), Richie DJ, DJOS Optimizer, la próxima versión de Fedora y
// el acceso a GitHub (solo si una descarga lo pide). Todo sale de "/usr/libexec/djos/update status"; buscar e instalar van por pkexec.
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

PageBase {
    id: page
    title: "Updates"
    subtitle: "DJOS downloads updates by itself, never during a set, and installs them only when you choose: when you restart or shut down from here."

    readonly property var st: win.updates
    readonly property string sysState: st.system ? st.system.state : ""
    readonly property var release: st.release || ({})
    readonly property bool releasePrepared: release.prepared === true

    function systemTitle() {
        switch (sysState) {
        case "ready":
            return page.releasePrepared ? "Fedora " + page.release.available + " is ready to install"
                                        : st.system.count + (st.system.count === 1 ? " update is ready to install" : " updates are ready to install")
        case "checking":   return "Checking for updates…"
        case "offline":    return "No internet connection"
        case "error":      return "The last check failed"
        }
        return st.time > 0 ? "Fedora is up to date" : "Not checked yet"
    }
    function systemSubtitle() {
        switch (sysState) {
        case "ready":
            return page.releasePrepared ? "The PC restarts, installs it (20-40 minutes, don't turn it off) and starts again."
                                        : "Already downloaded and tested. They install in a few minutes while the PC restarts or shuts down."
        case "checking":   return "Downloading in the background at the lowest priority. You can keep using the PC."
        case "offline":    return "DJOS checks again when you're back online."
        case "error":      return st.system.error || ""
        }
        return win.sys.name || ""
    }
    function appText(state) {
        switch (state) {
        case "up-to-date":  return "Up to date"
        case "updated":     return "Updated to the latest version"
        case "downloading": return "Downloading the new version… (it installs when the app is closed)"
        case "ready":       return "New version downloaded: it installs when you close it"
        case "waiting":     return "New version available: it downloads when you're not playing"
        case "unreachable": return "Can't check right now (no internet connection?)"
        case "not-connected": return "This download needs GitHub access: Connect GitHub"
        case "error":       return "The last update failed. Try Check now"
        }
        return "Not checked yet"
    }
    function optimizerText() {
        var o = st.optimizer || {}
        switch (o.state) {
        case "updated":       return "Just updated to " + o.installed
        case "ready":         return "Version " + o.available + " installs when nothing is playing"
        case "waiting":       return "Version " + o.available + " installs after the Fedora updates (Install & restart)"
        case "not-connected": return "The DJOS updates need GitHub access: Connect GitHub"
        case "unreachable":   return "Can't check right now" + (o.error ? " (" + o.error + ")" : "")
        case "error":         return "The last update failed" + (o.error ? ": " + o.error : "")
        }
        return "Up to date"
    }
    function offerDate() {   // la versión nueva se ofrece 4 semanas después de salir
        if (!release.date) return ""
        var d = new Date(release.date + "T12:00:00")
        d.setDate(d.getDate() + 28)
        return d.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }

    Component.onCompleted: win.refreshUpdates()

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: !page.st.connected
        type: Kirigami.MessageType.Warning
        text: "A DJOS download needs GitHub access on this PC (normally none is needed). Connect GitHub once: you sign in with your browser; there's nothing to paste."
        actions: [
            Kirigami.Action {
                text: "Connect GitHub"
                icon.name: "network-connect"
                onTriggered: win.connectGitHub()
            }
        ]
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        visible: win.updateMessage.length > 0
        type: Kirigami.MessageType.Error
        text: win.updateMessage
        showCloseButton: true
        onVisibleChanged: if (!visible) win.updateMessage = ""
    }

    Card {
        title: "Fedora"
        StatusRow {
            iconName: page.sysState === "ready" ? "update-high" : "update-none"
            warning: page.sysState === "error"
            title: page.systemTitle()
            subtitle: page.systemSubtitle()
            QQC2.Button {
                icon.name: "view-refresh"
                text: win.updatesChecking ? "Checking…" : "Check now"
                enabled: !win.updatesChecking && !win.installingUpdates
                onClicked: win.checkUpdates()
            }
        }
        QQC2.BusyIndicator { visible: win.updatesChecking || win.installingUpdates; running: visible; Layout.alignment: Qt.AlignHCenter }
        RowLayout {
            visible: win.updatesReady && !win.updatesChecking
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button {
                icon.name: "system-shutdown"
                text: "Install & shut down"
                enabled: !win.installingUpdates
                onClicked: { confirm.action = "install-shutdown"; confirm.open() }
            }
            QQC2.Button {
                icon.name: "system-reboot"
                text: "Install & restart"
                enabled: !win.installingUpdates
                onClicked: { confirm.action = "install-reboot"; confirm.open() }
            }
        }
    }

    Card {
        title: "New Fedora release"
        visible: (page.release.available || "").length > 0
        StatusRow {
            iconName: "system-upgrade"
            title: page.releasePrepared ? "Fedora " + page.release.available + " is downloaded"
                 : page.release.ready ? "Fedora " + page.release.available + " is ready for this PC"
                 : "Fedora " + page.release.available + " is out"
            subtitle: page.releasePrepared ? "Use Install & restart above when you have no gigs coming up."
                    : page.release.ready ? "Tested by everyone for 4 weeks, and the drivers this PC needs are ready. It downloads now (a few GB) and installs on restart; do it when you have no gigs coming up."
                    : "DJOS offers it once it has been out for 4 weeks" + (page.offerDate() ? " (around " + page.offerDate() + ")" : "") + " and the drivers this PC needs are ready."
            QQC2.Button {
                visible: page.release.ready === true && !page.releasePrepared
                icon.name: "system-upgrade"
                text: "Upgrade…"
                onClicked: { confirm.action = "release-upgrade"; confirm.open() }
            }
        }
    }

    Card {
        title: "Your apps"
        visible: win.updateApps.length > 0
        Repeater {
            model: win.updateApps
            delegate: StatusRow {
                required property var modelData
                iconName: modelData.id === "richiedj" ? "richiedj" : "application-x-executable"
                title: (modelData.name || modelData.id) + (modelData.version ? "  ·  " + modelData.version : "")
                subtitle: page.appText(modelData.state)
            }
        }
    }

    Card {
        title: "DJOS"
        StatusRow {
            iconName: "djos"
            warning: ["error", "not-connected"].indexOf((page.st.optimizer || {}).state) >= 0
            title: "DJOS Optimizer " + ((page.st.optimizer || {}).installed || win.sys.version || "")
            subtitle: page.optimizerText()
        }
        StatusRow {
            iconName: "plasmadiscover"
            title: "Apps from Flathub"
            subtitle: "Updated with every check (an app that is open keeps its version until you restart it)."
            QQC2.Button {
                icon.name: "plasmadiscover"
                text: "Open Discover"
                onClicked: djos.launch(["plasma-discover", "--mode", "update"])
            }
        }
        // las descargas de DJOS son públicas: esta fila aparece solo si una pide permiso, o si la PC tiene un acceso
        // guardado de antes (se puede renovar)
        StatusRow {
            visible: !page.st.connected || page.st.account === true
            iconName: "network-connect"
            title: page.st.connected ? "Connected to GitHub" : "Not connected to GitHub"
            subtitle: page.st.connected ? "Richie DJ and the DJOS updates download without an account; this saved sign-in is only used if a download asks for one."
                                        : "A DJOS download asks for GitHub access. Connect this PC once (you sign in with your browser)."
            QQC2.Button {
                icon.name: "network-connect"
                text: page.st.connected ? "Reconnect…" : "Connect…"
                flat: page.st.connected
                onClicked: win.connectGitHub()
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        opacity: 0.6
        wrapMode: Text.WordWrap
        text: page.st.time > 0 ? "Last check: " + new Date(page.st.time * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)
                              : "DJOS checks 15 minutes after you turn the PC on, and then every 6 hours."
    }

    // confirmación: instalar reinicia la PC; pasar de versión baja varios GB en una ventana que muestra el avance
    Kirigami.PromptDialog {
        id: confirm
        property string action: ""
        title: action === "release-upgrade" ? "Upgrade to Fedora " + page.release.available + "?"
             : action === "install-shutdown" ? "Install and shut down?" : "Install and restart?"
        subtitle: action === "release-upgrade"
                  ? "A window shows the download (a few GB). When it's done, the PC restarts and installs Fedora " + page.release.available + " (20-40 minutes, don't turn it off). Do it when you have no gigs coming up."
                  : "Save your work and close Richie DJ. The PC restarts, installs the updates"
                    + (page.releasePrepared ? " (20-40 minutes, don't turn it off)" : " (a few minutes)")
                    + (action === "install-shutdown" ? " and then shuts down." : " and starts again.")
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: confirm.action === "release-upgrade" ? "Upgrade" : confirm.action === "install-shutdown" ? "Install & shut down" : "Install & restart"
                icon.name: confirm.action === "release-upgrade" ? "system-upgrade" : confirm.action === "install-shutdown" ? "system-shutdown" : "system-reboot"
                onTriggered: {
                    if (confirm.action === "release-upgrade")
                        djos.launch(["konsole", "--hide-menubar", "-e", "pkexec", "/usr/libexec/djos/update", "release-upgrade"])
                    else
                        win.installUpdates(confirm.action)
                    confirm.close()
                }
            },
            Kirigami.Action {
                text: "Cancel"
                icon.name: "dialog-cancel"
                onTriggered: confirm.close()
            }
        ]
    }
}
