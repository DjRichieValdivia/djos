#!/usr/bin/bash
# Revisa los scripts de DJOS: sintaxis (bash -n; los de Python, que compilen) y shellcheck. Solo los errores
# frenan (salida 1); los avisos de shellcheck se muestran. Mira system/usr/libexec/djos, system/usr/bin,
# bootstrap y packaging. Lo corre CI; a mano: sh packaging/lint.sh
# Sin shellcheck instalado usa la imagen docker.io/koalaman/shellcheck-alpine con podman.
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
set -u

repo=$(cd "$(dirname "$0")/.." && pwd) || exit 1
cd "$repo" || exit 1
fail=0
sh_files=()
py_files=()
for f in system/usr/libexec/djos/* system/usr/bin/* bootstrap/* packaging/*.sh; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    case "$(head -n 1 "$f")" in
        '#!'*python*) py_files+=("$f") ;;
        '#!'*sh*) sh_files+=("$f") ;;
        *) case "$f" in *.sh) sh_files+=("$f") ;; esac ;;
    esac
done
echo "lint: ${#sh_files[@]} scripts de shell, ${#py_files[@]} de Python"

for f in "${sh_files[@]}"; do
    bash -n "$f" || { echo "lint: error de sintaxis en $f"; fail=1; }
done
if [ ${#py_files[@]} -gt 0 ]; then
    if command -v python3 > /dev/null; then
        for f in "${py_files[@]}"; do
            python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1])' "$f" ||
                { echo "lint: error de sintaxis en $f"; fail=1; }
        done
    else
        echo "lint: sin python3, no reviso ${py_files[*]}"
    fi
fi

if command -v shellcheck > /dev/null; then
    sc=(shellcheck)
elif command -v podman > /dev/null; then
    sc=(podman run --rm --log-driver=none --security-opt label=disable -v "$repo:/mnt:ro" -w /mnt
        docker.io/koalaman/shellcheck-alpine:stable shellcheck)
else
    echo "lint: falta shellcheck (y podman para usar su imagen)"
    exit 1
fi
if [ ${#sh_files[@]} -gt 0 ]; then
    echo "lint: shellcheck, errores:"
    "${sc[@]}" -S error -f gcc "${sh_files[@]}" || fail=1
    warnings=$("${sc[@]}" -S warning -f gcc "${sh_files[@]}" 2>&1)
    if [ -n "$warnings" ]; then
        echo "lint: shellcheck, avisos (no frenan): $(printf '%s\n' "$warnings" | grep -c ': warning: ')"
        printf '%s\n' "$warnings"
    fi
fi

[ "$fail" -eq 0 ] && echo "lint: ok" || echo "lint: HAY ERRORES"
exit "$fail"
