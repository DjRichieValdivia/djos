// DJOS: agrega el ícono "DJOS Updates" a la barra (lo corre "notices" al iniciar sesión, una vez por usuario)
var all = panels();
var found = false;
for (var i = 0; i < all.length; ++i) {
    var widgets = all[i].widgets();
    for (var j = 0; j < widgets.length; ++j)
        if (widgets[j].type === "org.djos.updates")
            found = true;
}
if (!found && all.length > 0) {
    // la barra de abajo (la que tiene la bandeja del sistema); si no, la primera
    var target = all[0];
    for (var k = 0; k < all.length; ++k) {
        var ws = all[k].widgets();
        for (var m = 0; m < ws.length; ++m)
            if (ws[m].type === "org.kde.plasma.systemtray")
                target = all[k];
    }
    target.addWidget("org.djos.updates");
}
