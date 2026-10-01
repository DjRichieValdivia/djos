// DJOS: el menú de la barra con la grilla de apps blanca ("djos-start", en Papirus-Dark-DJOS: la de Papirus, que ocupa
// la mitad del cuadro, más grande). Lo corre "desktop-setup" una sola vez por usuario (DJOS 2.2.4). Solo cambia los
// íconos que puso DJOS (su logo, el de Plasma de la 2.2.2, la grilla chica de la 2.2.3): si el usuario eligió otro,
// se respeta
var mine = ["djos", "start-here-kde-plasma", "start-here"];
var all = panels();
for (var i = 0; i < all.length; ++i) {
    var widgets = all[i].widgets();
    for (var j = 0; j < widgets.length; ++j) {
        var w = widgets[j];
        if (w.type !== "org.kde.plasma.kickoff" && w.type !== "org.kde.plasma.kicker")
            continue;
        w.currentConfigGroup = ["General"];
        if (mine.indexOf(w.readConfig("icon", "")) >= 0)
            w.writeConfig("icon", "djos-start");
    }
}
