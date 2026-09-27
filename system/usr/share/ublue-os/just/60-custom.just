# DJOS: programas de audio y DJ desde Flathub (nada viene preinstalado: se elige y se instala con un clic)
djos-apps:
    #!/usr/bin/bash
    set -uo pipefail
    sel=$(kdialog --title "DJOS" --separate-output --checklist "Choose what to install (from Flathub):" \
        com.bitwig.BitwigStudio "Bitwig Studio (DAW)" off \
        fm.reaper.Reaper "REAPER (DAW)" off \
        org.ardour.Ardour "Ardour (open-source DAW)" off \
        org.audacityteam.Audacity "Audacity (audio editor)" on \
        org.kde.kid3 "Kid3 (track tags)" on \
        cc.spek.Spek "Spek (spectrum: check if an MP3 is real quality)" on \
        org.musicbrainz.Picard "MusicBrainz Picard (organize your music)" off \
        org.mixxx.Mixxx "Mixxx (DJ software)" off \
        com.obsproject.Studio "OBS Studio (stream or record sets, NVENC)" off \
        net.sourceforge.VMPK "VMPK (on-screen MIDI keyboard)" off \
        net.sourceforge.kmidimon "KMidimon (MIDI monitor)" off) || exit 0
    [ -n "$sel" ] || exit 0
    flatpak install --system -y --noninteractive flathub $sel
    echo
    read -r -p "Done. Press Enter to close." _
