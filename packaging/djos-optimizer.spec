# DJOS Optimizer: afinación para DJs encima de Fedora KDE Plasma Desktop (44, 45…). Un solo RPM noarch.
# Se arma con packaging/build-rpm.sh, que antepone la versión (packaging/VERSION), el dueño en GitHub
# (DJOS_OWNER) y las listas de servicios propios (sacadas de system/usr/lib/systemd), y agrega el %%changelog.
# El contrato (rutas, scriptlets, source.conf) está en packaging/ARCHITECTURE.md.

%{!?djos_version:%global djos_version 0.0.0}
%{!?djos_owner:%global djos_owner djos-test}
%{!?djos_system_units:%global djos_system_units %{nil}}
%{!?djos_user_units:%global djos_user_units %{nil}}
%global setup_bin %{_libexecdir}/djos/optimizer-setup
%global new_units /run/djos-optimizer/new-units

Name:           djos-optimizer
Version:        %{djos_version}
Release:        1
Summary:        DJ and music production tuning for Fedora KDE Plasma
License:        LicenseRef-DJOS-Proprietary
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

BuildRequires:  systemd-rpm-macros
BuildRequires:  python3
BuildRequires:  desktop-file-utils
BuildRequires:  systemd-udev

%{?systemd_requires}
# lo que usan los scripts de /usr/libexec/djos
Requires:       bash
Requires:       diffutils
Requires:       jq
Requires:       psmisc
Requires:       grubby
Requires:       tuned
Requires:       tuned-ppd
Requires:       pipewire
Requires:       pipewire-utils
Requires:       wireplumber
Requires:       alsa-utils
Requires:       podman
Requires:       skopeo
Requires:       flatpak
Requires:       kdialog
# notify-send (libnotify) y kscreen-doctor (libkscreen): se piden por el programa, rpmlint no quiere
# dependencias explícitas de paquetes lib*
Requires:       /usr/bin/notify-send
Requires:       /usr/bin/kscreen-doctor
Requires:       usbutils
Requires:       pciutils
Requires:       python3-pyside6
# DJOS Preview: decodifica con ffmpeg (ffmpeg-free de Fedora o el ffmpeg de RPM Fusion: los dos traen estos archivos)
Requires:       /usr/bin/ffmpeg
Requires:       /usr/bin/ffprobe
Requires:       kf6-kirigami
Requires:       kf6-kconfig
Requires:       polkit
Requires:       dnf5
Requires:       gh
# connect: 'gh auth login --clipboard' copia el código con wl-copy/wl-paste; vino con kde-connect y la limpieza se lo
# llevaría (como dependencia, dnf ya no lo saca)
Requires:       wl-clipboard
Requires:       plymouth
Requires:       plymouth-scripts
# nuestros archivos son enlaces a estos: el tema de arranque djos usa two-step y las imágenes de spinner,
# Papirus-Dark-DJOS apunta a las carpetas de Papirus-Dark (y esas a Papirus); sin ellos quedan enlaces rotos
Requires:       plymouth-plugin-two-step
Requires:       plymouth-theme-spinner
Requires:       papirus-icon-theme
Requires:       papirus-icon-theme-dark
# DJOS Glass: la decoración de ventanas (el semáforo) es un tema Aurorae; el Launchpad del dock es de
# kdeplasma-addons (sin él, el dock queda sin ese botón)
Requires:       aurorae
Recommends:     kdeplasma-addons
# optimizer-setup corre en %%post, %%preun y %%posttrans: sus herramientas tienen que estar instaladas antes
# y no irse antes que nosotros al desinstalar
Requires(pre):  coreutils
Requires(post): bash grubby tuned plymouth-scripts
Requires(preun): bash grubby tuned plymouth-scripts

# aspecto: letras
Recommends:     rsms-inter-fonts
Recommends:     jetbrains-mono-fonts
# programas para DJs y producción (cada uno se puede sacar sin llevarse DJOS)
Recommends:     ardour9
Recommends:     Carla
Recommends:     audacity
Recommends:     kid3
Recommends:     picard
# editor de etiquetas como Mp3tag (en forma de planilla)
Recommends:     puddletag
# DJOS Preview lee las etiquetas con mutagen (rápido); sin él, con ffprobe
Recommends:     python3-mutagen
Recommends:     soundconverter
Recommends:     sonic-visualiser
Recommends:     haruna
Recommends:     qpwgraph
# DJOS Center > Performance > "GPU monitor" (no viene con Fedora KDE)
Recommends:     nvtop
# plugins LV2 / VST3 / CLAP
Recommends:     lsp-plugins-lv2
Recommends:     lsp-plugins-vst3
Recommends:     lsp-plugins-clap
Recommends:     lv2-x42-plugins
Recommends:     lv2-calf-plugins
Recommends:     lv2-zam-plugins
Recommends:     zynaddsubfx-lv2
# medición de latencia y tiempo real
Recommends:     rtla
Recommends:     realtime-tests
Recommends:     stress-ng
Recommends:     jack-tools
Recommends:     zita-alsa-pcmi-utils
Recommends:     git

%description
DJOS Optimizer turns a stock Fedora KDE Plasma Desktop into a machine for DJs
and music production: real-time audio tuning (kernel arguments, tuned
profiles, sound card IRQ priorities, PipeWire and WirePlumber settings,
real-time limits for the audio group), the DJOS look, DJOS Center, the DJOS
Self-Test, helpers for DJ controllers and delivery of Richie DJ.

Fedora and RPM Fusion keep the system itself updated. Removing this package
gives back a plain Fedora: its files, kernel arguments and service changes are
undone.

%prep
%setup -q

%build
# nada que compilar

%install
# system/ se copia tal cual: programas 0755, el resto 0644, carpetas 0755; los enlaces quedan enlaces.
# Programas: /usr/libexec y /usr/bin, las carpetas donde el sistema solo corre ejecutables (grub.d,
# kernel/install.d, generadores de systemd…) y lo que git tiene como ejecutable (build-rpm.sh lo conserva)
cd system
{ set +x; } 2> /dev/null
find . -mindepth 1 \( -type f -o -type l \) -print0 | LC_ALL=C sort -z |
while IFS= read -r -d '' f; do
    f=${f#./}
    if [ -L "$f" ]; then
        install -d -m 0755 "%{buildroot}/$(dirname "$f")"
        ln -sfn "$(readlink "$f")" "%{buildroot}/$f"
        continue
    fi
    case "$f" in
        usr/libexec/*|usr/bin/*|etc/grub.d/*|usr/lib/kernel/install.d/*|usr/lib/systemd/system-generators/*|\
        usr/lib/systemd/user-generators/*|usr/lib/systemd/system-sleep/*|usr/lib/systemd/system-shutdown/*|\
        etc/NetworkManager/dispatcher.d/*|usr/lib/NetworkManager/dispatcher.d/*)
            mode=0755 ;;
        *)
            if [ -x "$f" ]; then mode=0755; else mode=0644; fi ;;
    esac
    install -D -p -m "$mode" "$f" "%{buildroot}/$f"
done
echo "installed $(find %{buildroot} \( -type f -o -type l \) | wc -l) files from system/"
set -x
cd ..

# de dónde bajan los scripts Richie DJ y el propio optimizador (/etc/djos/source.conf lo reemplaza)
case "%{djos_owner}" in
    ''|-*|*[!a-z0-9-]*) echo "invalid DJOS owner: %{djos_owner}" >&2; exit 1 ;;
esac
install -d -m 0755 %{buildroot}%{_datadir}/djos
cat > %{buildroot}%{_datadir}/djos/source.conf <<'EOF'
# Generated when the package was built. /etc/djos/source.conf (if present) overrides it.
DJOS_OWNER=%{djos_owner}
DJOS_APP_IMAGE=ghcr.io/%{djos_owner}/richiedj:latest
DJOS_OPTIMIZER_IMAGE=ghcr.io/%{djos_owner}/djos-optimizer:latest
EOF
echo '%{version}' > %{buildroot}%{_datadir}/djos/VERSION
chmod 0644 %{buildroot}%{_datadir}/djos/source.conf %{buildroot}%{_datadir}/djos/VERSION

# la lista de %%files sale del buildroot (todo lo que está en system/ se empaqueta)
bash packaging/gen-filelist.sh files %{buildroot} > djos-files.list

%check
# sintaxis de scripts, JSON, .desktop y reglas de udev; y la interfaz que piden los scriptlets
fail=0
if [ ! -f %{buildroot}%{setup_bin} ]; then
    echo "missing %{setup_bin} (required by the scriptlets, see packaging/ARCHITECTURE.md)" >&2
    fail=1
fi
for f in %{buildroot}%{_libexecdir}/djos/* %{buildroot}%{_bindir}/*; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    case "$(head -n 1 "$f")" in
        '#!'*python*)
            python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1])' "$f" ||
                { echo "syntax error: ${f#%{buildroot}}" >&2; fail=1; } ;;
        '#!'*sh*)
            bash -n "$f" || { echo "syntax error: ${f#%{buildroot}}" >&2; fail=1; } ;;
    esac
done
while IFS= read -r -d '' f; do
    python3 -m json.tool "$f" > /dev/null || { echo "invalid JSON: ${f#%{buildroot}}" >&2; fail=1; }
done < <(find %{buildroot} -type f -name '*.json' -print0)
for f in %{buildroot}%{_datadir}/applications/*.desktop; do
    [ -f "$f" ] || continue
    desktop-file-validate "$f" || fail=1
done
for f in %{buildroot}%{_udevrulesdir}/*.rules; do
    [ -f "$f" ] || continue
    udevadm verify --resolve-names=never --no-style "$f" || fail=1
done
[ "$fail" -eq 0 ]

%pre
# al actualizar: anotar los servicios que esta versión trae nuevos, para activarlos en %%post
# (%%systemd_post solo aplica los presets en la primera instalación)
if [ "$1" -ge 2 ]; then
    mkdir -p "$(dirname %{new_units})" 2> /dev/null && : > %{new_units} 2> /dev/null || :
    for u in %{djos_system_units}; do
        [ -e "%{_unitdir}/$u" ] || echo "system $u" >> %{new_units} 2> /dev/null || :
    done
    for u in %{djos_user_units}; do
        [ -e "%{_userunitdir}/$u" ] || echo "user $u" >> %{new_units} 2> /dev/null || :
    done
fi
:

%post
%if "%{djos_system_units}" != ""
%systemd_post %{djos_system_units}
%endif
%if "%{djos_user_units}" != ""
%systemd_user_post %{djos_user_units}
%endif
if [ "$1" -ge 2 ] && [ -s %{new_units} ]; then
    while read -r kind unit; do
        if [ "$kind" = system ]; then
            systemctl --no-reload preset "$unit" || :
        else
            systemctl --no-reload preset --global "$unit" || :
        fi
    done < %{new_units}
fi
rm -rf "$(dirname %{new_units})"
if [ "$1" -eq 1 ]; then
    %{setup_bin} install || echo "djos-optimizer: 'optimizer-setup install' failed" >&2
else
    %{setup_bin} upgrade || echo "djos-optimizer: 'optimizer-setup upgrade' failed" >&2
fi
:

%preun
# desinstalación de verdad (no actualización): deshacer todo antes de que se vayan los archivos
if [ "$1" -eq 0 ]; then
    %{setup_bin} remove || echo "djos-optimizer: 'optimizer-setup remove' failed" >&2
fi
%if "%{djos_system_units}" != ""
%systemd_preun %{djos_system_units}
%endif
%if "%{djos_user_units}" != ""
%systemd_user_preun %{djos_user_units}
%endif
:

%postun
%if "%{djos_system_units}" != ""
%systemd_postun %{djos_system_units}
%endif
%if "%{djos_user_units}" != ""
%systemd_user_postun %{djos_user_units}
%endif
# desinstalación: el initramfs se rearma recién ahora, sin los archivos de DJOS (tema, ntsync, opciones de audio);
# lo pide 'optimizer-setup remove' en %%preun
if [ "$1" -eq 0 ] && [ -e /run/djos-optimizer-initramfs ]; then
    rm -f /run/djos-optimizer-initramfs
    echo "djos: updating the boot screen in every installed kernel (1-2 minutes)..."
    if dracut -f --regenerate-all > /dev/null 2>&1; then
        echo "djos: boot screen updated"
    else
        echo "djos-optimizer: dracut failed; run: sudo dracut -f --regenerate-all" >&2
    fi
fi
:

%posttrans
# initramfs y pantalla de arranque, cuando ya están todos los archivos
%{setup_bin} posttrans || echo "djos-optimizer: 'optimizer-setup posttrans' failed" >&2
:

%files -f djos-files.list
%doc README.md
