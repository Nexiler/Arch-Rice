#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${WAYBAR_BT_STATE_FILE:-${XDG_RUNTIME_DIR:-/tmp}/waybar-bluetooth-suspend.state}"
POLICY_FILE="${WAYBAR_BT_POLICY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/waybar/bluetooth-policy.conf}"
RESUME_POLICY="restore"

if [[ -f "$POLICY_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$POLICY_FILE" || true
  RESUME_POLICY="${BLUETOOTH_RESUME_POLICY:-$RESUME_POLICY}"
fi

if ! command -v bluetoothctl >/dev/null 2>&1; then
  exit 0
fi

get_power_state() {
  local powered
  powered="$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ { print $2; exit }')"

  case "$powered" in
    yes)
      printf 'on\n'
      ;;
    no)
      printf 'off\n'
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

set_power_state() {
  local target="$1"
  local try

  for try in 1 2 3 4 5; do
    if [[ "$target" == "on" ]]; then
      bluetoothctl power on >/dev/null 2>&1 || true
    else
      bluetoothctl power off >/dev/null 2>&1 || true
    fi

    if [[ "$(get_power_state)" == "$target" ]]; then
      return 0
    fi

    sleep 0.4
  done

  return 1
}

handle_pre_sleep() {
  printf '%s\n' "$(get_power_state)" >"$STATE_FILE"
}

handle_post_sleep() {
  local before_sleep="unknown"

  if [[ -f "$STATE_FILE" ]]; then
    before_sleep="$(head -n 1 "$STATE_FILE" 2>/dev/null || printf 'unknown\n')"
  fi

  # Give BlueZ/controller a moment to settle after wake.
  sleep 0.8

  if [[ "$RESUME_POLICY" == "off" ]]; then
    set_power_state off || true
    # Some stacks can re-enable Bluetooth shortly after resume; enforce off again.
    ( sleep 2; bluetoothctl power off >/dev/null 2>&1 || true ) &
    ( sleep 5; bluetoothctl power off >/dev/null 2>&1 || true ) &
    return
  fi

  if [[ "$before_sleep" == "on" ]]; then
    set_power_state on || true
  else
    set_power_state off || true
    # Keep off if it was off before suspend, even if something powers it back on.
    ( sleep 2; bluetoothctl power off >/dev/null 2>&1 || true ) &
    ( sleep 5; bluetoothctl power off >/dev/null 2>&1 || true ) &
  fi
}

case "${1:-}" in
  pre)
    handle_pre_sleep
    ;;
  post)
    handle_post_sleep
    ;;
  *)
    exit 0
    ;;
esac
