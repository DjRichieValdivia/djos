#!/usr/bin/bash
# Arma DJOS encima de la imagen base: saca lo que no hace falta, agrega la configuración de audio y el nombre.
set -euxo pipefail

# --- 1. Fuera lo que no sirve en una máquina de DJ / audio
#        (al sacar ModemManager también se van NetworkManager-wwan y NetworkManager-bluetooth: módem e internet
#        compartida por Bluetooth, que acá no se usan)
dnf5 -y remove \
    kde-connect kdeconnectd krfb \
    gamemode \
    plasma-welcome plasma-discover-notifier \
    pipewire-config-raop \
    akonadi-server akonadi-server-mysql \
    ModemManager \
    sssd-kcm \
    kunifiedpush xwaylandvideobridge \
    thermald supergfxctl \
    nvidia-container-toolkit nvidia-container-toolkit-base libnvidia-container-tools libnvidia-container1 \
    open-vm-tools virtualbox-guest-additions spice-vdagent spice-webdavd qemu-guest-agent \
    hyperv-daemons hyperv-daemons-license hypervkvpd hypervvssd hypervfcopyd \
    libva-intel-media-driver intel-mediasdk intel-vpl-gpu-rt intel-gmmlib intel-vaapi-driver

# librerías de 32 bits (solo sirven para juegos viejos): ~1 GB menos en cada actualización
i686=$(rpm -qa --qf '%{name}.%{arch}\n' | grep '\.i686$' || true)
[ -n "$i686" ] && dnf5 -y remove $i686
# si algún día sacar algo arrastra lo esencial, el armado falla en vez de publicar un sistema roto
rpm -q plasma-workspace kwin pipewire wireplumber nvidia-driver-libs.x86_64 konsole dolphin > /dev/null

# --- 2. Herramientas de audio profesionales: qpwgraph (conexiones de audio y MIDI) y medición de latencia
#        (rtla, cyclictest/hwlatdetect de realtime-tests, stress-ng, jack_iodelay, alsa_delay)
dnf5 -y install --setopt=install_weak_deps=False \
    qpwgraph rtla realtime-tests stress-ng jack-tools zita-alsa-pcmi-utils
dnf5 clean all

# --- 3. Archivos de DJOS (audio, tiempo real, arranque, primer inicio), cada uno con su permiso exacto:
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
    smartd.service
# nunca: actualizar y reiniciar solo (bootc-fetch-apply-updates reinicia la PC) ni el ahorro de energía de laptops
systemctl mask bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service nvidia-powerd.service
systemctl enable djos-rtirq.service djos-firstboot.service djos-users.path djos-update-check.timer djos-app-update.timer
systemctl --global enable djos-update-notify.timer

# --- 5. Escritorio: sin ubicación automática; sin avisos encima de Richie DJ en pantalla completa
rm -f /etc/xdg/autostart/geoclue-demo-agent.desktop
printf '\n[DoNotDisturb]\nWhenFullscreen=true\n' >> /etc/xdg/plasmanotifyrc

# --- 6. Nombre del sistema (se mantiene ID=fedora para que todo lo de Fedora siga funcionando)
sed -i \
    -e 's/^NAME=.*/NAME="DJOS"/' \
    -e 's/^PRETTY_NAME=.*/PRETTY_NAME="DJOS 44"/' \
    -e 's/^DEFAULT_HOSTNAME=.*//' \
    /usr/lib/os-release
cat >> /usr/lib/os-release <<'EOF'
DEFAULT_HOSTNAME="djos"
IMAGE_ID="djos"
EOF

# --- 7. Nada de restos del armado (carpetas de ejecución y datos de dnf, incluido su contador de uso "countme")
rm -rf /run/dnf /var/lib/dnf/repos
