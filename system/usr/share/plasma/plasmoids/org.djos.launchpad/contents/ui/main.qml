// DJOS Launchpad: todos los programas en pantalla completa, como el Launchpad de macOS. Se abre con el logo de DJOS
// (arriba a la izquierda), la tecla Meta y el ícono del dock (es el "menú de programas" de Plasma: X-Plasma-Provides
// org.kde.plasma.launchermenu). La lista la da /usr/libexec/djos/launchpad-apps (la del menú de Plasma, sin lo que
// DJOS esconde). Se puede ordenar a gusto:
//   escribir: busca (Enter abre el primero, Esc borra o cierra); rueda o flechas: otra página
//   arrastrar un ícono: lo cambia de lugar (contra un borde pasa de página); soltarlo abajo, en "Add to Dock", lo fija
//   en el dock
//   clic derecho en un programa: abrir, agregar o sacar del dock, ocultar; en el fondo: mostrar ocultos, orden A–Z
// Abajo a la derecha: bloquear, cerrar la sesión, reiniciar y apagar (con la confirmación de Plasma).
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // en la barra va directo el botón con el logo (la "representación completa", como el dock): el Launchpad es su
    // propia ventana (dialog), sin popup de Plasma. Como "compacta", sin una completa declarada, Plasma 6 usaba este
    // item entero y no dibujaba el botón (quedaba un hueco); con una completa vacía, la tecla Meta abría un popup vacío
    preferredRepresentation: fullRepresentation
    activationTogglesExpanded: false   // la tecla Meta abre el Launchpad (onActivated)
    Plasmoid.icon: Plasmoid.configuration.icon
    toolTipMainText: "Launchpad"
    toolTipSubText: "All your apps"

    property var apps: []                 // [{id, name, generic, comment, keywords, icon, url}]
    property var dockLaunchers: []        // lo que hay fijo en el dock de DJOS
    property string query: ""
    property bool showHidden: false
    property int page: 0

    readonly property var hiddenIds: Plasmoid.configuration.hidden || []
    readonly property var orderIds: Plasmoid.configuration.order || []

    // lo que se ve: el orden del usuario primero (lo que sigue instalado), después el resto por nombre; buscando,
    // lo que coincide (primero lo que empieza igual)
    readonly property var shown: {
        const list = ordered()
        const q = query.trim().toLowerCase()
        if (q === "")
            return list
        const starts = [], has = []
        for (const a of list) {
            const n = a.name.toLowerCase()
            if (n.startsWith(q) || n.split(/\s+/).some(w => w.startsWith(q)))
                starts.push(a)
            else if ((a.generic + " " + a.keywords + " " + a.comment + " " + a.id).toLowerCase().indexOf(q) >= 0)
                has.push(a)
        }
        return starts.concat(has)
    }
    function ordered() {
        const byId = {}
        for (const a of apps)
            byId[a.id] = a
        let list = []
        const used = {}
        for (const id of orderIds) {
            if (byId[id] && !used[id]) {
                list.push(byId[id])
                used[id] = true
            }
        }
        for (const a of apps) {
            if (!used[a.id])
                list.push(a)
        }
        if (!showHidden)
            list = list.filter(a => hiddenIds.indexOf(a.id) < 0)
        return list
    }

    function toggle() {
        if (dialog.visible)
            close()
        else
            openLaunchpad()
    }
    function openLaunchpad() {
        refresh()
        query = ""
        page = 0
        dialog.visible = true
        dialog.requestActivate()
        dialog.focusSearch()
    }
    function close() {
        appMenu.close()
        bgMenu.close()
        dialog.visible = false
        query = ""
    }

    Connections {
        target: Plasmoid
        function onActivated() { root.toggle() }
    }

    fullRepresentation: MouseArea {
        Layout.minimumWidth: height
        Layout.preferredWidth: height
        hoverEnabled: true
        onClicked: root.toggle()
        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: Math.round(parent.height * 0.1)
            source: Plasmoid.configuration.icon
            active: parent.containsMouse
        }
    }

    // ---------------------------------------------------------------- comandos
    function shq(str) { return "'" + String(str).replace(/'/g, "'\\''") + "'" }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            const out = data.stdout || ""
            if (source === root.appsCmd) {
                try { root.apps = JSON.parse(out) } catch (e) { }
            } else if (source === root.dockReadCmd) {
                root.dockLaunchers = root.parseScriptOutput(out)
            } else if (source.indexOf("djos-dock-write") >= 0) {
                root.readDock()
            }
        }
    }
    function run(cmd) { exec.connectSource(cmd) }

    readonly property string appsCmd: "/usr/libexec/djos/launchpad-apps"
    function refresh() {
        run(appsCmd)
        readDock()
    }

    // el dock de DJOS es otro widget: sus programas fijos se leen y cambian con el mismo mecanismo que usa Plasma
    // para sus scripts (evaluateScript), y el dock se entera solo (son su configuración)
    readonly property string dockFind: "var r=[];var a=panels();for(var i=0;i<a.length;i++){var w=a[i].widgets();"
        + "for(var j=0;j<w.length;j++){if(w[j].type==\"org.djos.dock\"){w[j].currentConfigGroup=[\"General\"];"
        + "var l=w[j].readConfig(\"launchers\",[]);if(typeof l===\"string\")l=l.length?l.split(\",\"):[];"
    readonly property string dockReadCmd: "busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "
        + shq(dockFind + "r=r.concat(l);}}}print(JSON.stringify(r));")
    function readDock() { run(dockReadCmd) }
    function dockWrite(js, tag) {
        run("busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s "
            + shq(dockFind + js + "}}}") + " # djos-dock-write " + tag + " " + Date.now())
    }
    function addToDock(url) {
        dockWrite("if(l.indexOf(" + JSON.stringify(url) + ")<0){l.push(" + JSON.stringify(url) + ");w[j].writeConfig(\"launchers\",l);}", "add")
    }
    function removeFromDock(url) {
        dockWrite("var k=l.indexOf(" + JSON.stringify(url) + ");if(k>=0){l.splice(k,1);w[j].writeConfig(\"launchers\",l);}", "remove")
    }
    function inDock(app) {
        return dockLaunchers.some(l => l === app.url || l.endsWith("/" + app.id) || l.endsWith(":" + app.id))
    }
    // busctl contesta: s "texto con \" escapadas"
    function parseScriptOutput(out) {
        const m = out.match(/^s "([\s\S]*)"\s*$/)
        if (!m)
            return []
        try { return JSON.parse(m[1].replace(/\\"/g, '"').replace(/\\\\/g, "\\")) } catch (e) { return [] }
    }

    function launch(app) {
        run("kstart --application " + shq(app.id))
        close()
    }
    function setHidden(app, hide) {
        const h = hiddenIds.filter(id => id !== app.id)
        if (hide)
            h.push(app.id)
        Plasmoid.configuration.hidden = h
    }
    // mover un programa delante de otro (o al final): se guarda el orden completo
    function moveApp(id, beforeId) {
        if (id === beforeId)
            return
        let ids = ordered().map(a => a.id).filter(x => x !== id)
        const k = beforeId ? ids.indexOf(beforeId) : -1
        if (k < 0)
            ids.push(id)
        else
            ids.splice(k, 0, id)
        Plasmoid.configuration.order = ids
    }

    // ---------------------------------------------------------------- la pantalla del Launchpad
    readonly property rect screenGeo: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 1920, 1080)

    PlasmaCore.Dialog {
        id: dialog
        visible: false
        type: PlasmaCore.Dialog.Normal
        flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        location: PlasmaCore.Types.Floating
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        x: root.screenGeo.x
        y: root.screenGeo.y
        function focusSearch() { searchInput.forceActiveFocus() }

        mainItem: FocusScope {
            id: pad
            width: root.screenGeo.width
            height: root.screenGeo.height
            focus: true

            readonly property int cellW: Math.round(Kirigami.Units.gridUnit * 7.5)
            readonly property int cellH: Math.round(Kirigami.Units.gridUnit * 7.2)
            readonly property int iconPx: Math.round(Kirigami.Units.gridUnit * 4)
            readonly property int topSpace: Math.round(Kirigami.Units.gridUnit * 6)
            readonly property int bottomSpace: Math.round(Kirigami.Units.gridUnit * 7)
            readonly property int cols: Math.max(1, Math.min(8, Math.floor((width - Kirigami.Units.gridUnit * 8) / cellW)))
            readonly property int rows: Math.max(1, Math.min(5, Math.floor((height - topSpace - bottomSpace) / cellH)))
            readonly property int perPage: cols * rows
            readonly property int pages: Math.max(1, Math.ceil(root.shown.length / perPage))
            onPagesChanged: if (root.page >= pages) root.page = pages - 1

            // arrastre de un ícono
            property var dragApp: null
            property point dragPos
            property string dropBefore: ""
            property bool overDockZone: false

            Keys.onEscapePressed: { if (root.query !== "") root.query = ""; else root.close() }
            Keys.onRightPressed: root.page = Math.min(pages - 1, root.page + 1)
            Keys.onLeftPressed: root.page = Math.max(0, root.page - 1)

            // fondo: oscuro y un poco transparente (se ve el escritorio detrás)
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0.03, 0.04, 0.07, 0.82)
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        bgAnchor.x = mouse.x
                        bgAnchor.y = mouse.y
                        bgMenu.openRelative()
                    } else
                        root.close()
                }
                onWheel: wheel => {
                    if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0)
                        root.page = Math.min(pad.pages - 1, root.page + 1)
                    else
                        root.page = Math.max(0, root.page - 1)
                }
            }
            Item { id: bgAnchor; width: 1; height: 1 }

            // búsqueda
            Rectangle {
                id: searchBox
                width: Math.round(Kirigami.Units.gridUnit * 16)
                height: Math.round(Kirigami.Units.gridUnit * 2)
                radius: height / 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(pad.topSpace * 0.42)
                color: Qt.rgba(1, 1, 1, 0.10)
                border.color: searchInput.activeFocus ? Qt.rgba(0.04, 0.52, 1, 0.9) : Qt.rgba(1, 1, 1, 0.16)
                Kirigami.Icon {
                    id: searchIcon
                    source: "search"
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round(parent.height * 0.4)
                    color: "#d8d8dc"
                    isMask: true
                }
                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(parent.height * 0.5)
                    anchors.verticalCenter: parent.verticalCenter
                    color: "#f2f2f4"
                    selectionColor: "#0a64d7"
                    font.family: Kirigami.Theme.defaultFont.family
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    clip: true
                    text: root.query
                    onTextEdited: { root.query = text; root.page = 0 }
                    Keys.onReturnPressed: if (root.shown.length > 0) root.launch(root.shown[0])
                    Keys.onEnterPressed: if (root.shown.length > 0) root.launch(root.shown[0])
                    Keys.onEscapePressed: { if (root.query !== "") root.query = ""; else root.close() }
                    Keys.onRightPressed: event => { if (cursorPosition === text.length && text === "") root.page = Math.min(pad.pages - 1, root.page + 1); else event.accepted = false }
                    Text {
                        visible: parent.text === ""
                        text: "Search"
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font: parent.font
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // las páginas
            ListView {
                id: pagesView
                x: Math.round((parent.width - pad.cols * pad.cellW) / 2)
                y: pad.topSpace
                width: pad.cols * pad.cellW
                height: pad.rows * pad.cellH
                orientation: ListView.Horizontal
                snapMode: ListView.SnapOneItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 260
                boundsBehavior: Flickable.StopAtBounds
                interactive: pad.dragApp === null
                clip: true      // si no, se ve el principio de la página siguiente
                model: pad.pages
                currentIndex: root.page
                onCurrentIndexChanged: root.page = currentIndex
                delegate: Item {
                    id: pageItem
                    required property int index
                    width: pagesView.width
                    height: pagesView.height
                    Grid {
                        columns: pad.cols
                        Repeater {
                            model: root.shown.slice(pageItem.index * pad.perPage, (pageItem.index + 1) * pad.perPage)
                            delegate: Item {
                                id: cell
                                required property var modelData
                                width: pad.cellW
                                height: pad.cellH
                                readonly property bool isHidden: root.hiddenIds.indexOf(modelData.id) >= 0
                                readonly property bool dragged: pad.dragApp !== null && pad.dragApp.id === modelData.id
                                readonly property bool dropHere: pad.dragApp !== null && pad.dropBefore === modelData.id && !dragged
                                // marca de "va acá"
                                Rectangle {
                                    visible: cell.dropHere
                                    width: 3
                                    radius: 1.5
                                    height: pad.iconPx
                                    x: 0
                                    y: Math.round(pad.cellH * 0.08)
                                    color: "#0a84ff"
                                }
                                Kirigami.Icon {
                                    id: appIcon
                                    source: cell.modelData.icon
                                    width: pad.iconPx
                                    height: width
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: Math.round(pad.cellH * 0.08)
                                    opacity: cell.dragged ? 0.25 : cell.isHidden ? 0.4 : 1
                                    scale: cellMouse.pressed && !cell.dragged ? 0.92 : 1
                                    Behavior on scale { NumberAnimation { duration: 90 } }
                                    animated: false
                                }
                                Text {
                                    anchors.top: appIcon.bottom
                                    anchors.topMargin: Kirigami.Units.smallSpacing * 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: pad.cellW - Kirigami.Units.smallSpacing * 2
                                    horizontalAlignment: Text.AlignHCenter
                                    text: cell.modelData.name
                                    color: "#f2f2f4"
                                    opacity: cell.isHidden ? 0.5 : 1
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    font.family: Kirigami.Theme.defaultFont.family
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.35)
                                }
                                MouseArea {
                                    id: cellMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    property point start
                                    property bool moved: false
                                    onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); moved = false }
                                    onPositionChanged: mouse => {
                                        if (!(mouse.buttons & Qt.LeftButton))
                                            return
                                        const p = mapToItem(pad, mouse.x, mouse.y)
                                        if (pad.dragApp === null && Math.hypot(mouse.x - start.x, mouse.y - start.y) > 12) {
                                            pad.dragApp = cell.modelData
                                            moved = true
                                        }
                                        if (pad.dragApp !== null)
                                            pad.dragMove(p.x, p.y)
                                    }
                                    onReleased: mouse => { if (pad.dragApp !== null) pad.dragEnd() }
                                    onClicked: mouse => {
                                        if (moved)
                                            return
                                        if (mouse.button === Qt.RightButton)
                                            root.openAppMenu(cell.modelData, cell)
                                        else
                                            root.launch(cell.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // arrastrar: dónde va (antes de qué programa), pasar de página contra los bordes, soltar en el dock
            function dragMove(px, py) {
                dragPos = Qt.point(px, py)
                overDockZone = py > height - bottomSpace * 0.75
                const lx = px - pagesView.x, ly = py - pagesView.y
                if (!overDockZone && lx >= 0 && lx < pagesView.width && ly >= 0 && ly < pagesView.height) {
                    const c = Math.min(cols - 1, Math.floor(lx / cellW)), r = Math.min(rows - 1, Math.floor(ly / cellH))
                    const idx = root.page * perPage + r * cols + c + (lx % cellW > cellW / 2 ? 1 : 0)
                    dropBefore = idx < root.shown.length ? root.shown[idx].id : ""
                }
                flipTimer.dir = px < Kirigami.Units.gridUnit * 3 ? -1 : px > width - Kirigami.Units.gridUnit * 3 ? 1 : 0
                flipTimer.running = flipTimer.dir !== 0
            }
            function dragEnd() {
                const app = dragApp
                flipTimer.running = false
                if (overDockZone)
                    root.addToDock(app.url)
                else if (root.query === "")
                    root.moveApp(app.id, dropBefore)
                dragApp = null
                dropBefore = ""
                overDockZone = false
            }
            Timer {
                id: flipTimer
                property int dir: 0
                interval: 650
                repeat: true
                onTriggered: root.page = Math.max(0, Math.min(pad.pages - 1, root.page + dir))
            }

            // el ícono que se arrastra
            Kirigami.Icon {
                visible: pad.dragApp !== null
                source: pad.dragApp ? pad.dragApp.icon : ""
                width: pad.iconPx
                height: width
                x: pad.dragPos.x - width / 2
                y: pad.dragPos.y - height / 2
                opacity: 0.9
                animated: false
            }

            // franja para fijar en el dock (aparece al arrastrar)
            Rectangle {
                visible: pad.dragApp !== null
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - pad.bottomSpace * 0.7
                width: Math.round(Kirigami.Units.gridUnit * 18)
                height: Math.round(Kirigami.Units.gridUnit * 3)
                radius: Math.round(height * 0.3)
                color: pad.overDockZone ? Qt.rgba(0.04, 0.52, 1, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                border.color: pad.overDockZone ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.25)
                Text {
                    anchors.centerIn: parent
                    text: pad.dragApp && root.inDock(pad.dragApp) ? "Already in the Dock" : "Drop here to add to the Dock"
                    color: "#f2f2f4"
                    font.family: Kirigami.Theme.defaultFont.family
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                }
            }

            // puntitos de las páginas
            Row {
                visible: pad.pages > 1 && pad.dragApp === null
                anchors.horizontalCenter: parent.horizontalCenter
                y: pagesView.y + pagesView.height + Kirigami.Units.gridUnit
                spacing: Kirigami.Units.smallSpacing * 3
                Repeater {
                    model: pad.pages
                    delegate: Rectangle {
                        required property int index
                        width: 8
                        height: 8
                        radius: 4
                        color: index === root.page ? "#f2f2f4" : Qt.rgba(1, 1, 1, 0.3)
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.page = parent.index }
                    }
                }
            }

            // sin resultados
            Text {
                visible: root.shown.length === 0 && root.apps.length > 0
                anchors.centerIn: parent
                text: "No apps found"
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.3
            }

            // bloquear, cerrar la sesión, reiniciar, apagar
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Kirigami.Units.gridUnit * 1.5
                spacing: Kirigami.Units.smallSpacing * 3
                Repeater {
                    model: [
                        { icon: "system-lock-screen", text: "Lock", cmd: "loginctl lock-session" },
                        { icon: "system-log-out", text: "Log Out", cmd: "busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptLogout" },
                        { icon: "system-reboot", text: "Restart", cmd: "busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptReboot" },
                        { icon: "system-shutdown", text: "Shut Down", cmd: "busctl --user call org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt promptShutDown" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: Math.round(Kirigami.Units.gridUnit * 2.4)
                        height: width
                        radius: width / 2
                        color: powerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Kirigami.Units.iconSizes.smallMedium
                            height: width
                            source: parent.modelData.icon
                            color: "#f2f2f4"
                            isMask: true
                        }
                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: { root.close(); root.run(parent.modelData.cmd) }
                        }
                        PlasmaCore.ToolTipArea {
                            anchors.fill: parent
                            mainText: parent.modelData.text
                        }
                    }
                }
            }
            Item { id: appAnchor; width: 1; height: 1 }
        }
    }

    // ---------------------------------------------------------------- menús del clic derecho
    property var menuApp: null
    function openAppMenu(app, cellItem) {
        menuApp = app
        const p = cellItem.mapToItem(pad, cellItem.width / 2, pad.iconPx * 0.6)
        appAnchor.x = p.x
        appAnchor.y = p.y
        appMenu.openRelative()
    }
    PlasmaExtras.Menu {
        id: appMenu
        visualParent: appAnchor
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
        PlasmaExtras.MenuItem {
            section: true
            text: root.menuApp ? root.menuApp.name : ""
        }
        PlasmaExtras.MenuItem {
            text: "Open"
            icon: "media-playback-start"
            onClicked: if (root.menuApp) root.launch(root.menuApp)
        }
        PlasmaExtras.MenuItem {
            visible: root.menuApp !== null && !root.inDock(root.menuApp)
            text: "Add to Dock"
            icon: "window-pin"
            onClicked: root.addToDock(root.menuApp.url)
        }
        PlasmaExtras.MenuItem {
            visible: root.menuApp !== null && root.inDock(root.menuApp)
            text: "Remove from Dock"
            icon: "window-unpin"
            onClicked: root.removeFromDock(root.menuApp.url)
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem {
            visible: root.menuApp !== null && root.hiddenIds.indexOf(root.menuApp.id) < 0
            text: "Hide from Launchpad"
            icon: "view-hidden"
            onClicked: root.setHidden(root.menuApp, true)
        }
        PlasmaExtras.MenuItem {
            visible: root.menuApp !== null && root.hiddenIds.indexOf(root.menuApp.id) >= 0
            text: "Show in Launchpad"
            icon: "view-visible"
            onClicked: root.setHidden(root.menuApp, false)
        }
    }
    PlasmaExtras.Menu {
        id: bgMenu
        visualParent: bgAnchor
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
        PlasmaExtras.MenuItem {
            text: root.showHidden ? "Hide Hidden Apps" : "Show Hidden Apps (" + root.hiddenIds.length + ")"
            icon: root.showHidden ? "view-hidden" : "view-visible"
            enabled: root.hiddenIds.length > 0 || root.showHidden
            onClicked: root.showHidden = !root.showHidden
        }
        PlasmaExtras.MenuItem {
            text: "Sort A–Z"
            icon: "view-sort-ascending-name"
            enabled: root.orderIds.length > 0
            onClicked: Plasmoid.configuration.order = []
        }
    }

    Component.onCompleted: refresh()
}
