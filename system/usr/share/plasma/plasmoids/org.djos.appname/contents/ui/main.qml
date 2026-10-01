/*
    DJOS App Name: en la barra de arriba, el nombre de la app que se está usando (en negrita, como en un Mac), antes de
    su menú. Así se sabe de quién es el menú, y las apps sin menú global (Chrome, Firefox) también se nombran.
    Clic: Hide / Quit de esa app (todas sus ventanas). Con el escritorio en primer plano no muestra nada (no ocupa lugar).
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    TaskManager.TasksModel {
        id: tasks
        filterByScreen: false
        filterByVirtualDesktop: false
        filterByActivity: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        onActiveTaskChanged: root.refresh()
        onDataChanged: root.refresh()
        onCountChanged: root.refresh()
    }
    property string appName: ""
    function refresh() {
        const i = tasks.activeTask
        appName = i && i.valid ? (tasks.data(i, TaskManager.AbstractTasksModel.AppName) || "") : ""
    }
    Component.onCompleted: refresh()
    // como en un Mac: Hide / Quit son para todas las ventanas de esa app, no solo la del frente
    property string menuAppId: ""   // la app del clic (abrir el menú podría cambiar la ventana activa)
    property string menuAppName: ""
    function eachWindowOfApp(fn) {
        const id = root.menuAppId
        if (!id) return
        for (let r = tasks.count - 1; r >= 0; --r) {
            const i = tasks.makeModelIndex(r)
            if (tasks.data(i, TaskManager.AbstractTasksModel.AppId) === id) fn(i)
        }
    }

    fullRepresentation: MouseArea {
        id: area
        // sin app activa, nada: el menú global queda pegado al logo
        // hasta 12 de ancho (un nombre largo se corta con "…")
        Layout.preferredWidth: root.appName.length > 0 ? Math.min(label.implicitWidth + Kirigami.Units.smallSpacing * 3, Kirigami.Units.gridUnit * 12) : 0
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.fillHeight: true
        visible: root.appName.length > 0
        hoverEnabled: true
        onClicked: {
            root.menuAppId = tasks.data(tasks.activeTask, TaskManager.AbstractTasksModel.AppId) || ""
            root.menuAppName = root.appName
            menu.openRelative()
        }

        Rectangle {   // el resaltado al pasar el mouse, como los menús de al lado
            anchors.fill: parent
            anchors.topMargin: Kirigami.Units.smallSpacing / 2
            anchors.bottomMargin: Kirigami.Units.smallSpacing / 2
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.textColor
            opacity: area.containsMouse || menu.status === PlasmaExtras.Menu.Open ? 0.12 : 0
        }
        PlasmaComponents.Label {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - Kirigami.Units.smallSpacing * 2)
            text: root.appName
            font.weight: Font.Bold
            elide: Text.ElideRight
        }
        PlasmaExtras.Menu {
            id: menu
            visualParent: area
            placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
            PlasmaExtras.MenuItem {
                text: "Hide " + root.menuAppName
                icon: "window-minimize"
                onClicked: root.eachWindowOfApp(i => {
                    if (!tasks.data(i, TaskManager.AbstractTasksModel.IsMinimized)) tasks.requestToggleMinimized(i)
                })
            }
            PlasmaExtras.MenuItem {
                text: "Quit " + root.menuAppName
                icon: "application-exit"
                onClicked: root.eachWindowOfApp(i => tasks.requestClose(i))
            }
        }
    }
}
