// DJOS Glass: barra de arriba y dock, como en macOS (solo la interfaz). Es el diseño del tema DJOS Glass: Plasma lo usa
// al armar el escritorio de un usuario nuevo, y "desktop-setup" lo corre una vez por versión del diseño para los
// usuarios que ya existían (reemplaza las barras que hubiera).
//   - arriba: el logo de DJOS (el Launchpad: todas las apps en pantalla completa, buscar, ordenar y apagar; también
//     con la tecla Meta y desde el dock), el menú de la app activa, la bandeja y el reloj
//   - abajo: el dock de DJOS (org.djos.dock: los programas con la lupa de macOS, el Launchpad y la papelera); se
//     esconde cuando una ventana lo toca y vuelve con el mouse abajo, así no le quita lugar a nada
// Las dos van en la pantalla principal (la 0 de Plasma); si no, Plasma las pone en la del cursor.
var old = panels();
for (var i = 0; i < old.length; ++i)
    old[i].remove();

function has(type) {
    try { return knownWidgetTypes.indexOf(type) >= 0; } catch (e) { return true; }
}

// ---------------------------------------------------------------- barra de arriba
var bar = new Panel;
bar.location = "top";
bar.height = Math.round(gridUnit * 1.6);
try { bar.screen = 0; } catch (e) { }
try { bar.floating = false; } catch (e) { }
try { bar.opacity = "translucent"; } catch (e) { }

// el Launchpad de DJOS (org.djos.launchpad: se ordena, se esconden programas, se fijan en el dock); sin él, el de
// Plasma (kickerdash) o el menú de siempre (kickoff)
var launcher = has("org.djos.launchpad") ? "org.djos.launchpad"
             : has("org.kde.plasma.kickerdash") ? "org.kde.plasma.kickerdash" : "org.kde.plasma.kickoff";
var menu = bar.addWidget(launcher);
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "djos-menu");
if (launcher !== "org.djos.launchpad")
    menu.writeConfig("useCustomButtonImage", false);
menu.writeConfig("favoritesPortedToKAstats", false);
menu.writeConfig("favorites", ["applications:richiedj.desktop", "applications:org.djos.center.desktop",
                               "applications:org.mozilla.firefox.desktop", "applications:org.kde.dolphin.desktop",
                               "applications:org.kde.konsole.desktop", "applications:systemsettings.desktop",
                               "applications:org.kde.discover.desktop"]);

// el menú de la app activa (Archivo, Editar…), como la barra de menús de macOS
if (has("org.kde.plasma.appmenu"))
    bar.addWidget("org.kde.plasma.appmenu");
bar.addWidget("org.kde.plasma.panelspacer");

// bandeja sin el clima (desktop-setup lo saca con panel-tweaks.js: la bandeja arma su lista recién después)
bar.addWidget("org.kde.plasma.systemtray");
// ícono de actualizaciones de DJOS (solo si el widget está instalado: si no, Plasma mostraría un error en la barra)
if (has("org.djos.updates"))
    bar.addWidget("org.djos.updates");
var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd MMM d");
// del mismo tamaño que el menú (si no, crece con el alto de la barra), en Inter Medium como el resto de DJOS
clock.writeConfig("autoFontAndSize", false);
clock.writeConfig("fontFamily", "Inter");
clock.writeConfig("fontWeight", 500);
clock.writeConfig("fontSize", 10);

// ---------------------------------------------------------------- dock
var richiedj = applicationExists("richiedj.desktop");
var launchers = ["preferred://browser", "preferred://filemanager", "applications:org.kde.konsole.desktop",
                 "applications:org.djos.center.desktop", "applications:systemsettings.desktop",
                 "applications:org.kde.discover.desktop"];
if (richiedj)
    launchers.unshift("applications:richiedj.desktop");

var dock = new Panel;
dock.location = "bottom";
try { dock.screen = 0; } catch (e) { }
try { dock.lengthMode = "fit"; } catch (e) { }
try { dock.alignment = "center"; } catch (e) { }
if (has("org.djos.dock")) {
    // el dock dibuja su fondo y crece adentro del panel: el panel es transparente (tema djos-glass) y más alto que el
    // dock (separación 6 + dock + lupa y nombre); no reserva lugar y se esconde cuando una ventana lo toca
    var size = 38;
    dock.height = 6 + Math.round(size * 1.4) + Math.ceil(size * 0.6) + 36;
    try { dock.floating = false; } catch (e) { }
    try { dock.hiding = "dodgewindows"; } catch (e) { }
    var dj = dock.addWidget("org.djos.dock");
    dj.currentConfigGroup = ["General"];
    dj.writeConfig("launchers", launchers);
    dj.writeConfig("iconSize", size);
} else {
    // sin el dock de DJOS: el de Plasma, flotante, con el Launchpad y la papelera
    dock.height = 2 * Math.round(gridUnit * 1.75);
    try { dock.floating = true; } catch (e) { }
    try { dock.opacity = "translucent"; } catch (e) { }
    try { dock.hiding = "none"; } catch (e) { }
    var tasks = dock.addWidget("org.kde.plasma.icontasks");
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("launchers", launchers);
    tasks.writeConfig("maxStripes", 1);
    if (has("org.kde.plasma.trash"))
        dock.addWidget("org.kde.plasma.trash");
}

// fondo de pantalla DJOS Glass en todos los escritorios
var ds = desktops();
for (var j = 0; j < ds.length; ++j) {
    ds[j].wallpaperPlugin = "org.kde.image";
    ds[j].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    ds[j].writeConfig("Image", "file:///usr/share/wallpapers/DJOS-Glass/");
}
