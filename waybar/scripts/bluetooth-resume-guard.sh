#!/usr/bin/env bash

set -euo pipefail

lock_file="/tmp/bluetooth-resume-guard.lock"
exec 9>"$lock_file"

if ! flock -n 9; then
  exit 0
fi

if ! command -v dbus-monitor >/dev/null 2>&1; then
  exit 0
fi

if ! command -v bluetoothctl >/dev/null 2>&1; then
  exit 0
fi

dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" 2>/dev/null |
while IFS= read -r line; do
  if [[ "$line" == *"boolean false"* ]]; then
    bluetoothctl power off >/dev/null 2>&1 || true
  fi
done
