#!/usr/bin/env bash
# Waybar custom/gpu: one shot of NVIDIA telemetry (RTX 5070), ~15ms per call.
# Prints an empty "text" when nvidia-smi is unavailable so the module hides
# itself instead of showing a permanently broken value.

set -uo pipefail

line=$(nvidia-smi \
	--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,name \
	--format=csv,noheader,nounits 2>/dev/null | head -1)

if [[ -z $line ]]; then
	printf '{"text":"","alt":"none","class":"none"}\n'
	exit 0
fi

IFS=',' read -r util temp used total power name <<<"$line"

trim() { echo "${1}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }
util=$(trim "$util")
temp=$(trim "$temp")
used=$(trim "$used")
total=$(trim "$total")
power=$(trim "$power")
name=$(trim "$name")

# Colour the module the same way cpu/memory colour themselves.
class=normal
if ((util >= 90)); then
	class=critical
elif ((util >= 70)); then
	class=warning
fi

tooltip="$name"$'\n'"Uso ${util}% · ${temp}°C"$'\n'"VRAM ${used} / ${total} MiB"
[[ $power != "[N/A]" ]] && tooltip+=$'\n'"Consumo ${power} W"

jq -cn \
	--arg text "${util}% ${temp}°" \
	--arg class "$class" \
	--arg tooltip "$tooltip" \
	'{text: $text, alt: $class, class: $class, tooltip: $tooltip}'
