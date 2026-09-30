#!/usr/bin/bash
# DJOS Optimizer: primera instalación en un Fedora KDE Plasma Desktop recién instalado (44 o más nuevo, no atómico).
# Se corre una sola vez, como el usuario normal, en Konsole (pide la contraseña con sudo). Se puede volver a correr
# sin problema: cada paso mira si ya está hecho.
#
# El comando que escribe el usuario en Konsole (<owner> = la cuenta u organización de GitHub dueña del repo DJOS; no
# hace falta cuenta de GitHub: el repo y las imágenes de ghcr.io son públicos):
#   curl -fsSL https://raw.githubusercontent.com/<owner>/DJOS/main/bootstrap/install.sh -o djos-install.sh && bash djos-install.sh <owner>
#
# Pasos: revisar el sistema → las descargas de DJOS (ghcr.io/<owner>, sin cuenta; solo si el registro pide permiso,
# el inicio de sesión de GitHub de antes: /etc/djos/registry-auth.json) → RPM Fusion free y nonfree → actualizar todo
# Fedora → instalar djos-optimizer → driver de NVIDIA (si hay una placa NVIDIA) → Richie DJ → preguntar si se sacan
# programas que una PC de DJ no usa → reiniciar (y la pantalla azul de la clave, "MOK").
#
# Solo para pruebas en una VM (nunca hacen falta en una PC de verdad):
#   DJOS_LOCAL_RPM=/ruta/djos-optimizer.noarch.rpm    instala ese RPM en vez de bajarlo de GitHub
#   DJOS_OPTIMIZER_SOURCE=oci-archive:/x.tar           baja el RPM de esa imagen (transporte de skopeo)
#   DJOS_APP_SOURCE=oci-archive:/richiedj.tar          Richie DJ desde esa imagen
#   DJOS_SKIP_GITHUB=1                                  no usa GitHub para nada (ni ghcr.io)
#   DJOS_TEST_FORCE_NVIDIA=1                            hace de cuenta que hay una placa NVIDIA (nvidia-setup)
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
has_scope() {   # read:packages (write:packages también sirve: incluye leer)
    gh api -i user 2> /dev/null | tr -d '\r' | sed -n 's/^[Xx]-[Oo][Aa]uth-[Ss]copes: *//p' \
        | tr ',' '\n' | sed 's/^ *//' | grep -qxE '(read|write):packages'
}
# detached <nombre> <comando…>: corre el comando como root en un servicio aparte (systemd-run), no colgado de esta
# ventana: si Konsole se cierra o la sesión de Plasma se cae en medio (la actualización cambia al propio Plasma), dnf
# termina igual y la transacción no queda a medias. Lo que escribe se ve acá y queda en /var/log/<nombre>.log; el
# código de salida lo deja en /run/<nombre>.rc y su pid en /run/<nombre>.pid. No se usa "systemd-run --wait" ni se le
# pregunta a systemd si sigue: cuando la transacción actualiza systemd (daemon-reexec) o el bus, systemd no contesta
# por un rato y parecería que el paso se cortó (o se queda esperando para siempre). Se mira el proceso directo en /proc
detached() {
    local name=$1 log=/var/log/$1.log rcf=/run/$1.rc pidf=/run/$1.pid tailpid pid gone=0 rc
    shift
    running() {   # ¿sigue trabajando? (su proceso en /proc; si el pid no se puede leer, lo que diga systemd)
        [ ! -e "$rcf" ] || return 1
        case "$pid" in ''|*[!0-9]*) systemctl -q is-active "$name.service" 2> /dev/null ;; *) [ -d "/proc/$pid" ] ;; esac
    }
    pid=$(cat "$pidf" 2> /dev/null)
    if running; then
        info "A previous run of this step is still working: waiting for it to finish first…"
        while running; do sleep 5; done
    fi
    sudo rm -f "$log" "$rcf" "$pidf"
    # (--expand-environment=no: si no, systemd reemplaza los $ del comando antes de correrlo y "$$" llega como "$")
    # shellcheck disable=SC2016 # los $ son del sh de adentro
    sudo systemd-run --quiet --collect --expand-environment=no --unit="$name" \
        -p StandardOutput="append:$log" -p StandardError="append:$log" \
        -- sh -c 'echo $$ > "$1"; shift; "$@"; echo $? > "$0"' "$rcf" "$pidf" "$@" || return 1
    # en pantalla, sin lo que no significa nada para el usuario (en el log queda todo): lo que cuentan los scriptlets
    # de los paquetes (">>> …") y los avisos de systemd de que no pudo recargar las sesiones en medio de la
    # transacción (pasa igual al reiniciar)
    tail -n +1 -F "$log" 2> /dev/null > >(grep --line-buffered -v -e '^>>> ' -e 'Failed to start transient service unit:' \
        -e 'Transport endpoint is not connected') &
    tailpid=$!
    for _ in $(seq 1 30); do pid=$(cat "$pidf" 2> /dev/null); [ -n "$pid" ] && break; sleep 1; done
    # hasta que deje el código; si ya no trabaja y no lo dejó (lo cortaron), a los 30 s se da por fallado
    while [ ! -e "$rcf" ]; do
        if running; then gone=0; else gone=$((gone + 1)); fi
        [ "$gone" -ge 15 ] && break
        sleep 2
    done
    sleep 2
    kill "$tailpid" 2> /dev/null
    wait "$tailpid" 2> /dev/null
    rc=$(cat "$rcf" 2> /dev/null)
    [ "${rc:-1}" = 0 ]
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

# --- 2. las descargas de DJOS --------------------------------------------------------------------------------------
# El optimizador y Richie DJ son imágenes públicas de ghcr.io: se bajan sin cuenta. Solo si el registro pide permiso
# (imágenes privadas, como antes) se inicia sesión en GitHub con gh y se guarda el acceso de la PC (/etc/djos)
step "Checking the DJOS downloads"
command -v skopeo > /dev/null && command -v jq > /dev/null || sudo dnf5 install -y skopeo jq || die "Could not install skopeo and jq."
use_auth=false
denied() { case "$1" in *unauthorized*|*denied*|*"authentication required"*|*401*|*403*) return 0 ;; esac; return 1; }
probe() {   # probe <owner> [--authfile …]: ¿está la imagen del optimizador de ese dueño? (sin cuenta, o con la dada)
    local o=${1,,}
    shift
    sudo skopeo inspect "$@" --retry-times 2 --format '{{.Digest}}' "docker://ghcr.io/$o/djos-optimizer:latest" 2>&1
}
github_login() {   # el inicio de sesión de GitHub (solo si las descargas piden permiso); deja login y el acceso en $AUTH
    info "The DJOS downloads ask for a GitHub account: signing in to GitHub (only once)."
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
}
if $skip_github; then
    info "DJOS_SKIP_GITHUB=1: skipped."
elif [ -n "${DJOS_LOCAL_RPM:-}" ] || [ -n "${DJOS_OPTIMIZER_SOURCE:-}" ]; then
    info "DJOS Optimizer comes from ${DJOS_LOCAL_RPM:-$DJOS_OPTIMIZER_SOURCE} (test mode)."
else
    if [ -z "$owner" ] && command -v gh > /dev/null && gh auth status --hostname github.com > /dev/null 2>&1; then
        # sin dueño en el comando, pero con gh ya conectado (como antes): la propia cuenta o una de sus organizaciones
        # shellcheck disable=SC2046  # una organización por palabra
        for c in $(gh api user --jq .login 2> /dev/null) $(gh api user/orgs --jq '.[].login' 2> /dev/null); do
            if probe "$c" > /dev/null || { [ -s "$AUTH" ] && probe "$c" --authfile "$AUTH" > /dev/null; }; then
                owner=$c; break
            fi
        done
    fi
    [ -n "$owner" ] || die "Say who publishes DJOS: bash $0 <owner> (the name after github.com/ in the DJOS page address)."
    [[ $owner =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]] || die "'$owner' is not a GitHub account name."
    owner=${owner,,}
    if out=$(probe "$owner"); then
        ok "DJOS downloads from ghcr.io/$owner (public: no GitHub account needed)"
    elif ! denied "$out"; then
        die "Could not reach ghcr.io (the DJOS downloads): $(tail -n 1 <<< "$out")"
    elif [ -s "$AUTH" ] && probe "$owner" --authfile "$AUTH" > /dev/null; then
        use_auth=true
        ok "DJOS downloads from ghcr.io/$owner (with this PC's saved GitHub access)"
    else
        github_login
        if ! out=$(probe "$owner" --authfile "$AUTH"); then
            die "ghcr.io/$owner/djos-optimizer was not found, or this GitHub account can't see it. Check the owner name ($owner): $(tail -n 1 <<< "$out")"
        fi
        use_auth=true
        ok "DJOS downloads from ghcr.io/$owner"
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
info "It keeps going even if this window closes (the full log: /var/log/djos-bootstrap-upgrade.log)."
detached djos-bootstrap-upgrade dnf5 upgrade --refresh -y || die "The Fedora update failed."
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
        $use_auth && a=(--authfile "$AUTH")
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
cur=$(rpm -q --qf '%{VERSION}\n' djos-optimizer 2> /dev/null | sort -V | tail -n 1) || cur=""
fresh=false
if [ -n "$cur" ] && [ "$cur" = "$new" ]; then
    if [ -s /var/lib/djos/setup-version ]; then
        ok "DJOS Optimizer $cur is already installed"
    else
        # instalado pero sin terminar de preparar la PC (una vuelta anterior se cortó en medio de la instalación)
        info "DJOS Optimizer $cur is installed but this PC's setup did not finish: finishing it now."
        sudo /usr/libexec/djos/optimizer-setup install || die "The DJOS setup did not finish."
        sudo /usr/libexec/djos/optimizer-setup posttrans
        fresh=true
        ok "DJOS Optimizer $cur set up"
    fi
else
    # (localpkg_gpgcheck=0 explícito: el RPM de DJOS todavía no va firmado y no depende de lo que diga dnf.conf)
    detached djos-bootstrap-install dnf5 install -y --setopt=localpkg_gpgcheck=0 "$rpmfile" \
        || die "Could not install DJOS Optimizer."
    fresh=true
    ok "DJOS Optimizer $(rpm -q --qf '%{VERSION}\n' djos-optimizer | sort -V | tail -n 1) installed"
fi
[ -n "$work" ] && sudo rm -rf "$work"
# el que busca actualizaciones (cada 6 horas) y el aviso de cada usuario, por si el paquete no los dejó prendidos. Solo
# al instalar: si después el usuario los apagó, otra vuelta de este script no los prende (sin --now: la primera búsqueda
# arranca después de reiniciar, no en medio de esta instalación)
if $fresh; then
    systemctl -q is-enabled djos-update.timer 2> /dev/null || sudo systemctl enable djos-update.timer 2> /dev/null
    [ "$(systemctl --global is-enabled djos-update-notify.timer 2> /dev/null)" = enabled ] \
        || sudo systemctl --global enable djos-update-notify.timer 2> /dev/null
fi

# --- 6. NVIDIA -----------------------------------------------------------------------------------------------------
step "Graphics driver"
mok=false
if [ "${DJOS_TEST_FORCE_NVIDIA:-0}" = 1 ] || lspci -d 10de: 2> /dev/null | grep -qiE 'vga|3d controller|display'; then
    info "NVIDIA graphics card found: installing its driver (the build takes a few minutes)."
    [ -x "$LIBEXEC/nvidia-setup" ] || die "nvidia-setup is missing (DJOS Optimizer did not install well)."
    # shellcheck disable=SC2024  # la terminal del usuario, a propósito
    sudo --preserve-env=DJOS_TEST_FORCE_NVIDIA "$LIBEXEC/nvidia-setup" < /dev/tty || die "The NVIDIA driver setup failed."
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
        info "(DJOS Center > Updates shows why.)"
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
    echo "  2. A blue screen says \"Press any key to perform MOK management\": press the space bar (you have one minute)."
    echo "     The menu starts on \"Continue boot\": with the arrow keys and Enter choose"
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
