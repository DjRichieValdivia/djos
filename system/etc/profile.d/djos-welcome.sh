# DJOS: bienvenida de la terminal (una sola vez por usuario)
if [ -n "${PS1:-}" ] && [ -n "${HOME:-}" ] && [ -z "${CONTAINER_ID:-}" ] && [ ! -f /run/.containerenv ] \
   && [ ! -f "$HOME/.config/djos/welcome-shown" ]; then
    echo ""
    echo "Welcome! This is Fedora Linux, tuned for DJs by DJOS."
    echo ""
    echo "  Install software:      Discover (app store), or  sudo dnf install <package>   (dnf works normally)"
    echo "  Apps from Flathub:     flatpak install flathub <app>"
    echo "  Audio, performance, apps and updates:  DJOS Center (in the app menu)"
    echo "  Check this PC for DJing:               DJOS Self-Test (in the app menu)"
    echo "  Full system latency test:              sudo djos-latency-test"
    echo ""
    mkdir -p "$HOME/.config/djos" 2>/dev/null && touch "$HOME/.config/djos/welcome-shown" 2>/dev/null
fi
