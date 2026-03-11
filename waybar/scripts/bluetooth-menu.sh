#!/usr/bin/env bash

set -euo pipefail

if ! command -v rofi >/dev/null 2>&1; then
  exec /home/fahad/.config/waybar/scripts/bluetooth-ui.sh
fi

controller_state="$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ { print $2; exit }')"

if [[ "$controller_state" == "yes" ]]; then
  toggle_label="Turn Bluetooth Off"
else
  toggle_label="Turn Bluetooth On"
fi

choice="$(printf '%s\n' \
  "Open Bluetooth Manager" \
  "Open bluetoothctl" \
  "$toggle_label" \
  "Adapters" | rofi -dmenu -i -p 'Bluetooth' -theme-str 'window {width: 26em;} listview {lines: 4;}')"

case "$choice" in
  "Open Bluetooth Manager")
    exec blueman-manager
    ;;
  "Open bluetoothctl")
    exec /home/fahad/.config/waybar/scripts/bluetooth-ui.sh
    ;;
  "Turn Bluetooth Off"|"Turn Bluetooth On")
    exec /home/fahad/.config/waybar/scripts/bluetooth-toggle.sh
    ;;
  "Adapters")
    exec blueman-adapters
    ;;
esac