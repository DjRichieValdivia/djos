#!/usr/bin/bash
# Arma el RPM de DJOS Optimizer (noarch) adentro de un contenedor registry.fedoraproject.org/fedora:44
# (o directo, si ya corre adentro de un contenedor Fedora). Sirve igual desde WSL, una PC con Fedora o CI.
#   sh packaging/build-rpm.sh [carpeta-de-salida]        (por defecto dist/ en la raíz del repo)
# Arma desde el árbol de trabajo (archivos de git + cambios sin commitear), no desde el último commit.
# Variables:
#   DJOS_OWNER=<dueño en GitHub>  de dónde bajan Richie DJ y el optimizador (va a source.conf; por defecto djos-test)
#   DJOS_DRAFT=1                  prueba con el árbol a medio hacer: lo viejo (bootc/ublue), los choques y rpmlint
#                                 solo avisan, y no corre %check
#   DJOS_SKIP_REPO_CHECKS=1       sin red: no revisa que las dependencias existan ni choques con otros paquetes
#   DJOS_BUILD_IMAGE=<imagen>     otro contenedor de armado (por defecto registry.fedoraproject.org/fedora:44)
# Salida: djos-optimizer-<versión>-1.noarch.rpm y .src.rpm en la carpeta de salida, con el resumen de rpmlint.
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
set -u

die() { echo "build-rpm: $*" >&2; exit 1; }
say() { echo "==> $*"; }
warn() { echo "build-rpm: AVISO: $*" >&2; }
draft() { [ "${DJOS_DRAFT:-0}" = 1 ]; }

# --- adentro del contenedor: rpmbuild, rpmlint y las revisiones contra los repos de Fedora ---
inner() {
    local W=$1 src rpm fail=0 n
    src=$(echo "$W"/stage/djos-optimizer-*)
    [ -d "$src" ] || die "no encuentro las fuentes en $W/stage"

    say "Herramientas de armado (rpm-build, rpmlint)"
    dnf5 -y --setopt=install_weak_deps=False --setopt=keepcache=True install \
        rpm-build rpmlint systemd-rpm-macros python3 desktop-file-utils systemd-udev glibc-langpack-en \
        > "$W/dnf.log" 2>&1 || { tail -n 30 "$W/dnf.log"; die "no se pudieron instalar las herramientas de armado"; }

    say "rpmbuild"
    local args=(-ba --define "_topdir $W")
    draft && args+=(--nocheck)
    rpmbuild "${args[@]}" "$W/SPECS/djos-optimizer.spec" || die "rpmbuild falló"
    rpm=$(echo "$W"/RPMS/noarch/djos-optimizer-*.noarch.rpm)
    [ -f "$rpm" ] || die "rpmbuild no dejó el RPM"

    say "rpmlint"
    local rc_args=()
    [ -f "$src/packaging/djos-optimizer.rpmlintrc" ] && rc_args=(-r "$src/packaging/djos-optimizer.rpmlintrc")
    rpmlint "${rc_args[@]}" "$W/SPECS/djos-optimizer.spec" "$W"/SRPMS/*.src.rpm "$rpm" > "$W/rpmlint.txt" 2>&1
    cat "$W/rpmlint.txt"
    n=$(grep -c ': E: ' "$W/rpmlint.txt")
    if [ "$n" -gt 0 ]; then
        if draft; then warn "rpmlint: $n errores"; else echo "build-rpm: rpmlint: $n errores" >&2; fail=1; fi
    fi

    if [ "${DJOS_SKIP_REPO_CHECKS:-0}" != 1 ]; then
        say "Dependencias: cada Requires/Recommends tiene que existir en Fedora $(rpm -E %fedora)"
        local all deps paths found missing p
        all=$( { rpm -qp --requires "$rpm"; rpm -qp --recommends "$rpm"; } 2> /dev/null | awk '{print $1}' |
            grep -v -e '^rpmlib(' -e '^config(' | LC_ALL=C sort -u)
        deps=$(echo "$all" | grep -v '^/')
        paths=$(echo "$all" | grep '^/')
        # shellcheck disable=SC2086 # una palabra por nombre
        found=$(dnf5 -q repoquery --qf '%{name}\n' $deps 2> /dev/null | LC_ALL=C sort -u)
        missing=$(LC_ALL=C comm -23 <(echo "$deps") <(echo "$found"))
        # los que piden un archivo (/usr/bin/…): alguien tiene que traerlo
        for p in $paths; do
            [ -n "$(dnf5 -q repoquery --qf '%{name}\n' --whatprovides "$p" 2> /dev/null)" ] || missing="$missing $p"
        done
        if [ -n "${missing// /}" ]; then
            echo "build-rpm: no existen en los repos de Fedora: $(echo "$missing" | xargs)" >&2
            draft || fail=1
        else
            echo "ok: $(echo "$all" | wc -l) dependencias encontradas"
        fi

        say "Choques: ningún archivo del paquete puede ser de otro paquete de Fedora"
        local files owners f
        files=$(rpm -qp --qf '[%{FILEMODES:perms} %{FILENAMES}\n]' "$rpm" | awk '$1 !~ /^d/ {print $2}')
        owners=$(dnf5 -q --setopt=optional_metadata_types=filelists repoquery --qf '%{name}\n' \
                     --file "$(echo "$files" | paste -sd, -)" 2> /dev/null | LC_ALL=C sort -u)
        if [ -n "$owners" ]; then
            while IFS= read -r f; do
                n=$(dnf5 -q --setopt=optional_metadata_types=filelists repoquery --qf '%{name}\n' --file "$f" \
                        2> /dev/null | LC_ALL=C sort -u | paste -sd' ' -)
                [ -n "$n" ] && echo "build-rpm: $f ya es de: $n" >&2
            done <<< "$files"
            draft || fail=1
        else
            echo "ok: $(echo "$files" | wc -l) archivos, ninguno de otro paquete"
        fi
    fi
    return $fail
}

if [ "${1:-}" = --inner ]; then
    inner "${2:?falta la carpeta de trabajo}"
    exit $?
fi

# --- afuera: fuentes, spec, y rpmbuild en el contenedor ---
repo=$(cd "$(dirname "$0")/.." && pwd) || die "no encuentro el repo"
out=${1:-$repo/dist}
mkdir -p "$out" || die "no puedo crear la carpeta de salida $out"
out=$(cd "$out" && pwd) || die "no puedo usar la carpeta de salida $out"
cd "$repo" || die "no puedo entrar a $repo"

ver=$(tr -d '[:space:]' < packaging/VERSION 2> /dev/null)
[[ $ver =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "packaging/VERSION tiene que ser x.y.z (tiene '$ver')"
owner=$(printf '%s' "${DJOS_OWNER:-djos-test}" | tr '[:upper:]' '[:lower:]')
[[ $owner =~ ^[a-z0-9]([a-z0-9-]{0,37}[a-z0-9])?$ ]] || die "DJOS_OWNER no parece un dueño de GitHub: '$owner'"

work=$(mktemp -d "${TMPDIR:-/tmp}/djos-rpm.XXXXXX") || die "sin carpeta temporal"
trap 'rm -rf "$work"' EXIT
src="$work/stage/djos-optimizer-$ver"
mkdir -p "$src" "$work/SOURCES" "$work/SPECS"

# qué entra: lo que git conoce (commiteado o nuevo sin ignorar) y existe hoy; sin git, todo lo de esas carpetas
paths=(system packaging bootstrap README.md)
gitc() { git -c safe.directory='*' -C "$repo" "$@"; }
if gitc rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    gitc ls-files -z --cached --others --exclude-standard -- "${paths[@]}" | LC_ALL=C sort -zu > "$work/list.all"
    rev=$(gitc rev-parse --short HEAD 2> /dev/null || echo unknown)
    if [ -n "$(gitc status --porcelain -- "${paths[@]}" 2> /dev/null)" ]; then
        rev="$rev + uncommitted changes"; sde=$(date +%s)
    else
        sde=$(gitc log -1 --format=%ct 2> /dev/null || date +%s)
    fi
else
    find "${paths[@]}" \( -type f -o -type l \) -print0 2> /dev/null | LC_ALL=C sort -z > "$work/list.all"
    rev="no git"; sde=$(date +%s)
fi
while IFS= read -r -d '' p; do
    if [ -e "$p" ] || [ -L "$p" ]; then printf '%s\0' "$p"; fi
done < "$work/list.all" > "$work/list"
[ -s "$work/list" ] || die "no hay nada para empaquetar"
tar -C "$repo" --null -T "$work/list" -cf - | tar -C "$src" -xf - || die "no se pudieron copiar las fuentes"
# permisos parejos (en /mnt/c todo parece 0777); los del paquete los pone el %install del spec
find "$src" -type d -exec chmod 0755 {} + && find "$src" -type f -exec chmod 0644 {} +

# lo que git sabe y Windows pierde: los ejecutables (100755) y los enlaces (120000; con core.symlinks=false
# quedan como archivos con el destino adentro)
if [ "$rev" != "no git" ]; then
    while IFS= read -r -d '' rec; do
        p=${rec#*$'\t'}
        f="$src/$p"
        case "${rec%% *}" in
            100755)
                [ -f "$f" ] && [ ! -L "$f" ] && chmod 0755 "$f" ;;
            120000)
                if [ -f "$f" ] && [ ! -L "$f" ]; then
                    t=$(cat "$f")
                    rm -f "$f"
                    ln -s "$t" "$f" || die "no pude rehacer el enlace $p"
                fi ;;
        esac
    done < <(gitc ls-files -s -z -- system)
fi

say "DJOS Optimizer $ver ($rev), dueño '$owner'"
[ -f "$src/packaging/djos-optimizer.spec" ] || die "falta packaging/djos-optimizer.spec"
[ -d "$src/system" ] || die "falta system/"
if ! bash "$src/packaging/gen-filelist.sh" check "$src/system"; then
    draft || die "system/ trae cosas que no van en Fedora común (arriba el detalle; DJOS_DRAFT=1 para probar igual)"
    warn "system/ trae cosas que no van en Fedora común (sigo porque DJOS_DRAFT=1)"
fi
sys_units=$(bash "$src/packaging/gen-filelist.sh" units system "$src/system")
user_units=$(bash "$src/packaging/gen-filelist.sh" units user "$src/system")
echo "servicios del sistema: ${sys_units:-ninguno}"
echo "servicios de usuario:  ${user_units:-ninguno}"

# spec: lo generado arriba, el spec del repo en el medio, el %changelog al final
nil='%{nil}'
{
    echo "# --- generado por packaging/build-rpm.sh ---"
    echo "%global djos_version $ver"
    echo "%global djos_owner $owner"
    echo "%global djos_system_units ${sys_units:-$nil}"
    echo "%global djos_user_units ${user_units:-$nil}"
    echo "# --- fin de lo generado ---"
    cat "$src/packaging/djos-optimizer.spec"
    echo
    echo "%changelog"
    echo "* $(LC_ALL=C date -u -d "@$sde" '+%a %b %d %Y') DJOS <djos@localhost> - $ver-1"
    echo "- Build of ${rev//%/%%}"
} > "$work/SPECS/djos-optimizer.spec"

tar -C "$work/stage" --sort=name --owner=0 --group=0 --numeric-owner --mtime="@$sde" \
    -czf "$work/SOURCES/djos-optimizer-$ver.tar.gz" "djos-optimizer-$ver" || die "no se pudo armar el tar"

inner_cmd=(bash "$src/packaging/build-rpm.sh" --inner "$work")
if [ -f /etc/fedora-release ] && { [ -e /run/.containerenv ] || [ -e /.dockerenv ]; }; then
    "${inner_cmd[@]}"; rc=$?
elif command -v podman > /dev/null; then
    image=${DJOS_BUILD_IMAGE:-registry.fedoraproject.org/fedora:44}
    say "Contenedor $image"
    # la caché de dnf queda en un volumen: la segunda vez no baja todo de nuevo
    podman run --rm --security-opt label=disable \
        -v "$work:$work" -v djos-rpmbuild-dnf:/var/cache/libdnf5 \
        -e DJOS_DRAFT -e DJOS_SKIP_REPO_CHECKS \
        "$image" "${inner_cmd[@]}"
    rc=$?
else
    die "hace falta podman (o correr esto adentro de un contenedor fedora:44)"
fi

shopt -s nullglob
built=("$work"/RPMS/noarch/*.rpm "$work"/SRPMS/*.src.rpm)
[ ${#built[@]} -gt 0 ] || die "no se armó ningún RPM"
cp -f "${built[@]}" "$out/" || die "no pude copiar a $out"
[ -f "$work/rpmlint.txt" ] && cp -f "$work/rpmlint.txt" "$out/rpmlint.txt"
say "Listo:"
for f in "${built[@]}"; do echo "  $out/${f##*/}"; done
[ -f "$work/rpmlint.txt" ] && echo "rpmlint: $(tail -n 1 "$work/rpmlint.txt")"
[ "$rc" -eq 0 ] || die "hubo errores (arriba el detalle)"
exit 0
