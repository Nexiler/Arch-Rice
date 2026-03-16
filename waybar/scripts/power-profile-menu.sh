#!/usr/bin/env bash

set -euo pipefail

if ! command -v powerprofilesctl >/dev/null 2>&1; then
  exit 0
fi

choose_menu() {
  if command -v rofi >/dev/null 2>&1; then
    rofi -dmenu -i -p "Battery" -theme ~/.config/rofi/power-menu.rasi -theme-str 'entry { placeholder: "Choose battery mode..."; }'
    return
  fi

  if command -v wofi >/dev/null 2>&1; then
    wofi --dmenu --prompt "Power Profile"
    return
  fi

  exit 1
}

selection=$(printf 'Power Saver\nBalanced\nPerformance\n' | choose_menu)
[[ -z "$selection" ]] && exit 0

case "$selection" in
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
