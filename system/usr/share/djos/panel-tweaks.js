// DJOS: la bandeja de la barra de tareas sin el clima (lo corre "desktop-setup" una sola vez por usuario, DJOS 2.2.2).
// Plasma 6 lo trae; queda en "knownItems" para que no vuelva solo; se puede volver a agregar desde la configuración
// de la bandeja. El ícono del menú va aparte (menu-icon.js)
function list(v) {
    if (typeof v === "string")
        return v.length > 0 ? v.split(",") : [];
    return v || [];
}
var all = panels();
for (var i = 0; i < all.length; ++i) {
    var widgets = all[i].widgets();
    for (var j = 0; j < widgets.length; ++j) {
        var w = widgets[j];
        if (w.type === "org.kde.plasma.systemtray") {
            w.currentConfigGroup = ["General"];
            var extra = list(w.readConfig("extraItems", []));
            var known = list(w.readConfig("knownItems", []));
            if (extra.indexOf("org.kde.plasma.weather") >= 0)
                w.writeConfig("extraItems", extra.filter(function (x) { return x !== "org.kde.plasma.weather"; }));
            if (known.indexOf("org.kde.plasma.weather") < 0) {
                known.push("org.kde.plasma.weather");
                w.writeConfig("knownItems", known);
            }
        }
    }
}
