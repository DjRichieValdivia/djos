#!/usr/bin/bash
# DJOS: arma los enlaces que el paquete trae en vez de copiar o pisar archivos de otros paquetes:
#   - íconos Papirus-Dark-DJOS: una copia de Papirus-Dark hecha de enlaces, donde cada carpeta azul (y sus alias:
#     inode-directory, user-home…) apunta a la naranja, como hace papirus-folders; 16x16 no (ahí Papirus-Dark no
#     usa colores). Tiene que ser una copia COMPLETA (todas las carpetas de Papirus-Dark, y en places todos los
#     nombres): KDE acorta el nombre dentro de cada tema antes de mirar el tema padre, así que con solo las carpetas
#     "network-wired-activated" o "network-bluetooth-activated" terminaban en nuestro "network" (una carpeta
#     naranja en la bandeja). También arma el index.theme (el de Papirus-Dark más scalable/apps, los nuestros)
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

# ruta<TAB>destino (relativo, así sirve en cualquier raíz). Las carpetas que ya eran carpetas (o enlaces) en
# versiones anteriores siguen siéndolo: rpm no puede cambiar una carpeta por un enlace al actualizar
PD=$ICONS/Papirus-Dark
own="22x22 24x24 32x32 48x48 64x64"   # con carpetas naranjas
{
    for e in "$PD"/*; do
        b=${e##*/}
        [ -d "$e" ] || continue
        case " $own 96x96 128x128 " in *" ${b%@2x} "*) continue ;; esac
        printf '%s/%s\t../Papirus-Dark/%s\n' "$theme" "$b" "$b"   # 8x8, 16x16, 18x18, 42x42, 84x84…
    done
    for s in $own 96x96 128x128; do
        for e in "$PD/$s"/*; do
            sub=${e##*/}
            [ -d "$e" ] || continue
            if [ "$sub" != places ]; then
                printf '%s/%s/%s\t../../Papirus-Dark/%s/%s\n' "$theme" "$s" "$sub" "$s" "$sub"
                case " $own " in *" $s "*) printf '%s/%s@2x/%s\t../%s/%s\n' "$theme" "$s" "$sub" "$s" "$sub" ;; esac
                continue
            fi
            case $s in   # las grandes, con las naranjas de 48 y 64 (SVG: se ven igual)
                96x96) printf '%s/96x96/places\t../48x48/places\n' "$theme"; continue ;;
                128x128) printf '%s/128x128/places\t../64x64/places\n' "$theme"; continue ;;
            esac
            printf '%s/%s@2x/places\t../%s/places\n' "$theme" "$s" "$s"   # HiDPI: las mismas imágenes (igual que Papirus)
            for f in "$PD/$s/places"/*; do
                b=${f##*/}
                o=
                t=$(readlink -f "$f") || continue
                t=${t##*/}
                case "$b" in folder-blue*|user-blue*) ;;   # los de color se piden por nombre de color: quedan azules
                    *)  case "$t" in
                            folder-bluegrey*) ;;
                            folder-blue.svg|folder-blue-*.svg|user-blue.svg|user-blue-*.svg)
                                o=${t/-blue/-orange}; [ -e "$PD/$s/places/$o" ] || o= ;;
                        esac ;;
                esac
                printf '%s/%s/places/%s\t../../../Papirus-Dark/%s/places/%s\n' "$theme" "$s" "$b" "$s" "${o:-$b}"
            done
        done
    done
    for f in "$PLY/spinner"/*.png; do
        b=${f##*/}
        [ "$b" = watermark.png ] && continue
        printf '%s/%s\t../spinner/%s\n' "$ply" "$b" "$b"
    done
} | LC_ALL=C sort > "$list"
grep -q "^$theme/48x48/places/folder.svg	.*folder-orange" "$list" || die "no encontré folder.svg en Papirus-Dark: ¿cambió su estructura?"
grep -q "^$theme/22x22/panel	" "$list" || die "no encontré 22x22/panel en Papirus-Dark: ¿cambió su estructura?"

# fuera los enlaces viejos (del índice y del disco); watermark.png no se toca (index.theme se rehace abajo)
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

# index.theme: el de Papirus-Dark con nuestro nombre, heredando de él, y scalable/apps (los íconos propios de DJOS)
{
    cat <<'EOF'
# DJOS: Papirus Dark con carpetas naranjas (lo mismo que hace papirus-folders, pero sin tocar los archivos de
# Papirus). Es una copia completa de Papirus-Dark hecha de enlaces (las carpetas azules apuntan a las naranjas), y en
# scalable/apps están los íconos propios de DJOS: Dolphin, Discover y Configuración (naranjas) Richie DJ (un vinilo) y el menú (djos-start). Lo arma
# branding/gen-links.sh a partir del index.theme de Papirus-Dark: no editarlo a mano.
EOF
    awk '
        /^Name=/ && !n++ { print "Name=Papirus-Dark-DJOS"; next }
        /^Comment=/ && !c++ { print "Comment=Papirus Dark with orange folders (DJOS)"; next }
        /^Inherits=/ && !i++ { print "Inherits=Papirus-Dark,breeze-dark,hicolor"; next }
        /^Directories=/ && !d++ { print $0 ",scalable/apps"; next }
        { print }
    ' "$PD/index.theme"
    printf '\n# íconos de apps propios de DJOS (Dolphin, Discover, Configuración en naranja; Richie DJ, un vinilo; djos-start, el menú)\n'
    printf '[scalable/apps]\nContext=Applications\nSize=48\nMinSize=16\nMaxSize=512\nType=Scalable\n'
} > "$repo/$theme/index.theme" || die "no pude escribir index.theme"
grep -q '^Directories=.*22x22/panel.*,scalable/apps$' "$repo/$theme/index.theme" || die "index.theme quedó mal"
git add -- "$theme/index.theme" || die "no pude anotar index.theme en git"

echo "gen-links: $(grep -c "^$theme/" "$list") enlaces de íconos, $(grep -c "^$ply/" "$list") de Plymouth (en el índice de git)"
