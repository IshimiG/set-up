#!/usr/bin/env bash
# La fecha en español para la pantalla de bloqueo (hyprlock.conf): "Miércoles,
# 7 de octubre". Va en un script y no con LC_TIME=es_ES en la propia línea de
# hyprlock porque ese locale no tiene por qué estar generado, y entonces date
# la escribe en inglés sin avisar.

set -uo pipefail

dias=(Lunes Martes Miércoles Jueves Viernes Sábado Domingo)
meses=(enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre)

read -r dia_semana dia mes < <(date '+%u %-d %-m')
printf '%s, %s de %s\n' "${dias[dia_semana - 1]}" "$dia" "${meses[mes - 1]}"
