#!/usr/bin/env bash

set -euo pipefail

if ! command -v powerprofilesctl >/dev/null 2>&1; then
  exit 0
fi

choose_menu() {
  local status="$1"

  if command -v rofi >/dev/null 2>&1; then
    rofi -dmenu -i -p "Battery" -mesg "$status" \
      -theme ~/.config/rofi/power-menu.rasi \
      -theme-str 'entry { enabled: false; } inputbar { enabled: false; } mainbox { children: [message, listview]; }'
    return
  fi

  if command -v wofi >/dev/null 2>&1; then
    wofi --dmenu --prompt "Power Profile" --hide-search
    return
  fi

  exit 1
}

current_profile=$(powerprofilesctl get 2>/dev/null || true)
case "$current_profile" in
  power-saver)
    status_line="Current: Power Saver"
    ;;
  balanced)
    status_line="Current: Balanced"
    ;;
  performance)
    status_line="Current: Performance"
    ;;
  *)
    status_line="Current: Unknown"
    ;;
esac

selection=$(printf '%s\nPower Saver\nBalanced\nPerformance\n' "$status_line" | choose_menu "$status_line")
[[ -z "$selection" ]] && exit 0

case "$selection" in
  "$status_line")
    exit 0
    ;;
  "Power Saver")
    powerprofilesctl set power-saver
    ;;
  "Balanced")
    powerprofilesctl set balanced
    ;;
  "Performance")
    powerprofilesctl set performance
    ;;
esac
