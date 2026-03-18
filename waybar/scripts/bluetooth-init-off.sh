#!/usr/bin/env bash

set -euo pipefail

UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_PATH="$UNIT_DIR/waybar-bluetooth-sleep.service"

cleanup_unused_unit() {
  if ! command -v systemctl >/dev/null 2>&1; then
    return
  fi

  systemctl --user disable --now waybar-bluetooth-sleep.service >/dev/null 2>&1 || true
  if [[ -f "$UNIT_PATH" ]]; then
    rm -f "$UNIT_PATH"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
}

cleanup_unused_unit

if command -v bluetoothctl >/dev/null 2>&1; then
  controller_info="$(bluetoothctl show 2>/dev/null || true)"
  controller_state="$(printf '%s\n' "$controller_info" | awk -F': ' '/Powered:/ { print $2 }')"
  if [[ "$controller_state" == "yes" ]]; then
    bluetoothctl power off >/dev/null 2>&1 || true
  fi
fi

printf '{"text":"","class":"hidden","tooltip":""}\n'
