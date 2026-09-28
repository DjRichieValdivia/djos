#!/usr/bin/bash
# DJOS: arma los enlaces que el paquete trae en vez de copiar o pisar archivos de otros paquetes:
#   - íconos Papirus-Dark-DJOS: cada carpeta azul de Papirus-Dark (y sus alias: inode-directory, user-home…)
#     apunta a la naranja, como hace papirus-folders; 16x16 no (ahí Papirus-Dark no usa colores)
#   - Plymouth "djos": las imágenes del tema spinner (el logo, watermark.png, es nuestro)
# Se corre a mano cuando cambia Papirus o plymouth-theme-spinner, en un Fedora con papirus-icon-theme-dark,
# plymouth-theme-spinner y git; por ejemplo desde la raíz del repo:
#   podman run --rm -v "$PWD":/repo:z registry.fedoraproject.org/fedora:44 sh -c \
#     'dnf5 -y -q install git papirus-icon-theme-dark plymouth-theme-spinner && bash /repo/branding/gen-links.sh'
# Los enlaces van directo al índice de git (modo 120000): sirve igual en un checkout de Windows
# (core.symlinks=false, donde git los deja como archivos de texto con el destino adentro). No hace commit.
set -u

die() { echo "gen-links: $*" >&2; exit 1; }
repo=$(cd "$(dirname "$0")/.." && pwd) || die "no encuentro el repo"
git() { command git -c safe.directory='*' -C "$repo" "$@"; }
ICONS=${ICONS:-/usr/share/icons}
PLY=${PLY:-/usr/share/plymouth/themes}
theme=system/usr/share/icons/Papirus-Dark-DJOS
ply=system/usr/share/plymouth/themes/djos
[ -f "$ICONS/Papirus-Dark/index.theme" ] || die "falta Papirus-Dark (dnf install papirus-icon-theme-dark)"
[ -f "$PLY/spinner/spinner.plymouth" ] || die "falta el tema spinner (dnf install plymouth-theme-spinner)"

list=$(mktemp) || die "sin archivo temporal"
trap 'rm -f "$list"' EXIT

# ruta<TAB>destino (relativo, así sirve en cualquier raíz)
{
    sizes="22x22 24x24 32x32 48x48 64x64"
    for s in $sizes; do
        for f in "$ICONS/Papirus-Dark/$s/places"/*; do
            b=${f##*/}
            case "$b" in folder-blue*|user-blue*) continue ;; esac   # los de color se piden por nombre de color
            t=$(readlink -f "$f") || continue
            t=${t##*/}
            case "$t" in
                folder-bluegrey*) continue ;;
                folder-blue.svg|folder-blue-*.svg|user-blue.svg|user-blue-*.svg) ;;
                *) continue ;;
            esac
            o=${t/-blue/-orange}
            [ -e "$ICONS/Papirus-Dark/$s/places/$o" ] || continue
            printf '%s/%s/places/%s\t../../../Papirus-Dark/%s/places/%s\n' "$theme" "$s" "$b" "$s" "$o"
        done
        # HiDPI: las mismas imágenes (igual que Papirus)
        printf '%s/%s@2x/places\t../%s/places\n' "$theme" "$s" "$s"
    done
    printf '%s/96x96/places\t../48x48/places\n%s/128x128/places\t../64x64/places\n' "$theme" "$theme"
    for f in "$PLY/spinner"/*.png; do
        b=${f##*/}
        [ "$b" = watermark.png ] && continue
        printf '%s/%s\t../spinner/%s\n' "$ply" "$b" "$b"
    done
} | LC_ALL=C sort > "$list"
[ "$(grep -c "^$theme/48x48/places/folder.svg" "$list")" = 1 ] || die "no encontré folder.svg en Papirus-Dark: ¿cambió su estructura?"

# fuera los enlaces viejos (del índice y del disco); index.theme y watermark.png no se tocan
old=()
while IFS= read -r -d '' rec; do
    [ "${rec%% *}" = 120000 ] && old+=("${rec#*$'\t'}")
done < <(git ls-files -s -z -- "$theme" "$ply")
if [ ${#old[@]} -gt 0 ]; then
    printf '%s\0' "${old[@]}" | git update-index -z --force-remove --stdin || die "no pude sacar los enlaces viejos"
    for p in "${old[@]}"; do rm -f "$repo/$p"; done
fi

links=$(git config --bool core.symlinks 2> /dev/null || echo true)
while IFS=$'\t' read -r p t; do
    mkdir -p "$repo/${p%/*}" || die "no pude crear ${p%/*}"
    if [ -d "$repo/$p" ] && [ ! -L "$repo/$p" ]; then die "$p es una carpeta de verdad"; fi
    if [ "$links" = true ]; then
        ln -sfn "$t" "$repo/$p" || die "no pude crear el enlace $p"
    else
        rm -f "$repo/$p" && printf '%s' "$t" > "$repo/$p" || die "no pude escribir $p"
    fi
    printf '120000 %s 0\t%s\n' "$(printf '%s' "$t" | git hash-object -w --stdin)" "$p"
done < "$list" | git update-index --add --index-info || die "no pude anotar los enlaces en git"

echo "gen-links: $(grep -c "^$theme/" "$list") enlaces de íconos, $(grep -c "^$ply/" "$list") de Plymouth (en el índice de git)"
