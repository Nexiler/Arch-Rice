#!/usr/bin/env bash

set -euo pipefail

POLICY_FILE="${WAYBAR_BATTERY_POLICY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/waybar/battery-policy.conf}"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-battery-guard"
PERSISTENT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-battery-guard"
LAST_NOTIFY_FILE="$STATE_DIR/last_notify"
SUSPEND_LOCK_FILE="$STATE_DIR/suspend_action_taken"
POWEROFF_LOCK_FILE="$STATE_DIR/poweroff_action_taken"
SUSPEND_MARKER_FILE="$PERSISTENT_STATE_DIR/suspended_once"

LOW_BATTERY_WARN_THRESHOLD=25
LOW_BATTERY_SUSPEND_THRESHOLD=20
LOW_BATTERY_POWEROFF_THRESHOLD=15
LOW_BATTERY_GRACE_SECONDS=20
LOW_BATTERY_COOLDOWN_SECONDS=300

if [[ -f "$POLICY_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$POLICY_FILE" || true
fi

mkdir -p "$STATE_DIR"
mkdir -p "$PERSISTENT_STATE_DIR"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

log() {
  printf '[battery-guard] %s\n' "$*" >&2
}

send_notification() {
  local urgency="$1"
  local title="$2"
  local body="$3"

  if have_cmd notify-send; then
    notify-send -u "$urgency" "$title" "$body" || true
  fi
}

read_battery_status() {
  local bat_path info percent state

  if have_cmd upower; then
    bat_path="$(upower -e 2>/dev/null | grep -m1 -E 'battery(_|$|-)')"
    if [[ -n "$bat_path" ]]; then
      info="$(upower -i "$bat_path" 2>/dev/null || true)"
      percent="$(printf '%s\n' "$info" | awk '/percentage:/ { gsub("%", "", $2); print int($2); exit }')"
      state="$(printf '%s\n' "$info" | awk '/state:/ { print $2; exit }')"
      if [[ -n "$percent" && -n "$state" ]]; then
        printf '%s %s\n' "$percent" "$state"
        return 0
      fi
    fi
  fi

  local bat
  bat="$(ls /sys/class/power_supply 2>/dev/null | grep -m1 -E '^BAT')"
  if [[ -n "$bat" && -r "/sys/class/power_supply/$bat/capacity" ]]; then
    percent="$(cat "/sys/class/power_supply/$bat/capacity")"
    if [[ -r "/sys/class/power_supply/$bat/status" ]]; then
      state="$(tr '[:upper:]' '[:lower:]' <"/sys/class/power_supply/$bat/status")"
    else
      state="unknown"
    fi
    printf '%s %s\n' "$percent" "$state"
    return 0
  fi

  return 1
}

is_discharging_state() {
  case "$1" in
    discharging)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

clear_suspend_lock() {
  rm -f "$SUSPEND_LOCK_FILE"
}

clear_poweroff_lock() {
  rm -f "$POWEROFF_LOCK_FILE"
}

mark_suspend_lock() {
  printf '%s\n' "$(date +%s)" >"$SUSPEND_LOCK_FILE"
}

mark_poweroff_lock() {
  printf '%s\n' "$(date +%s)" >"$POWEROFF_LOCK_FILE"
}

mark_suspend_marker() {
  printf '%s\n' "$(date +%s)" >"$SUSPEND_MARKER_FILE"
}

clear_suspend_marker() {
  rm -f "$SUSPEND_MARKER_FILE"
}

has_suspend_marker() {
  [[ -f "$SUSPEND_MARKER_FILE" ]]
}

cooldown_expired() {
  local now last
  now="$(date +%s)"
  if [[ ! -f "$LAST_NOTIFY_FILE" ]]; then
    return 0
  fi
  last="$(cat "$LAST_NOTIFY_FILE" 2>/dev/null || printf '0')"
  (( now - last >= LOW_BATTERY_COOLDOWN_SECONDS ))
}

mark_notified_now() {
  date +%s >"$LAST_NOTIFY_FILE"
}

perform_suspend() {
  systemctl suspend
}

perform_poweroff() {
  systemctl poweroff
}

evaluate_battery() {
  local info capacity state

  if ! info="$(read_battery_status)"; then
    log "No battery data available"
    return
  fi

  capacity="${info%% *}"
  state="${info##* }"

  if ! [[ "$capacity" =~ ^[0-9]+$ ]]; then
    return
  fi

  if ! is_discharging_state "$state"; then
    clear_suspend_lock
    clear_poweroff_lock
    clear_suspend_marker
    return
  fi

  if (( capacity <= LOW_BATTERY_WARN_THRESHOLD )) && cooldown_expired; then
    send_notification "normal" "Battery low" "Battery at ${capacity}%"
    mark_notified_now
  fi

  if (( capacity > LOW_BATTERY_SUSPEND_THRESHOLD )); then
    clear_suspend_lock
    clear_poweroff_lock
    clear_suspend_marker
    return
  fi

  if has_suspend_marker; then
    if (( capacity > LOW_BATTERY_POWEROFF_THRESHOLD )); then
      clear_poweroff_lock
      return
    fi

    if [[ -f "$POWEROFF_LOCK_FILE" ]]; then
      return
    fi

    send_notification "critical" "Battery critical" "${capacity}% remaining. Shutdown in ${LOW_BATTERY_GRACE_SECONDS}s unless charging."
    sleep "$LOW_BATTERY_GRACE_SECONDS"

    if ! info="$(read_battery_status)"; then
      return
    fi

    capacity="${info%% *}"
    state="${info##* }"

    if [[ "$capacity" =~ ^[0-9]+$ ]] && is_discharging_state "$state" && (( capacity <= LOW_BATTERY_POWEROFF_THRESHOLD )); then
      mark_poweroff_lock
      perform_poweroff
    fi

    return
  fi

  if [[ -f "$SUSPEND_LOCK_FILE" ]]; then
    return
  fi

  send_notification "critical" "Battery critical" "${capacity}% remaining. Suspend in ${LOW_BATTERY_GRACE_SECONDS}s unless charging."
  sleep "$LOW_BATTERY_GRACE_SECONDS"

  if ! info="$(read_battery_status)"; then
    return
  fi

  capacity="${info%% *}"
  state="${info##* }"

  if [[ "$capacity" =~ ^[0-9]+$ ]] && is_discharging_state "$state" && (( capacity <= LOW_BATTERY_SUSPEND_THRESHOLD )); then
    mark_suspend_lock
    mark_suspend_marker
    perform_suspend
  fi
}

start_monitor() {
  if ! have_cmd upower; then
    log "upower not found, running periodic fallback checks"
    while true; do
      evaluate_battery
      sleep 30
    done
  fi

  evaluate_battery

  upower --monitor-detail 2>/dev/null | while IFS= read -r line; do
    if [[ "$line" =~ (state:|percentage:|on-battery:) ]]; then
      evaluate_battery
    fi
  done
}

start_monitor
