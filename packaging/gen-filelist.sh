#!/usr/bin/bash
# Listas que el RPM saca del árbol system/ (así cualquier archivo nuevo en system/ se empaqueta solo):
#   gen-filelist.sh files <buildroot>        → líneas de %files (/etc como %config(noreplace), %dir solo de lo nuestro)
#   gen-filelist.sh units system|user <raíz> → servicios propios (djos-*) para los macros de systemd, en una línea
#   gen-filelist.sh check <system/>          → frena si quedó algo del sistema viejo (bootc/ostree/Universal Blue)
#                                              o algo que un RPM no debe traer
# <raíz> es system/ o el buildroot. Lo usan packaging/build-rpm.sh y el %install del spec.
set -u

# carpetas que son nuestras (el paquete las crea y las borra); nunca carpetas compartidas del sistema
# (/usr/share/icons, /etc/xdg, /usr/lib/systemd/system…). /etc/djos NO: es estado que crean los scripts.
own_dir() {
    case "$1" in
        usr/libexec/djos|usr/libexec/djos/*) return 0 ;;
        usr/share/djos|usr/share/djos/*) return 0 ;;
        usr/lib/tuned/profiles/djos*) return 0 ;;
        usr/share/plasma/look-and-feel/org.djos.*) return 0 ;;
        usr/share/plasma/plasmoids/org.djos.*) return 0 ;;
        # las páginas de DJOS en Configuración del sistema: ningún paquete de Fedora 44/45 trae estas carpetas (sin
        # ser nuestras quedaban vacías después de desinstalar)
        usr/share/plasma/systemsettings|usr/share/plasma/systemsettings/externalmodules) return 0 ;;
        usr/share/plymouth/themes/djos|usr/share/plymouth/themes/djos/*) return 0 ;;
        usr/share/wallpapers/DJOS*) return 0 ;;
        usr/share/icons/Papirus-Dark-DJOS|usr/share/icons/Papirus-Dark-DJOS/*) return 0 ;;
        usr/share/doc/djos-optimizer) return 0 ;;
        # carpetas de retoques (drop-ins) de un servicio: ningún paquete de Fedora las trae, las dejamos limpias
        usr/lib/systemd/system/*.d|usr/lib/systemd/user/*.d)
            case "${1##*/}" in
                *.service.d|*.timer.d|*.socket.d|*.path.d|*.slice.d|*.scope.d|*.mount.d|*.target.d) return 0 ;;
            esac ;;
    esac
    return 1
}

# ruta para %files: con comillas si tiene espacios, % escapado; comodines de rpm no se aceptan
files_path() {
    local p=$1
    # shellcheck disable=SC1003 # '\' es la barra invertida literal
    case "$p" in
        *'*'*|*'?'*|*'['*|*']'*|*'{'*|*'}'*|*'"'*|*'\'*)
            echo "gen-filelist: nombre que rpm no puede empaquetar tal cual: $p" >&2; return 1 ;;
    esac
    p=${p//%/%%}
    case "$p" in
        *[[:space:]]*) printf '"%s"' "$p" ;;
        *) printf '%s' "$p" ;;
    esac
}

cmd_files() {
    local root=${1:?falta el buildroot} rel line fail=0
    [ -d "$root" ] || { echo "gen-filelist: no existe $root" >&2; return 1; }
    while IFS= read -r -d '' rel; do
        rel=${rel#./}
        if [ -d "$root/$rel" ] && [ ! -L "$root/$rel" ]; then
            own_dir "$rel" || {
                # una carpeta con "djos" en el nombre que no está en la lista: avisar (quizás falta agregarla arriba)
                case "${rel##*/}" in
                    *[dD][jJ][oO][sS]*) echo "gen-filelist: aviso: la carpeta /$rel no es del paquete (agregarla en own_dir si es nuestra)" >&2 ;;
                esac
                continue
            }
            line="%dir $(files_path "/$rel")" || { fail=1; continue; }
        else
            line=$(files_path "/$rel") || { fail=1; continue; }
            case "$rel" in
                etc/*) line="%config(noreplace) $line" ;;
            esac
        fi
        printf '%s\n' "$line"
    done < <(cd "$root" && find . -mindepth 1 -print0 | LC_ALL=C sort -z)
    return $fail
}

cmd_units() {
    local kind=${1:?system o user} root=${2:?falta la raíz} dir f out=""
    case "$kind" in system|user) ;; *) echo "gen-filelist: units system|user" >&2; return 1 ;; esac
    dir="$root/usr/lib/systemd/$kind"
    [ -d "$dir" ] || { echo; return 0; }
    while IFS= read -r f; do
        out="$out${out:+ }$f"
    done < <(cd "$dir" && find . -maxdepth 1 -type f -name 'djos-*' \
                 \( -name '*.service' -o -name '*.timer' -o -name '*.path' -o -name '*.socket' -o -name '*.target' \) \
                 -printf '%f\n' | LC_ALL=C sort)
    printf '%s\n' "$out"
}

cmd_check() {
    local root=${1:?falta la raíz} rel fail=0 why
    [ -d "$root" ] || { echo "gen-filelist: no existe $root" >&2; return 1; }
    while IFS= read -r -d '' rel; do
        rel=${rel#./}
        why=""
        case "$rel" in
            usr/lib/bootc/*|usr/lib/bootupd/*|usr/lib/ostree/*|etc/ostree/*|*rpm-ostree*|*ostree*)
                why="bootc/ostree: no existe en Fedora KDE común" ;;
            usr/share/ublue-os/*|*/just/*|*flatpak-system-update*|*flatpak-user-update*)
                why="Universal Blue (ujust y sus servicios) no existe en Fedora KDE común" ;;
            var/*|opt/*|usr/local/*|home/*|root/*|run/*|tmp/*)
                why="un RPM no trae estado ni cosas de /var, /opt o /usr/local (los crean los scripts)" ;;
            etc/djos|etc/djos/*)
                why="/etc/djos es estado de la máquina: lo crean los scripts" ;;
            usr/share/djos/source.conf|usr/share/djos/VERSION)
                why="lo genera el armado del paquete: no va en system/" ;;
            etc/tuned/ppd.conf)
                why="es de tuned-ppd: se edita con copia de seguridad desde optimizer-setup, no se empaqueta" ;;
        esac
        [ -n "$why" ] && { echo "gen-filelist: /$rel: $why" >&2; fail=1; }
    done < <(cd "$root" && find . -mindepth 1 \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
    return $fail
}

case "${1:-}" in
    files) shift; cmd_files "$@" ;;
    units) shift; cmd_units "$@" ;;
    check) shift; cmd_check "$@" ;;
    *) echo "uso: $0 files <buildroot> | units system|user <raíz> | check <raíz>" >&2; exit 2 ;;
esac
