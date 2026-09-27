// DJOS: fija Richie DJ en la barra de tareas (lo corre "notices" al iniciar sesión, una vez, cuando la app ya está).
// Si la barra todavía tiene los lanzadores por defecto, se conservan y Richie DJ va primero.
if (applicationExists("richiedj.desktop")) {
    var defaults = ["applications:systemsettings.desktop", "applications:org.kde.discover.desktop",
                    "preferred://filemanager", "preferred://browser"];
    var all = panels();
    for (var i = 0; i < all.length; ++i) {
        var widgets = all[i].widgets();
        for (var j = 0; j < widgets.length; ++j) {
            var w = widgets[j];
            if (w.type !== "org.kde.plasma.icontasks" && w.type !== "org.kde.plasma.taskmanager")
                continue;
            w.currentConfigGroup = ["General"];
            var current = w.readConfig("launchers", []);
            if (typeof current === "string")
                current = current.length > 0 ? current.split(",") : [];
            if (current.length === 0)
                current = defaults;
            if (current.indexOf("applications:richiedj.desktop") < 0) {
                current.unshift("applications:richiedj.desktop");
                w.writeConfig("launchers", current);
            }
        }
    }
}
