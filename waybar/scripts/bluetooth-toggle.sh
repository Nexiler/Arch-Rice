#!/usr/bin/env bash

set -euo pipefail

if ! command -v bluetoothctl >/dev/null 2>&1; then
  exit 0
fi

controller_state="$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ { state=$2 } END { print state }')"

if [[ "$controller_state" == "yes" ]]; then
  systemctl --user stop obex.service
  bluetoothctl power off
else
  rfkill unblock bluetooth >/dev/null 2>&1 || true
  bluetoothctl power on
  systemctl --user start obex.service
fi
