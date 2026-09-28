#!/usr/bin/bash
# DJOS Optimizer: primera instalación en un Fedora KDE Plasma Desktop recién instalado (44 o más nuevo, no atómico).
# Se corre una sola vez, como el usuario normal, en Konsole (pide la contraseña con sudo). Se puede volver a correr
# sin problema: cada paso mira si ya está hecho.
#
# Los 3 comandos que escribe el usuario en Konsole (<owner> = la cuenta u organización de GitHub dueña del repo
# privado DJOS; se puede omitir al final si es la propia cuenta):
#   sudo dnf install -y gh
#   gh auth login --web --git-protocol https --skip-ssh-key -s read:packages
#   gh api -H "Accept: application/vnd.github.raw" repos/<owner>/djos/contents/bootstrap/install.sh > djos-install.sh && bash djos-install.sh <owner>
#
# Pasos: revisar el sistema → acceso a GitHub (/etc/djos/registry-auth.json) → RPM Fusion free y nonfree →
# actualizar todo Fedora → instalar djos-optimizer → driver de NVIDIA (si hay una placa NVIDIA) → Richie DJ →
# preguntar si se sacan programas que una PC de DJ no usa → reiniciar (y la pantalla azul de la clave, "MOK").
#
# Solo para pruebas en una VM (nunca hacen falta en una PC de verdad):
#   DJOS_LOCAL_RPM=/ruta/djos-optimizer.noarch.rpm    instala ese RPM en vez de bajarlo de GitHub
#   DJOS_OPTIMIZER_SOURCE=oci-archive:/x.tar           baja el RPM de esa imagen (transporte de skopeo)
#   DJOS_APP_SOURCE=oci-archive:/richiedj.tar          Richie DJ desde esa imagen
#   DJOS_SKIP_GITHUB=1                                  no usa GitHub para nada
set -u

AUTH=/etc/djos/registry-auth.json
LIBEXEC=/usr/libexec/djos
MOK_PASSWORD=djosdjos        # la misma que muestra nvidia-setup
TOTAL=8
LOG=$HOME/djos-install.log
owner=${1:-${DJOS_OWNER:-}}
skip_github=false; [ "${DJOS_SKIP_GITHUB:-0}" = 1 ] && skip_github=true

# todo lo que se ve queda también en ~/djos-install.log (para soporte); gh y sudo hablan directo con la terminal
exec > >(tee -a "$LOG") 2>&1

bold=$'\033[1m'; orange=$'\033[1;33m'; red=$'\033[1;31m'; green=$'\033[1;32m'; off=$'\033[0m'
n=0
step() { n=$((n + 1)); printf '\n%s==> [%d/%d] %s%s\n' "$orange" "$n" "$TOTAL" "$*" "$off"; }
ok() { printf '%s    ✓ %s%s\n' "$green" "$*" "$off"; }
info() { printf '    %s\n' "$*"; }
die() {
    printf '\n%sERROR: %s%s\n' "$red" "$*" "$off"
    echo "Nothing is broken. Fix that and run this script again: it continues where it stopped."
    echo "(A copy of everything shown here is in $LOG)"
    exit 1
}
ask() {   # ask <pregunta>: 0 si contesta que sí (por defecto no)
    local a
    read -r -p "    $1 [y/N] " a < /dev/tty || return 1
    [[ $a == [yY]* ]]
}
has_scope() {
    gh api -i user 2> /dev/null | tr -d '\r' | sed -n 's/^[Xx]-[Oo][Aa]uth-[Ss]copes: *//p' \
        | tr ',' '\n' | sed 's/^ *//' | grep -qx 'read:packages'
}

printf '%sDJOS Optimizer: first install%s  (%s)\n' "$bold" "$off" "$(date '+%Y-%m-%d %H:%M')"
echo "This turns this Fedora KDE into a DJ PC. It takes 10-40 minutes depending on the internet speed."

# --- 1. el sistema -------------------------------------------------------------------------------------------------
step "Checking this PC"
[ "$(id -u)" != 0 ] || die "Run it as your normal user, not as root (it asks for your password when needed)."
[ -r /etc/os-release ] || die "This is not Fedora."
# shellcheck source=/dev/null
. /etc/os-release
[ "${ID:-}" = fedora ] || die "This is ${PRETTY_NAME:-not Fedora}. DJOS needs Fedora KDE Plasma Desktop 44 or newer."
case "${VERSION_ID:-}" in ''|*[!0-9]*) die "Unknown Fedora version (${VERSION_ID:-})." ;; esac
[ "$VERSION_ID" -ge 44 ] || die "This is Fedora $VERSION_ID. DJOS needs Fedora 44 or newer: upgrade first."
[ ! -e /run/ostree-booted ] || die "This is an atomic Fedora (Kinoite, Silverblue, bootc). DJOS needs the normal Fedora KDE Plasma Desktop."
rpm -q plasma-workspace > /dev/null 2>&1 || die "KDE Plasma is not installed. DJOS needs Fedora KDE Plasma Desktop."
[ "${VARIANT_ID:-}" = kde ] || info "Note: this is not the KDE edition (${VARIANT_ID:-none}), but Plasma is installed: continuing."
ok "$PRETTY_NAME"
avail=$(df --output=avail -BG / 2> /dev/null | tail -n 1 | tr -dc 0-9)
[ "${avail:-0}" -ge 15 ] || die "Only ${avail:-0} GB free on the system disk; DJOS and Richie DJ need about 15 GB."
curl -fsS -o /dev/null --max-time 20 --retry 2 https://fedoraproject.org/static/hotspot.txt \
    || die "No internet connection (a cable is best for this)."
ok "Internet OK, ${avail} GB free"
echo "    Your password is needed for the system changes (nothing shows while you type it)."
# shellcheck disable=SC2024  # la terminal del usuario, a propósito
sudo -v < /dev/tty || die "sudo didn't work: your user must be an administrator (it is on a normal Fedora install)."
# sudo sigue abierto mientras dura el script (algunos pasos tardan mucho)
( while kill -0 $$ 2> /dev/null; do sudo -n true 2> /dev/null; sleep 50; done ) &
ok "Administrator rights"

# --- 2. GitHub -----------------------------------------------------------------------------------------------------
step "Connecting to GitHub (Richie DJ and the DJOS updates are private)"
command -v skopeo > /dev/null && command -v jq > /dev/null || sudo dnf5 install -y skopeo jq || die "Could not install skopeo and jq."
if $skip_github; then
    info "DJOS_SKIP_GITHUB=1: skipped."
else
    command -v gh > /dev/null || sudo dnf5 install -y gh || die "Could not install gh (the GitHub tool)."
    if ! gh auth status --hostname github.com > /dev/null 2>&1; then
        echo "    Sign in to GitHub: press Enter, your browser opens; type the code shown here and click Authorize."
        gh auth login --hostname github.com --web --git-protocol https --skip-ssh-key -s read:packages \
            < /dev/tty > /dev/tty 2>&1 || die "GitHub sign-in did not finish."
    fi
    if ! has_scope; then
        echo "    GitHub needs one more permission (read packages): press Enter and authorize it in the browser."
        gh auth refresh --hostname github.com -s read:packages < /dev/tty > /dev/tty 2>&1 \
            || die "GitHub did not grant the read:packages permission."
    fi
    has_scope || die "The GitHub session lacks the read:packages permission."
    login=$(gh api user --jq .login 2> /dev/null) || die "Could not read your GitHub account."
    ok "Signed in to GitHub as $login"
    sudo install -d -m 0755 /etc/djos
    # el token va por un caño: nunca se muestra ni queda en la línea de comandos
    if ! gh auth token --hostname github.com 2> /dev/null \
        | sudo skopeo login --authfile "$AUTH" -u "$login" --password-stdin ghcr.io > /dev/null 2>&1; then
        die "GitHub's package registry did not accept the access."
    fi
    sudo chmod 0600 "$AUTH"
    ok "This PC can download the private packages ($AUTH)"
    # ¿de quién es DJOS? el argumento, si no la propia cuenta o una de sus organizaciones
    if [ -z "${DJOS_LOCAL_RPM:-}" ] && [ -z "${DJOS_OPTIMIZER_SOURCE:-}" ]; then
        if [ -z "$owner" ]; then
            # shellcheck disable=SC2046  # una organización por palabra
            for c in "$login" $(gh api user/orgs --jq '.[].login' 2> /dev/null); do
                if sudo skopeo inspect --authfile "$AUTH" --retry-times 2 --format '{{.Digest}}' \
                    "docker://ghcr.io/${c,,}/djos-optimizer:latest" > /dev/null 2>&1; then
                    owner=$c; break
                fi
            done
            [ -n "$owner" ] || die "Could not find the DJOS package on GitHub. Run it again with the owner: bash $0 <owner>"
        fi
        owner=${owner,,}
        ok "DJOS packages from ghcr.io/$owner"
    fi
fi

# --- 3. RPM Fusion -------------------------------------------------------------------------------------------------
step "Enabling RPM Fusion (NVIDIA driver and codecs)"
if rpm -q rpmfusion-free-release rpmfusion-nonfree-release > /dev/null 2>&1; then
    ok "Already enabled"
else
    fv=$(rpm -E %fedora)
    sudo dnf5 install -y \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$fv.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$fv.noarch.rpm" \
        || die "Could not enable RPM Fusion."
    ok "RPM Fusion free and nonfree enabled"
fi

# --- 4. Fedora al día ----------------------------------------------------------------------------------------------
step "Updating Fedora (can take a while the first time)"
sudo dnf5 upgrade --refresh -y || die "The Fedora update failed."
ok "Fedora is up to date"

# --- 5. djos-optimizer ---------------------------------------------------------------------------------------------
step "Installing DJOS Optimizer"
rpmfile=${DJOS_LOCAL_RPM:-}
work=""
if [ -z "$rpmfile" ]; then
    src=${DJOS_OPTIMIZER_SOURCE:-}
    a=()
    if [ -z "$src" ]; then
        $skip_github && die "DJOS_SKIP_GITHUB=1 needs DJOS_LOCAL_RPM or DJOS_OPTIMIZER_SOURCE."
        src="docker://ghcr.io/$owner/djos-optimizer:latest"
        a=(--authfile "$AUTH")
    fi
    work=$(sudo mktemp -d /var/tmp/djos-install.XXXXXX) || die "Could not create a temporary folder."
    sudo skopeo copy -q "${a[@]}" --retry-times 3 "$src" "dir:$work/img" > /dev/null \
        || die "Could not download DJOS Optimizer from $src."
    for l in $(sudo jq -r '.layers[].digest' "$work/img/manifest.json"); do
        sudo tar -xf "$work/img/${l#*:}" -C "$work" 2> /dev/null
    done
    rpmfile=$(sudo find "$work/rpm" -maxdepth 1 -name '*.rpm' 2> /dev/null | head -n 1)
    [ -n "$rpmfile" ] || die "The DJOS Optimizer download has no package inside."
fi
new=$(sudo rpm -qp --qf '%{VERSION}' "$rpmfile" 2> /dev/null)
cur=$(rpm -q --qf '%{VERSION}' djos-optimizer 2> /dev/null) || cur=""
if [ -n "$cur" ] && [ "$cur" = "$new" ]; then
    ok "DJOS Optimizer $cur is already installed"
else
    sudo dnf5 install -y "$rpmfile" || die "Could not install DJOS Optimizer."
    ok "DJOS Optimizer $(rpm -q --qf '%{VERSION}' djos-optimizer) installed"
fi
[ -n "$work" ] && sudo rm -rf "$work"
# el que busca actualizaciones (cada 6 horas) y el aviso de cada usuario, por si el paquete no los dejó prendidos
# (sin --now: la primera búsqueda arranca después de reiniciar, no en medio de esta instalación)
systemctl -q is-enabled djos-update.timer 2> /dev/null || sudo systemctl enable djos-update.timer 2> /dev/null
[ "$(systemctl --global is-enabled djos-update-notify.timer 2> /dev/null)" = enabled ] \
    || sudo systemctl --global enable djos-update-notify.timer 2> /dev/null

# --- 6. NVIDIA -----------------------------------------------------------------------------------------------------
step "Graphics driver"
mok=false
if lspci -d 10de: 2> /dev/null | grep -qiE 'vga|3d controller|display'; then
    info "NVIDIA graphics card found: installing its driver (the build takes a few minutes)."
    [ -x "$LIBEXEC/nvidia-setup" ] || die "nvidia-setup is missing (DJOS Optimizer did not install well)."
    # shellcheck disable=SC2024  # la terminal del usuario, a propósito
    sudo "$LIBEXEC/nvidia-setup" < /dev/tty || die "The NVIDIA driver setup failed."
    [ "$("$LIBEXEC/nvidia-setup" --status 2> /dev/null | jq -r '.mok_pending' 2> /dev/null)" = true ] && mok=true
    ok "NVIDIA driver ready"
else
    ok "No NVIDIA card: the open-source driver is used (nothing to install)"
fi

# --- 7. Richie DJ --------------------------------------------------------------------------------------------------
step "Richie DJ"
if $skip_github && [ -z "${DJOS_APP_SOURCE:-}" ]; then
    info "DJOS_SKIP_GITHUB=1: skipped."
else
    info "Downloading Richie DJ (a few GB the first time; later updates only bring what changed)."
    sudo --preserve-env=DJOS_APP_SOURCE,DJOS_SKIP_GITHUB "$LIBEXEC/app-update" --progress
    if [ -e /usr/local/share/applications/richiedj.desktop ]; then
        ok "Richie DJ installed ($(cat /opt/richiedj/.djos-version 2> /dev/null))"
    else
        info "Richie DJ could not be installed now. DJOS tries again by itself every few hours"
        info "(DJOS Center > Updates shows why; Connect GitHub there if it asks)."
    fi
fi

# --- 8. limpieza (opcional) ----------------------------------------------------------------------------------------
step "Apps a DJ PC doesn't need (optional)"
if [ -x "$LIBEXEC/optimizer-setup" ]; then
    echo "    DJOS can remove preinstalled apps a DJ PC doesn't use (games, office, mail, remote desktop…)."
    echo "    This is what it would remove:"
    sudo "$LIBEXEC/optimizer-setup" cleanup --dry-run 2>&1 | sed 's/^/      /'
    if ask "Remove them?"; then
        sudo "$LIBEXEC/optimizer-setup" cleanup || info "The cleanup did not finish; nothing essential was removed."
        ok "Cleanup done"
    else
        ok "Nothing removed (you can do it later: sudo $LIBEXEC/optimizer-setup cleanup)"
    fi
fi

# --- listo ---------------------------------------------------------------------------------------------------------
printf '\n%sAll done.%s What is left:\n' "$green" "$off"
echo "  1. Restart the PC."
if $mok; then
    echo "  2. A blue screen appears once (\"Perform MOK management\"). With the arrow keys and Enter choose:"
    echo "        Enroll MOK → Continue → Yes → type the password  $MOK_PASSWORD  (nothing shows while typing) → Reboot"
    echo "     If you miss it, nothing breaks: DJOS reminds you and it appears again on the next restart."
    echo "  3. Open the app menu and run \"DJOS Self-Test\" to check that everything is ready for a set."
else
    echo "  2. Open the app menu and run \"DJOS Self-Test\" to check that everything is ready for a set."
fi
echo
if ask "Restart now?"; then
    sudo systemctl reboot
fi
