#!/usr/bin/env bash
# Prueba de .config/hypr/scripts/paquetes.sh sin tocar el sistema: lista con un
# `pacman -Qie` falso, desinstalar con PAQUETES_PACMAN=echo, y la lista contra
# el pacman real en sólo lectura. Nunca llama a desinstalar sin PAQUETES_PACMAN.
cd "$(dirname "$0")/../.." || exit 1
S=$PWD/.config/hypr/scripts/paquetes.sh
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fallos=0
ok() { echo "OK    $1"; }
ko() { echo "FALLO $1"; fallos=$((fallos + 1)); }
es() { if [ "$2" = "$3" ]; then ok "$1"; else ko "$1 (esperado «$3», salió «$2»)"; fi; }

paq() { # nombre versión descripción tamaño requeridos
	printf 'Name            : %s\nVersion         : %s\nDescription     : %s\nArchitecture    : x86_64\nDepends On      : None\nRequired By     : %s\nInstalled Size  : %s\nInstall Reason  : Explicitly installed\n\n' "$1" "$2" "$3" "$5" "$4"
}
{
	paq zen-browser 1.0-1 'Navegador normal' '12.34 MiB' None
	paq base 3-2 'Base del sistema' '0.00 B' 'a  b'
	paq linux-zen-headers 6.1.zen1-1 'Cabeceras' '100.00 MiB' None
	paq linux-zen 6.1.zen1-1 'Kernel zen' '150.00 MiB' None
	paq paru-bin 2.0-1 'Ayudante AUR' '9.00 MiB' None
	paq linux-firmware-intel 1-1 'Firmware' '5.00 MiB' None
	paq linux-atm 2.5-1 'Programa que sólo empieza por linux' '1.00 MiB' None
	paq linux-cachyos-lts 6.1-1 'Kernel cachyos lts' '150.00 MiB' None
	paq largo 1-1 'Una descripción muy larga que sigue
                  en una segunda línea con sangría	y un tabulador' '1.50 KiB' 'x  y  z'
} >"$T/qi"
printf 'paru-bin\n' >"$T/qm"

out=$(PAQUETES_QI=$T/qi PAQUETES_QM=$T/qm "$S" lista); es 'lista sale 0' $? 0
es 'lista: orden por nombre' "$(cut -f1 <<<"$out" | paste -sd' ')" 'base largo linux-atm linux-cachyos-lts linux-firmware-intel linux-zen linux-zen-headers paru-bin zen-browser'
campo() { awk -F'\t' -v n="$1" -v c="$2" '$1 == n { print $c }' <<<"$out"; }
es 'lista: 7 campos en todas' "$(awk -F'\t' 'NF != 7' <<<"$out" | wc -l)" 0
es 'zen-browser: versión' "$(campo zen-browser 2)" 1.0-1
es 'zen-browser: tamaño' "$(campo zen-browser 3)" '12.34 MiB'
es 'zen-browser: origen repo' "$(campo zen-browser 4)" repo
es 'zen-browser: no protegido' "$(campo zen-browser 5)" 0
es 'zen-browser: 0 requeridos' "$(campo zen-browser 6)" 0
es 'paru-bin: origen aur' "$(campo paru-bin 4)" aur
es 'paru-bin: no protegido (no es paru exacto)' "$(campo paru-bin 5)" 0
es 'base: protegido' "$(campo base 5)" 1
es 'base: 2 requeridos' "$(campo base 6)" 2
es 'linux-zen: protegido' "$(campo linux-zen 5)" 1
es 'linux-zen-headers: no protegido' "$(campo linux-zen-headers 5)" 0
es 'linux-cachyos-lts: protegido' "$(campo linux-cachyos-lts 5)" 1
es 'linux-firmware-intel: protegido' "$(campo linux-firmware-intel 5)" 1
es 'linux-atm: no protegido (no es un núcleo)' "$(campo linux-atm 5)" 0
es 'largo: 3 requeridos' "$(campo largo 6)" 3
es 'largo: descripción unida, sin tabs' "$(campo largo 7)" 'Una descripción muy larga que sigue en una segunda línea con sangría y un tabulador'

PAQUETES_PACMAN=echo PAQUETES_SIN_ESPERA=1 "$S" desinstalar foo >"$T/o" 2>&1
es 'desinstalar normal: sale 0' $? 0
es 'desinstalar normal: orden -Rns -- foo' "$(cat "$T/o")" '-Rns -- foo'
PAQUETES_PACMAN=echo PAQUETES_SIN_ESPERA=1 "$S" desinstalar foo linux-zen >"$T/o" 2>&1
es 'desinstalar con protegido: sale 2' $? 2
if grep -q -e '-Rns' "$T/o"; then ko 'desinstalar con protegido: no llama a pacman'; else ok 'desinstalar con protegido: no llama a pacman'; fi
grep -q linux-zen "$T/o" && ok 'desinstalar con protegido: dice cuál' || ko 'desinstalar con protegido: dice cuál'
PAQUETES_PACMAN=echo PAQUETES_SIN_ESPERA=1 "$S" desinstalar >/dev/null 2>&1
es 'desinstalar sin argumentos: sale 2' $? 2

real=$("$S" lista); es 'real: lista sale 0' $? 0
es 'real: nº de líneas == pacman -Qqe' "$(wc -l <<<"$real")" "$(pacman -Qqe | wc -l)"
es 'real: 7 campos en cada línea' "$(awk -F'\t' 'NF != 7' <<<"$real" | wc -l)" 0

if [ "$fallos" -eq 0 ]; then echo 'Todo OK'; else echo "$fallos FALLOS"; exit 1; fi
