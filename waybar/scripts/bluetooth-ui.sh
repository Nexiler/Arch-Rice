#!/usr/bin/env bash

set -euo pipefail

launch_interactive_pairing() {
  if ! command -v bluetoothctl >/dev/null 2>&1; then
    return 1
  fi

  if ! command -v kitty >/dev/null 2>&1; then
    return 1
  fi

  if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exec "[float; center; size 980 720] kitty --class waybar-bluetooth --title waybar-bluetooth /home/fahad/.config/waybar/scripts/bluetooth-interactive.sh"
    exit 0
  fi

  exec kitty --class waybar-bluetooth --title waybar-bluetooth /home/fahad/.config/waybar/scripts/bluetooth-interactive.sh
}

launch_interactive_pairing || exec blueman-manager