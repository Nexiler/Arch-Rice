#!/usr/bin/env bash

set -euo pipefail

json_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//"/\\"}
  value=${value//$'\n'/\\n}
  printf '%s' "$value"
}

default_source=$(pactl get-default-source 2>/dev/null || true)
if [[ -z "$default_source" ]]; then
  printf '{"text":"","tooltip":"No microphone source available","class":"muted"}\n'
  exit 0
fi

volume_line=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || true)
volume=$(printf '%s\n' "$volume_line" | awk '{print $2}')
muted=false
if [[ "$volume_line" == *"[MUTED]"* ]]; then
  muted=true
fi

if [[ -z "$volume" ]]; then
  volume=0
fi

percent=$(awk -v value="$volume" 'BEGIN { printf "%d", (value * 100) + 0.5 }')
description=$(wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | sed -n 's/.*node.description = "\(.*\)"/\1/p' | head -n 1)
if [[ -z "$description" ]]; then
  description="$default_source"
fi

icon=""
class="active"
if [[ "$muted" == true ]]; then
  icon=""
  class="muted"
elif (( percent > 100 )); then
  class="boosted"
fi

tooltip=$(printf '%s
Input %s%%%s
Left click: actions
Right click: mute
Scroll: adjust level' "$description" "$percent" "$( [[ "$muted" == true ]] && printf ' muted' )")
tooltip=$(json_escape "$tooltip")

printf '{"text":"%s","tooltip":"%s","class":"%s","percentage":%s}\n' "$icon" "$tooltip" "$class" "$percent"