// DJOS: barra de tareas y fondo de pantalla. Es el diseño del tema DJOS: Plasma lo usa al armar el escritorio de un
// usuario nuevo, y "desktop-setup" lo corre una vez por versión para los usuarios que ya existían (reemplaza la
// barra de fábrica de Fedora). Richie DJ (app-update lo instala en /usr/local/share/applications) va primero en la
// barra si ya está; si llega después, "desktop-setup" lo agrega con pin-richiedj.js.
var old = panels();
for (var i = 0; i < old.length; ++i)
    old[i].remove();

var panel = new Panel;
// en la pantalla principal: si no, Plasma la pone en la del cursor (con dos monitores, a veces en el secundario).
// La pantalla 0 de Plasma es siempre la principal (Configuración > Pantalla)
try { panel.screen = 0; } catch (e) { }
panel.location = "bottom";
panel.height = 2 * Math.round(gridUnit * 1.25);
try { panel.floating = true; } catch (e) { }

var richiedj = applicationExists("richiedj.desktop");

// menú: el logo de DJOS y los favoritos (Richie DJ también si todavía no está: aparece cuando se instala)
var menu = panel.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "djos");
menu.writeConfig("favoritesPortedToKAstats", false);
menu.writeConfig("favorites", ["applications:richiedj.desktop", "applications:org.djos.center.desktop",
                               "applications:org.mozilla.firefox.desktop", "applications:org.kde.dolphin.desktop",
                               "applications:org.kde.konsole.desktop", "applications:systemsettings.desktop",
                               "applications:org.kde.discover.desktop"]);

// programas fijos en la barra (Richie DJ primero)
var launchers = ["preferred://browser", "preferred://filemanager", "applications:org.kde.konsole.desktop",
                 "applications:org.djos.center.desktop"];
if (richiedj)
    launchers.unshift("applications:richiedj.desktop");
var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", launchers);

panel.addWidget("org.kde.plasma.marginsseparator");
panel.addWidget("org.kde.plasma.systemtray");
// ícono de actualizaciones de DJOS (solo si el widget está instalado: si no, Plasma mostraría un error en la barra)
var updates = true;
try { updates = knownWidgetTypes.indexOf("org.djos.updates") >= 0; } catch (e) { }
if (updates)
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
