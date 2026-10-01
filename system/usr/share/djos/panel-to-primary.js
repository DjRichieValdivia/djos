// DJOS: lleva la barra de tareas a la pantalla principal (lo corre "desktop-setup" una sola vez por usuario). Hasta
// DJOS 2.2.0 la barra de DJOS se armaba en la pantalla del cursor, que con dos monitores podía ser la secundaria.
// Solo si hay una sola barra: con varias, el usuario ya las acomodó a su gusto.
var all = panels();
if (all.length === 1 && all[0].screen !== 0) {
    try { all[0].screen = 0; } catch (e) { }
}
