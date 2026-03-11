#!/usr/bin/env bash

set -euo pipefail

refresh_waybar() {
  pkill -RTMIN+11 waybar >/dev/null 2>&1 || true
}

choose_menu() {
  if command -v rofi >/dev/null 2>&1; then
    rofi -dmenu -i -p "Microphone" -theme ~/.config/rofi/microphone-menu.rasi
    return
  fi

  if command -v wofi >/dev/null 2>&1; then
    wofi --dmenu --prompt "Microphone"
    return
  fi

  exit 1
}

list_sources() {
  pactl list short sources | awk '!/\.monitor/ { print $2 }'
}

apply_action() {
  case "$1" in
    toggle)
      wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      ;;
    up)
      wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ 5%+
      ;;
    down)
      wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-
      ;;
    set-0)
      wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0
      ;;
    set-25)
      wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.25
      ;;
    set-50)
      wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.50
      ;;
    set-75)
      wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 0.75
      ;;
    set-100)
      wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1.00
      ;;
    set-125)
      wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ 1.25
      ;;
    set-150)
      wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SOURCE@ 1.50
      ;;
    source:*)
      pactl set-default-source "${1#source:}"
      ;;
  esac

  refresh_waybar
}

case "${1:-menu}" in
  toggle|up|down|set-0|set-25|set-50|set-75|set-100|set-125|set-150|source:*)
    apply_action "$1"
    exit 0
    ;;
esac

default_source=$(pactl get-default-source 2>/dev/null || true)
volume_line=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || true)
mute_label="Mute"
if [[ "$volume_line" == *"[MUTED]"* ]]; then
  mute_label="Unmute"
fi

options=$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
  "$mute_label" \
  "Volume 0%" \
  "Volume 25%" \
  "Volume 50%" \
  "Volume 75%" \
  "Volume 100%" \
  "Boost 125%")
options+=$(printf '%s\n' "Boost 150%")

while IFS= read -r source_name; do
  [[ -z "$source_name" ]] && continue
  suffix=""
  if [[ "$source_name" == "$default_source" ]]; then
    suffix=" [default]"
  fi
  options+=$(printf 'Source: %s%s\n' "$source_name" "$suffix")
done < <(list_sources)

selection=$(printf '%s' "$options" | choose_menu)
[[ -z "$selection" ]] && exit 0

case "$selection" in
  Mute|Unmute)
    apply_action toggle
    ;;
  "Volume 0%")
    apply_action set-0
    ;;
  "Volume 25%")
    apply_action set-25
    ;;
  "Volume 50%")
    apply_action set-50
    ;;
  "Volume 75%")
    apply_action set-75
    ;;
  "Volume 100%")
    apply_action set-100
    ;;
  "Boost 125%")
    apply_action set-125
    ;;
  "Boost 150%")
    apply_action set-150
    ;;
  Source:\ *)
    source_name=${selection#Source: }
    source_name=${source_name% \[default\]}
    apply_action "source:${source_name}"
    ;;
esac