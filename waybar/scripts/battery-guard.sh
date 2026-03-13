#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-battery-guard.state"
LOW_THRESHOLD=25
CRITICAL_THRESHOLD=15
HIBERNATE_THRESHOLD=10

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

notify() {
  local urgency="$1"
  local title="$2"
  local body="$3"

  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u "$urgency" "$title" "$body"
  fi
}

read_battery() {
  local bat_path
  bat_path="$(find /sys/class/power_supply -maxdepth 1 -type d -name 'BAT*' | head -n 1 || true)"
  [[ -z "$bat_path" ]] && return 1

  local status capacity
  status="$(cat "$bat_path/status" 2>/dev/null || true)"
  capacity="$(cat "$bat_path/capacity" 2>/dev/null || true)"

  [[ -z "$status" || -z "$capacity" ]] && return 1
  [[ ! "$capacity" =~ ^[0-9]+$ ]] && return 1

  printf '%s;%s\n' "$status" "$capacity"
}

load_state() {
  LAST_STATE="none"
  LAST_SUSPEND_AT="-1"

  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE" || true
  fi
}

save_state() {
  cat >"$STATE_FILE" <<EOF
LAST_STATE="$LAST_STATE"
LAST_SUSPEND_AT="$LAST_SUSPEND_AT"
EOF
}

main() {
  local battery_line status capacity level
  battery_line="$(read_battery || true)"

  if [[ -z "$battery_line" ]]; then
    printf '{"text":"","class":"hidden","tooltip":""}\n'
    exit 0
  fi

  IFS=';' read -r status capacity <<<"$battery_line"

  load_state

  if [[ "$status" == "Discharging" ]]; then
    if (( capacity <= CRITICAL_THRESHOLD )); then
      level="critical"
    elif (( capacity <= LOW_THRESHOLD )); then
      level="low"
    else
      level="normal"
    fi

    if [[ "$level" != "$LAST_STATE" ]]; then
      case "$level" in
        low)
          notify normal "Battery low" "Battery is at ${capacity}%. Plug in soon."
          ;;
        critical)
          notify critical "Battery critical" "Battery is at ${capacity}%. Hibernating soon if it keeps dropping."
          ;;
      esac
    fi

    if (( capacity <= HIBERNATE_THRESHOLD )) && [[ "$LAST_SUSPEND_AT" != "$capacity" ]]; then
      notify critical "Battery exhausted" "Battery is at ${capacity}%. Hibernating now to protect your session."
      if [[ -x "$SCRIPT_DIR/power-menu.sh" ]]; then
        "$SCRIPT_DIR/power-menu.sh" lock >/dev/null 2>&1 || true
      fi
      systemctl hibernate >/dev/null 2>&1 || systemctl suspend
      LAST_SUSPEND_AT="$capacity"
    fi

    LAST_STATE="$level"
  else
    LAST_STATE="normal"
    LAST_SUSPEND_AT="-1"
  fi

  save_state
  printf '{"text":"","class":"hidden","tooltip":""}\n'
}

main
