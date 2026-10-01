// DJOS Dock: el dock de DJOS Glass. Los programas fijos y abiertos (el modelo de tareas de Plasma, agrupados por
// programa), el Launchpad y la papelera, sobre un fondo de vidrio propio (la barra del panel es transparente: el tema de
// Plasma "DJOS Glass"). Al pasar el mouse los íconos crecen como en macOS: el de abajo del puntero hasta "zoom" veces y
// los vecinos menos (una campana), corriéndose hacia los costados; el punto debajo del puntero queda quieto. El panel es
// más alto que el dock (lugar para crecer y para el nombre del programa) y no reserva espacio: se esconde cuando una
// ventana lo toca ("dodge windows") y vuelve con el mouse abajo.
//   clic: abre el programa, o lo trae (si ya está adelante, lo minimiza; con varias ventanas, pasa a la siguiente)
//   clic del medio: otra ventana; clic derecho: abrir, ventana nueva, dejar o sacar del dock, cerrar
//   arrastrar un ícono: de costado lo cambia de lugar; hacia arriba, afuera del dock, lo saca (como en macOS)
//   soltar en el dock: un programa (.desktop, desde Dolphin o un menú) lo agrega donde cae; archivos sobre un programa
//   los abren con ese programa; sobre la papelera, van a la papelera
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    // ---------------------------------------------------------------- medidas (todo a 1x; Plasma escala en HiDPI)
    readonly property int iconSize: Plasmoid.configuration.iconSize
    readonly property real maxZoom: Plasmoid.configuration.zoom
    readonly property int gap: Math.round(iconSize * 0.16)          // entre íconos
    readonly property int slot: iconSize + gap
    readonly property int padTop: Math.round(iconSize * 0.16)
    readonly property int padBottom: Math.round(iconSize * 0.24)     // con lugar para el indicador
    readonly property int padSide: Math.round(iconSize * 0.16)
    readonly property int floatGap: 6                                // del borde de la pantalla al dock
    readonly property int sepWidth: Math.round(iconSize * 0.34)
    readonly property real sigma: 1.15                               // ancho de la lupa, en íconos
    readonly property int bgHeight: iconSize + padTop + padBottom
    // lo que hace falta a cada costado para que el dock crezca sin cortarse
    readonly property int slack: Math.ceil(slot * (maxZoom - 1) * sigma * 2.6)

    readonly property int count: tasksModel.count
    readonly property int padSlot: count + 1                         // Launchpad
    readonly property int trashSlot: count + 2
    readonly property int nSlots: count + 3                          // + separador + Launchpad + papelera
    readonly property real baseRowWidth: count * slot + sepWidth + 2 * slot

    // la lupa: dónde está el mouse (en coordenadas del dock sin agrandar) y cuánto está prendida (0..1)
    property real mouseU: 0
    property bool zooming: false
    property real zoomAmt: zooming ? 1 : 0
    Behavior on zoomAmt { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property var lay: computeLayout()

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    function baseWidth(j) { return j === count ? sepWidth : slot }

    // ancho y escala de cada lugar, su posición, y adónde fue a parar el punto debajo del mouse (F)
    function computeLayout() {
        const n = nSlots
        const s = [], w = [], x = []
        let c0 = 0
        for (let j = 0; j < n; ++j) {
            const w0 = baseWidth(j)
            let sj = 1
            if (j !== count && zoomAmt > 0) {
                const d = (c0 + w0 / 2 - mouseU) / slot
                sj = 1 + (maxZoom - 1) * zoomAmt * Math.exp(-d * d / (2 * sigma * sigma))
            }
            s.push(sj)
            w.push(j === count ? w0 : w0 * sj)
            c0 += w0
        }
        let total = 0
        for (let j = 0; j < n; ++j) { x.push(total); total += w[j] }
        let acc = 0, accb = 0, F = mouseU
        for (let j = 0; j < n; ++j) {
            const w0 = baseWidth(j)
            if (mouseU < accb + w0 || j === n - 1) {
                F = acc + Math.max(0, mouseU - accb) * (w[j] / w0)
                break
            }
            acc += w[j]
            accb += w0
        }
        return { s: s, w: w, x: x, total: total, F: F }
    }

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

    // ---------------------------------------------------------------- tareas (las de Plasma)
    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }

    TaskManager.TasksModel {
        id: tasksModel
        activity: activityInfo.currentActivity
        virtualDesktop: virtualDesktopInfo.currentDesktop
        filterByActivity: true
        filterByVirtualDesktop: false
        filterByScreen: false
        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        sortMode: TaskManager.TasksModel.SortManual
        separateLaunchers: false
        launchInPlace: true
        hideActivatedLaunchers: true
        launcherList: Plasmoid.configuration.launchers
        onLauncherListChanged: {
            if (JSON.stringify(Plasmoid.configuration.launchers) !== JSON.stringify(launcherList))
                Plasmoid.configuration.launchers = launcherList
        }
    }

    // ---------------------------------------------------------------- comandos (Launchpad, papelera)
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: source => disconnectSource(source)
    }
    function run(cmd) { exec.connectSource(cmd) }

    // la papelera llena o vacía (barato: un "ls" cada 5 s)
    P5Support.DataSource {
        id: trashState
        engine: "executable"
        interval: 5000
        connectedSources: ["sh -c 'ls -A \"${XDG_DATA_HOME:-$HOME/.local/share}/Trash/files\" 2>/dev/null | head -c 1'"]
        property bool full: false
        onNewData: (source, data) => { full = (data.stdout || "").length > 0 }
    }

    // ---------------------------------------------------------------- un ícono del dock
    component DockIcon: Item {
        id: di
        property int slotIndex: 0
        property var iconSource
        property string name: ""
        property bool running: false
        property bool active: false
        property bool attention: false
        property bool launching: false
        property real bounceY: 0
        readonly property real sc: root.lay.s[slotIndex] || 1
        readonly property bool ghost: root.dragging && root.dragSlot === slotIndex

        x: root.rowLeft + (root.lay.x[slotIndex] || 0)
        width: root.lay.w[slotIndex] || root.slot
        height: parent ? parent.height : 0

        // el ícono se dibuja una sola vez, al tamaño más grande, y la lupa lo escala en la placa de video: si cambiara
        // de tamaño en cada cuadro, Plasma lo volvería a pintar desde el SVG cada vez (lento, y mientras tanto se ve
        // la imagen anterior)
        Kirigami.Icon {
            id: icon
            source: di.iconSource
            readonly property real full: Math.ceil(root.iconSize * root.maxZoom)
            width: full
            height: full
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.bgBottom - root.padBottom - full - di.bounceY
            transformOrigin: Item.Bottom
            scale: di.sc / root.maxZoom
            roundToIconSize: false
            smooth: true
            animated: false
            opacity: di.ghost ? 0.25 : di.pressed ? 0.7 : 1
        }
        property bool pressed: false

        // indicador: un punto para "abierta", una píldora azul para la que está adelante
        Rectangle {
            visible: di.running
            width: di.active ? Math.round(root.iconSize * 0.36) : 5
            height: 5
            radius: 2.5
            color: di.attention ? "#ffd60a" : di.active ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.72)
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.bgBottom - Math.round(root.padBottom / 2) - 2
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        // rebota mientras el programa arranca
        SequentialAnimation on bounceY {
            running: di.launching
            loops: Animation.Infinite
            NumberAnimation { to: root.iconSize * 0.42; duration: 280; easing.type: Easing.OutQuad }
            NumberAnimation { to: 0; duration: 280; easing.type: Easing.InQuad }
            PauseAnimation { duration: 80 }
        }
        onLaunchingChanged: if (!launching) bounceY = 0
    }

    // ---------------------------------------------------------------- geometría en pantalla
    property real dockWidth: 0
    property real dockHeight: 0
    readonly property real bgBottom: dockHeight - floatGap
    readonly property real bgTop: bgBottom - bgHeight
    readonly property real baseLeft: (dockWidth - baseRowWidth) / 2        // primer lugar, sin agrandar
    readonly property real rowLeft: clamp(baseLeft + (mouseU - lay.F), padSide, dockWidth - padSide - lay.total)

    fullRepresentation: Item {
        id: dock
        Layout.minimumWidth: root.baseRowWidth + 2 * root.padSide + 2 * root.slack
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true
        onWidthChanged: root.dockWidth = width
        onHeightChanged: root.dockHeight = height
        Component.onCompleted: {
            root.dockWidth = width
            root.dockHeight = height
            root.taskRepeater = taskRepeater
            root.padIcon = padIcon
            root.trashIcon = trashIcon
            root.menuAnchor = menuAnchor
        }

        // fondo de vidrio (crece con la lupa)
        Rectangle {
            x: root.rowLeft - root.padSide
            width: root.lay.total + 2 * root.padSide
            y: root.bgTop
            height: root.bgHeight
            radius: Math.round(root.iconSize * 0.42)
            color: Qt.rgba(0.10, 0.10, 0.11, 0.74)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
        }

        // separador antes del Launchpad
        Rectangle {
            x: root.rowLeft + (root.lay.x[root.count] || 0) + root.sepWidth / 2
            width: 1
            height: Math.round(root.iconSize * 0.72)
            y: root.bgTop + (root.bgHeight - height) / 2
            color: Qt.rgba(1, 1, 1, 0.2)
        }

        Repeater {
            id: taskRepeater
            model: tasksModel
            delegate: DockIcon {
                required property int index
                required property var model
                property bool clicked: false      // rebote al abrirlo, hasta que aparece la ventana
                slotIndex: index
                iconSource: model.decoration
                name: model.AppName || model.display || ""
                running: model.IsLauncher !== true && model.IsStartup !== true
                active: model.IsActive === true
                attention: model.IsDemandingAttention === true
                launching: model.IsStartup === true || clicked
                onRunningChanged: if (running) clicked = false
                Timer { running: parent.clicked; interval: 8000; onTriggered: parent.clicked = false }
            }
        }

        DockIcon {
            id: padIcon
            slotIndex: root.padSlot
            iconSource: "djos-launchpad"
            name: "Launchpad"
        }
        DockIcon {
            id: trashIcon
            slotIndex: root.trashSlot
            iconSource: trashState.full ? "user-trash-full" : "user-trash"
            name: "Trash"
        }

        // dónde queda lo que se arrastra (entre dos íconos)
        Rectangle {
            visible: root.dropIndex >= 0 && !root.dragRemove
            width: 3
            radius: 1.5
            height: root.iconSize
            color: "#0a84ff"
            x: root.rowLeft + (root.lay.x[Math.min(root.dropIndex, root.count)] || 0) - 1.5
            y: root.bgBottom - root.padBottom - height
        }
        // el ícono que se arrastra, pegado al mouse
        Kirigami.Icon {
            visible: root.dragging
            source: root.dragging && root.itemAt(root.dragSlot) ? root.itemAt(root.dragSlot).iconSource : ""
            width: Math.round(root.iconSize * 1.15)
            height: width
            x: root.dragX - width / 2
            y: root.dragY - height / 2
            opacity: root.dragRemove ? 0.45 : 0.95
            roundToIconSize: false
            animated: false
        }
        Rectangle {
            visible: root.dragRemove && root.dragCanRemove
            height: removeText.implicitHeight + 8
            width: removeText.implicitWidth + 22
            radius: height / 2
            color: Qt.rgba(0.13, 0.13, 0.14, 0.94)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            x: root.clamp(root.dragX - width / 2, 0, dock.width - width)
            y: root.bgTop + 4
            Text {
                id: removeText
                anchors.centerIn: parent
                text: "Remove from Dock"
                color: "#ececee"
                font.family: Kirigami.Theme.defaultFont.family
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
            }
        }

        // nombre del programa, arriba del ícono
        Rectangle {
            id: label
            readonly property Item target: root.hoverItem
            visible: opacity > 0
            opacity: target && root.zoomAmt > 0.5 && !menu.shown && !root.dragging ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            height: labelText.implicitHeight + 8
            width: labelText.implicitWidth + 22
            radius: height / 2
            color: Qt.rgba(0.13, 0.13, 0.14, 0.94)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            x: target ? root.clamp(target.x + target.width / 2 - width / 2, 0, dock.width - width) : x
            y: target ? root.bgBottom - root.padBottom - root.iconSize * target.sc - height - 8 : y
            Text {
                id: labelText
                anchors.centerIn: parent
                text: label.target ? label.target.name : ""
                color: "#ececee"
                font.family: Kirigami.Theme.defaultFont.family
                font.pointSize: Kirigami.Theme.defaultFont.pointSize
                font.weight: Font.Medium
            }
        }

        // el lugar del menú del clic derecho
        Item { id: menuAnchor; width: 1; height: 1 }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            property point pressPos
            property int pressSlot: -1
            property bool wasDrag: false
            // sobre el dock (o sobre los íconos agrandados que salen por arriba)
            readonly property bool overDock: containsMouse
                && mouseY >= root.bgTop - root.iconSize * (root.maxZoom - 1) * root.zoomAmt - 2
                && mouseX >= root.rowLeft - root.padSide && mouseX <= root.rowLeft + root.lay.total + root.padSide
            onOverDockChanged: if (!root.dragging && !root.extDrag) root.zooming = overDock
            onContainsMouseChanged: if (!containsMouse && !root.dragging && !root.extDrag) root.zooming = false
            onPositionChanged: mouse => {
                if (pressSlot >= 0 && pressSlot < root.count && (mouse.buttons & Qt.LeftButton) && !root.dragging
                        && Math.hypot(mouse.x - pressPos.x, mouse.y - pressPos.y) > 10)
                    root.startDrag(pressSlot)
                if (root.dragging) {
                    root.dragX = mouse.x
                    root.dragY = mouse.y
                    root.dropIndex = root.dragRemove ? -1 : root.insertIndexAt(mouse.x)
                    return
                }
                if (overDock)
                    root.mouseU = root.clamp(mouse.x - root.baseLeft, 0, root.baseRowWidth)
                root.hoverSlot = overDock ? root.slotAt(mouse.x) : -1
            }
            onPressed: mouse => {
                pressPos = Qt.point(mouse.x, mouse.y)
                pressSlot = overDock && mouse.button === Qt.LeftButton ? root.slotAt(mouse.x) : -1
                wasDrag = false
                const it = root.itemAt(root.slotAt(mouse.x))
                if (it)
                    it.pressed = true
            }
            onReleased: mouse => {
                root.clearPressed()
                pressSlot = -1
                if (root.dragging) {
                    wasDrag = true
                    root.finishDrag()
                    root.zooming = overDock
                }
            }
            onCanceled: {
                root.clearPressed()
                pressSlot = -1
                root.cancelDrag()
            }
            onClicked: mouse => {
                if (wasDrag || !overDock)
                    return
                const j = root.slotAt(mouse.x)
                if (j < 0)
                    return
                if (j < root.count)
                    root.taskClicked(j, mouse.button)
                else if (j === root.padSlot && mouse.button === Qt.LeftButton)
                    root.run("busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell activateLauncherMenu")
                else if (j === root.trashSlot && mouse.button === Qt.LeftButton)
                    Qt.openUrlExternally("trash:/")
                else if (j === root.trashSlot && mouse.button === Qt.RightButton)
                    root.openMenu(j)
            }
        }

        // soltar cosas en el dock (desde Dolphin, el escritorio, un menú…)
        DropArea {
            anchors.fill: parent
            property bool apps: false        // programas (.desktop): se agregan
            function track(drag) {
                root.extDrag = true
                root.zooming = true
                root.mouseU = root.clamp(drag.x - root.baseLeft, 0, root.baseRowWidth)
                const j = root.slotAt(drag.x)
                root.hoverSlot = apps ? -1 : j
                root.dropIndex = apps ? root.insertIndexAt(drag.x) : -1
            }
            onEntered: drag => {
                const urls = (drag.urls || []).map(u => String(u))
                apps = urls.length > 0 && urls.every(u => u.endsWith(".desktop") || u.startsWith("applications:"))
                if (urls.length === 0) {
                    drag.accepted = false
                    return
                }
                drag.accept(Qt.CopyAction)
                track(drag)
            }
            onPositionChanged: drag => track(drag)
            onExited: root.endExtDrag()
            onDropped: drop => {
                const urls = (drop.urls || []).map(u => String(u))
                if (apps)
                    root.addLaunchers(urls, root.insertIndexAt(drop.x))
                else {
                    const j = root.slotAt(drop.x)
                    if (j >= 0 && j < root.count)
                        tasksModel.requestOpenUrls(tasksModel.makeModelIndex(j), urls)
                    else if (j === root.trashSlot)
                        root.run("kioclient move " + urls.map(u => root.shq(u)).join(" ") + " trash:/")
                }
                drop.accept(Qt.CopyAction)
                root.endExtDrag()
            }
        }
    }

    // ---------------------------------------------------------------- arrastrar y soltar
    property bool dragging: false
    property int dragSlot: -1
    property real dragX: 0
    property real dragY: 0
    property int dropIndex: -1           // entre qué íconos va a quedar (0..count)
    property bool extDrag: false         // algo de afuera arriba del dock
    // hacia arriba, afuera del dock: se saca (solo si está fijo; una ventana abierta sin fijar no se puede sacar)
    readonly property bool dragRemove: dragging && dragY < bgTop - iconSize * 0.9
    readonly property bool dragCanRemove: dragging && itemAt(dragSlot) !== null && itemAt(dragSlot).model.HasLauncher === true

    function insertIndexAt(px) {
        for (let j = 0; j < count; ++j) {
            if (px < rowLeft + lay.x[j] + lay.w[j] / 2)
                return j
        }
        return count
    }
    function startDrag(j) {
        zooming = false
        hoverSlot = -1
        dragSlot = j
        dragging = true
    }
    function cancelDrag() {
        dragging = false
        dragSlot = -1
        dropIndex = -1
    }
    function finishDrag() {
        const j = dragSlot
        const it = itemAt(j)
        if (dragRemove) {
            if (it && it.model.HasLauncher === true)
                tasksModel.requestRemoveLauncher(it.model.LauncherUrlWithoutIcon)
        } else if (dropIndex >= 0 && it) {
            const to = dropIndex > j ? dropIndex - 1 : dropIndex
            if (to !== j) {
                tasksModel.move(j, to)
                tasksModel.syncLaunchers()
            }
        }
        cancelDrag()
    }
    function endExtDrag() {
        extDrag = false
        dropIndex = -1
        hoverSlot = -1
        zooming = false
    }
    // programas soltados en el dock: quedan fijos donde se soltaron (el nuevo aparece al final y se mueve)
    function addLaunchers(urls, pos) {
        for (const u of urls) {
            if (!tasksModel.requestAddLauncher(u))
                continue
            const name = u.split("/").pop().replace(/^applications:/, "")
            let from = -1
            for (let j = 0; j < count; ++j) {
                const lu = String(tasksModel.data(tasksModel.makeModelIndex(j), TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) || "")
                if (lu === u || lu.endsWith("/" + name) || lu.endsWith(":" + name))
                    from = j
            }
            if (from >= 0 && from !== pos) {
                tasksModel.move(from, pos > from ? pos - 1 : pos)
            }
            pos += 1
        }
        tasksModel.syncLaunchers()
    }
    function shq(str) { return "'" + str.replace(/'/g, "'\\''") + "'" }

    // lo que vive adentro de la representación (desde acá no se ve por su id)
    property Item taskRepeater: null
    property Item padIcon: null
    property Item trashIcon: null
    property Item menuAnchor: null

    property int hoverSlot: -1
    readonly property Item hoverItem: itemAt(hoverSlot)

    function slotAt(px) {
        for (let j = 0; j < nSlots; ++j) {
            const x0 = rowLeft + lay.x[j]
            if (px >= x0 && px < x0 + lay.w[j])
                return j === count ? -1 : j
        }
        return -1
    }
    function itemAt(j) {
        if (j < 0)
            return null
        if (j < count)
            return taskRepeater ? taskRepeater.itemAt(j) : null
        if (j === padSlot)
            return padIcon
        if (j === trashSlot)
            return trashIcon
        return null
    }
    function clearPressed() {
        for (let j = 0; j < nSlots; ++j) {
            const it = itemAt(j)
            if (it)
                it.pressed = false
        }
    }

    function taskClicked(j, button) {
        const idx = tasksModel.makeModelIndex(j)
        const it = itemAt(j)
        if (!it)
            return
        const m = it.model
        if (button === Qt.RightButton) {
            openMenu(j)
        } else if (button === Qt.MiddleButton) {
            tasksModel.requestNewInstance(idx)
            it.clicked = true
        } else if (m.IsLauncher === true) {
            tasksModel.requestActivate(idx)
            it.clicked = true
        } else if (m.IsGroupParent === true && m.ChildCount > 1) {
            // varias ventanas: a la siguiente si ya está adelante, si no a la última que se usó
            const n = m.ChildCount
            let activeChild = -1, best = 0, bestT = -1
            for (let c = 0; c < n; ++c) {
                const ci = tasksModel.makeModelIndex(j, c)
                if (tasksModel.data(ci, TaskManager.AbstractTasksModel.IsActive) === true)
                    activeChild = c
                const t = tasksModel.data(ci, TaskManager.AbstractTasksModel.LastActivated)
                const tv = t ? new Date(t).getTime() : 0
                if (tv > bestT) { bestT = tv; best = c }
            }
            tasksModel.requestActivate(tasksModel.makeModelIndex(j, activeChild >= 0 ? (activeChild + 1) % n : best))
        } else if (m.IsActive === true) {
            tasksModel.requestToggleMinimized(idx)
        } else {
            tasksModel.requestActivate(idx)
        }
    }

    // ---------------------------------------------------------------- menú del clic derecho
    property int menuSlot: -1
    readonly property var menuModel: menuSlot >= 0 && menuSlot < count && itemAt(menuSlot) ? itemAt(menuSlot).model : null
    readonly property bool menuIsTrash: menuSlot === trashSlot

    function openMenu(j) {
        const it = itemAt(j)
        if (!it || !menuAnchor)
            return
        menuSlot = j
        menuAnchor.x = it.x + it.width / 2
        menuAnchor.y = bgTop - iconSize * (maxZoom - 1) * zoomAmt
        menu.openRelative()
    }

    PlasmaExtras.Menu {
        id: menu
        property bool shown: false
        visualParent: root.menuAnchor
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
        onStatusChanged: shown = status !== PlasmaExtras.Menu.Closed

        PlasmaExtras.MenuItem {
            section: true
            text: root.menuIsTrash ? "Trash" : (root.menuModel ? (root.menuModel.AppName || root.menuModel.display || "") : "")
        }
        PlasmaExtras.MenuItem {
            visible: root.menuIsTrash
            text: "Open"
            icon: "document-open-folder"
            onClicked: Qt.openUrlExternally("trash:/")
        }
        PlasmaExtras.MenuItem {
            visible: root.menuIsTrash && trashState.full
            text: "Empty Trash"
            icon: "trash-empty"
            onClicked: root.run("ktrash6 --empty")
        }
        PlasmaExtras.MenuItem {
            visible: root.menuModel !== null && root.menuModel.IsLauncher === true
            text: "Open"
            icon: "media-playback-start"
            onClicked: { tasksModel.requestActivate(tasksModel.makeModelIndex(root.menuSlot)); const it = root.itemAt(root.menuSlot); if (it) it.clicked = true }
        }
        PlasmaExtras.MenuItem {
            visible: root.menuModel !== null && root.menuModel.IsLauncher !== true && root.menuModel.CanLaunchNewInstance === true
            text: "New Window"
            icon: "window-new"
            onClicked: tasksModel.requestNewInstance(tasksModel.makeModelIndex(root.menuSlot))
        }
        PlasmaExtras.MenuItem {
            visible: root.menuModel !== null && root.menuModel.HasLauncher !== true && String(root.menuModel.LauncherUrlWithoutIcon || "") !== ""
            text: "Keep in Dock"
            icon: "window-pin"
            onClicked: tasksModel.requestAddLauncher(root.menuModel.LauncherUrl)
        }
        PlasmaExtras.MenuItem {
            visible: root.menuModel !== null && root.menuModel.HasLauncher === true
            text: "Remove from Dock"
            icon: "window-unpin"
            onClicked: tasksModel.requestRemoveLauncher(root.menuModel.LauncherUrlWithoutIcon)
        }
        PlasmaExtras.MenuItem {
            visible: root.menuModel !== null && root.menuModel.IsLauncher !== true
            separator: true
        }
        PlasmaExtras.MenuItem {
            visible: root.menuModel !== null && root.menuModel.IsLauncher !== true
            text: root.menuModel && root.menuModel.ChildCount > 1 ? "Close All Windows" : "Close"
            icon: "window-close"
            onClicked: tasksModel.requestClose(tasksModel.makeModelIndex(root.menuSlot))
        }
    }
}
