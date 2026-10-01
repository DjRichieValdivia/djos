// DJOS: fija Richie DJ en la barra de tareas cuando la app llega después del escritorio (lo corre "desktop-setup" al
// iniciar sesión, una sola vez por usuario, recién cuando /usr/local/share/applications/richiedj.desktop existe).
// Sirve para la barra de DJOS y para cualquier otra: si la barra todavía tiene los lanzadores de fábrica de Plasma,
// se conservan y Richie DJ va primero. Si el usuario después lo saca, se respeta (no se vuelve a correr).
if (applicationExists("richiedj.desktop")) {
    var defaults = ["applications:systemsettings.desktop", "applications:org.kde.discover.desktop",
                    "preferred://filemanager", "preferred://browser"];
    var all = panels();
    for (var i = 0; i < all.length; ++i) {
        var widgets = all[i].widgets();
        for (var j = 0; j < widgets.length; ++j) {
            var w = widgets[j];
            if (w.type !== "org.kde.plasma.icontasks" && w.type !== "org.kde.plasma.taskmanager" && w.type !== "org.djos.dock")
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
