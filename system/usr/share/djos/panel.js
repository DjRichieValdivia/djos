// DJOS: barra de tareas y fondo de pantalla. La usa el tema DJOS al crear un usuario nuevo, y "desktop-setup" una sola
// vez para los usuarios que ya existían (reemplaza la barra de fábrica de Fedora).
var old = panels();
for (var i = 0; i < old.length; ++i)
    old[i].remove();

var panel = new Panel;
panel.location = "bottom";
panel.height = 2 * Math.round(gridUnit * 1.25);
try { panel.floating = true; } catch (e) { }

// menú: el logo de DJOS
var menu = panel.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "djos");
menu.writeConfig("favoritesPortedToKAstats", false);
menu.writeConfig("favorites", ["applications:richiedj.desktop", "applications:org.djos.center.desktop",
                               "applications:org.mozilla.firefox.desktop", "applications:org.kde.dolphin.desktop",
                               "applications:org.kde.konsole.desktop", "applications:systemsettings.desktop"]);

// programas fijos en la barra (Richie DJ primero)
var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", ["applications:richiedj.desktop", "preferred://browser", "preferred://filemanager",
                                "applications:org.kde.konsole.desktop", "applications:org.djos.center.desktop"]);

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.djos.updates");
var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "shortDate");

// fondo de pantalla DJOS en todos los escritorios
var ds = desktops();
for (var j = 0; j < ds.length; ++j) {
    ds[j].wallpaperPlugin = "org.kde.image";
    ds[j].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    ds[j].writeConfig("Image", "file:///usr/share/wallpapers/DJOS/");
}
