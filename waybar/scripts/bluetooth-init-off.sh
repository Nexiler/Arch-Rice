#!/usr/bin/env bash

set -euo pipefail

if command -v bluetoothctl >/dev/null 2>&1; then
  controller_info="$(bluetoothctl show 2>/dev/null || true)"
  controller_state="$(printf '%s\n' "$controller_info" | awk -F': ' '/Powered:/ { print $2 }')"
  if [[ "$controller_state" == "yes" ]]; then
    bluetoothctl power off >/dev/null 2>&1 || true
  fi
fi

printf '{"text":"","class":"hidden","tooltip":""}\n'
