# DJOS: bienvenida de la terminal (una sola vez por usuario), en lugar de la de Toolbx
if [ -n "${PS1:-}" ] && [ -n "${HOME:-}" ] && [ -z "${CONTAINER_ID:-}" ] && [ ! -f /run/.containerenv ] \
   && [ ! -f "$HOME/.config/djos/welcome-shown" ]; then
    . /etc/os-release 2>/dev/null
    echo ""
    echo "Welcome to ${PRETTY_NAME:-DJOS}."
    echo ""
    echo "  Install apps:          Discover (app store), or  flatpak install flathub <app>"
    echo "  Arch / AUR packages:   paru -S <package>   (apps show up in the menu)"
    echo "  Settings for audio, updates, apps and plugins:  DJOS Center (in the menu)"
    echo "  Audio latency test:    sudo djos-latency-test"
    echo ""
    echo "  The system itself is read-only by design (it can't break); your files and apps are yours."
    echo ""
    mkdir -p "$HOME/.config/djos" "$HOME/.config/toolbox" 2>/dev/null
    touch "$HOME/.config/djos/welcome-shown" "$HOME/.config/toolbox/host-welcome-shown" 2>/dev/null
fi
