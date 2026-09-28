#!/usr/bin/bash
# Arma DJOS encima de la imagen base: saca lo que no hace falta, agrega programas de audio, la configuración de
# audio, el aspecto de DJOS y el nombre.
set -euxo pipefail

# rpm_present <paquete>…: los que están instalados (para sacar solo esos, sin fallar por los que no están)
rpm_present() { rpm -q --qf '%{name}\n' "$@" 2> /dev/null | grep -v ' is not installed$' || true; }

# --- 1. Fuera lo que no sirve en una máquina de DJ / audio
#        (al sacar ModemManager también se van NetworkManager-wwan y NetworkManager-bluetooth: módem e internet
#        compartida por Bluetooth, que acá no se usan)
remove=$(rpm_present \
    kde-connect kdeconnectd krfb \
    gamemode \
    plasma-welcome plasma-discover-notifier \
    pipewire-config-raop \
    akonadi-server akonadi-server-mysql \
    mariadb mariadb-server mariadb-backup mariadb-common mariadb-errmsg mariadb-gssapi-server mariadb-cracklib-password-check \
    ModemManager \
    sssd-kcm \
    kunifiedpush xwaylandvideobridge \
    thermald supergfxctl \
    nvidia-container-toolkit nvidia-container-toolkit-base libnvidia-container-tools libnvidia-container1 \
    open-vm-tools virtualbox-guest-additions spice-vdagent spice-webdavd qemu-guest-agent \
    hyperv-daemons hyperv-daemons-license hypervkvpd hypervvssd hypervfcopyd \
    libva-intel-media-driver intel-mediasdk intel-vpl-gpu-rt intel-gmmlib intel-vaapi-driver \
    plasma-vault orca \
    hplip hplip-common hplip-libs hplip-gui gutenprint gutenprint-cups gutenprint-libs \
    plasma-workspace-wallpapers \
    drkonqi plasma-drkonqi \
    khelpcenter kdebugsettings kjournald kcharselect kfind kwalletmanager5 kwrite)
# teclados de idiomas asiáticos (ibus / fcitx5): DJOS está en inglés y español. (El teclado en pantalla,
# plasma-keyboard, no se puede sacar sin llevarse Plasma: queda apagado desde kwinrc)
remove="$remove $(rpm -qa --qf '%{name}\n' 'ibus*' 'fcitx5*' | grep -v -e '^ibus-libs$' || true)"
dnf5 -y remove $remove

# librerías de 32 bits (solo sirven para juegos viejos): ~1 GB menos en cada actualización
i686=$(rpm -qa --qf '%{name}.%{arch}\n' | grep '\.i686$' || true)
[ -n "$i686" ] && dnf5 -y remove $i686

# --- 2. Programas: aspecto (íconos Papirus, letras Inter y JetBrains Mono), DJOS Center (PySide6) y para audio:
#        Ardour (DAW), Carla (plugins sueltos), Audacity, Kid3 y Picard (etiquetas), SoundConverter, Sonic
#        Visualiser (espectro), Haruna (reproductor) y plugins LV2/VST3/CLAP (LSP, x42, Calf, ZAM, ZynAddSubFX);
#        qpwgraph (conexiones de audio y MIDI) y medición de latencia (rtla, cyclictest/hwlatdetect, stress-ng,
#        jack_iodelay, alsa_delay); git y gh para cambiar DJOS desde el propio DJOS
dnf5 -y install --setopt=install_weak_deps=False \
    papirus-icon-theme papirus-icon-theme-dark rsms-inter-fonts jetbrains-mono-fonts python3-pyside6 \
    ardour9 Carla audacity kid3 picard soundconverter sonic-visualiser haruna \
    lsp-plugins-lv2 lsp-plugins-vst3 lsp-plugins-clap lv2-x42-plugins lv2-calf-plugins lv2-zam-plugins zynaddsubfx-lv2 \
    qpwgraph rtla realtime-tests stress-ng jack-tools zita-alsa-pcmi-utils \
    git gh
dnf5 clean all

# si algún día sacar o agregar algo arrastra lo esencial, el armado falla en vez de publicar un sistema roto
rpm -q plasma-workspace plasma-desktop kwin plasma-systemsettings kscreen plasma-nm plasma-pa powerdevil bluedevil \
    xdg-desktop-portal-kde kde-gtk-config plasma-login-manager pipewire wireplumber nvidia-driver-libs.x86_64 \
    konsole dolphin plasma-discover flatpak firefox python3-pyside6 kf6-kirigami | grep "not installed" && exit 1 || true

# --- 3. Archivos de DJOS (audio, tiempo real, arranque, primer inicio, aspecto), cada uno con su permiso exacto:
#        programas 0755, configuración 0644 (nunca se copian los permisos de origen ni se tocan carpetas existentes)
cd /ctx/system
find . -type f | while read -r f; do
    case "$f" in
        ./usr/libexec/djos/*|./usr/bin/*) mode=0755 ;;
        *) mode=0644 ;;
    esac
    install -D -m "$mode" "$f" "/${f#./}"
done
cd /

# --- 4. Servicios: menos cosas corriendo, arranque más rápido, nada de estadísticas
#        (la impresora sigue andando: CUPS arranca solo cuando se imprime)
systemctl disable \
    NetworkManager-wait-online.service \
    avahi-daemon.service avahi-daemon.socket \
    intel_lpmd.service \
    lvm2-monitor.service lvm-devices-import.path lvm-devices-import.service \
    mdmonitor.service raid-check.timer \
    dnf-makecache.timer \
    rpm-ostree-countme.timer \
    pcscd.socket \
    switcheroo-control.service \
    fedora-atomic-desktop-mandb-update.service \
    smartd.service \
    cups.service cups.path \
    nfs-client.target gssproxy.service
# nunca: actualizar y reiniciar solo (bootc-fetch-apply-updates reinicia la PC) ni el ahorro de energía de laptops
systemctl mask bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service nvidia-powerd.service
systemctl enable djos-rtirq.service djos-firstboot.service djos-users.path djos-update-check.timer djos-app-update.timer
systemctl --global enable djos-update-notify.timer djos-notices.service djos-desktop.service
# accesibilidad para teclado/mouse (teclas especiales, etc.): no hace falta en una PC de DJ
systemctl --global mask plasma-kaccess.service

# --- 5. Escritorio
# sin ubicación automática; sin avisos encima de Richie DJ en pantalla completa
rm -f /etc/xdg/autostart/geoclue-demo-agent.desktop /etc/xdg/autostart/nvidia-settings-load.desktop
printf '\n[DoNotDisturb]\nWhenFullscreen=true\n' >> /etc/xdg/plasmanotifyrc
# aspecto por defecto de todos los usuarios: colores de DJOS + letras, íconos y tema (kdeglobals lleva los colores
# completos: las apps los leen de ahí) y secciones inútiles de Configuración escondidas
{ sed '/^\[General\]/,/^$/d' /usr/share/color-schemes/DJOS.colors; cat /usr/share/djos/kdeglobals.djos; } > /etc/xdg/kdeglobals
# el tema DJOS arma la barra de tareas de los usuarios nuevos con el mismo script que los ya existentes
mkdir -p /usr/share/plasma/look-and-feel/org.djos.desktop/contents/layouts
cp /usr/share/djos/panel.js /usr/share/plasma/look-and-feel/org.djos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
# carpetas naranjas en los íconos Papirus (como hace papirus-folders)
for d in /usr/share/icons/Papirus/*/places; do
    for f in "$d"/folder-blue*.svg "$d"/user-blue*.svg; do
        [ -e "$f" ] || continue
        b=${f##*/}
        [ -e "$d/${b/blue/orange}" ] && ln -sf "${b/blue/orange}" "$d/${b/-blue/}"
    done
done
gtk-update-icon-cache -f /usr/share/icons/hicolor > /dev/null 2>&1 || true
# sin el clima en la bandeja (pide ubicación y no hace falta)
rm -f /usr/lib64/qt6/plugins/plasma/applets/org.kde.plasma.weather.so
# el fondo por defecto de todo lo que no tiene uno elegido (usuarios nuevos, pantalla de inicio de sesión): DJOS
rm -rf /usr/share/wallpapers/Next
ln -s DJOS /usr/share/wallpapers/Next
ln -sfn DJOS /usr/share/wallpapers/Default
# fuera del menú lo que en Wayland o en una PC de DJ no sirve, y las variantes técnicas de Carla (siguen instalados)
for f in nvidia-settings kbd-layout-viewer5 org.kde.kmenuedit firewall-config htop \
         carla-control carla-jack-multi carla-jack-single carla-patchbay carla-rack; do
    [ -f "/usr/share/applications/$f.desktop" ] && sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "/usr/share/applications/$f.desktop"
done
# pantalla de arranque con el logo de DJOS (Plymouth va dentro del initramfs: se rearma igual que lo arma Universal
# Blue, con los mismos argumentos, para que el driver de NVIDIA y todo lo demás siga igual)
cp -n /usr/share/plymouth/themes/spinner/*.png /usr/share/plymouth/themes/djos/
plymouth-set-default-theme djos
KVER=$(ls /usr/lib/modules | head -1)
dracut --no-hostonly --kver "$KVER" --reproducible --add ostree -f "/usr/lib/modules/$KVER/initramfs.img"
chmod 0600 "/usr/lib/modules/$KVER/initramfs.img"
lsinitrd "/usr/lib/modules/$KVER/initramfs.img" > /tmp/initramfs.txt
grep -q "plymouth/themes/djos/watermark.png" /tmp/initramfs.txt
# Configuración > Acerca de este sistema
cat > /etc/xdg/kcm-about-distrorc <<'EOF'
[General]
LogoPath=/usr/share/djos/logo.png
Name=DJOS
Website=https://fedoraproject.org/
Variant=For DJs and music producers
EOF

# --- 6. Nombre del sistema (se mantiene ID=fedora para que todo lo de Fedora siga funcionando)
. /usr/lib/os-release   # VERSION_ID: la versión de Fedora de la base (44, 45…)
sed -i \
    -e 's/^NAME=.*/NAME="DJOS"/' \
    -e "s/^PRETTY_NAME=.*/PRETTY_NAME=\"DJOS ${VERSION_ID}\"/" \
    -e 's/^DEFAULT_HOSTNAME=.*//' \
    /usr/lib/os-release
cat >> /usr/lib/os-release <<'EOF'
DEFAULT_HOSTNAME="djos"
IMAGE_ID="djos"
EOF

# --- 7. Nada de restos del armado (carpetas de ejecución y datos de dnf, incluido su contador de uso "countme")
rm -rf /run/dnf /run/selinux-policy /var/lib/dnf/repos
