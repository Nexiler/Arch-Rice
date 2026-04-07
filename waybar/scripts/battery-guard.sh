#!/usr/bin/env bash

set -euo pipefail

POLICY_FILE="${WAYBAR_BATTERY_POLICY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/waybar/battery-policy.conf}"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/waybar-battery-guard"
PERSISTENT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/waybar-battery-guard"
LAST_NOTIFY_FILE="$STATE_DIR/last_notify"
SUSPEND_LOCK_FILE="$STATE_DIR/suspend_action_taken"
POWEROFF_LOCK_FILE="$STATE_DIR/poweroff_action_taken"
SUSPEND_MARKER_FILE="$PERSISTENT_STATE_DIR/suspended_once"
LAST_POWER_STATE_FILE="$STATE_DIR/last_power_state"
LAST_LEVEL_STATE_FILE="$STATE_DIR/last_level_state"

LOW_BATTERY_WARN_THRESHOLD=25
LOW_BATTERY_SUSPEND_THRESHOLD=20
LOW_BATTERY_POWEROFF_THRESHOLD=15
LOW_BATTERY_GRACE_SECONDS=20
LOW_BATTERY_COOLDOWN_SECONDS=300

BATTERY_SOUND_ENABLED=1
BATTERY_SOUND_BACKEND="auto"
BATTERY_SOUND_ON_STARTUP=0
BATTERY_SOUND_EVENT_PLUGGED="power-plug"
BATTERY_SOUND_EVENT_UNPLUGGED="power-unplug"
BATTERY_SOUND_EVENT_LOW="battery-low"
BATTERY_SOUND_EVENT_CRITICAL="battery-caution"
BATTERY_SOUND_FILE_PLUGGED=""
BATTERY_SOUND_FILE_UNPLUGGED=""
BATTERY_SOUND_FILE_LOW=""
BATTERY_SOUND_FILE_CRITICAL=""

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

play_sound() {
  local event_id="$1"
  local file_path="${2:-}"

  if [[ "${BATTERY_SOUND_ENABLED}" != "1" ]]; then
    return
  fi

  case "$BATTERY_SOUND_BACKEND" in
    auto)
      if have_cmd canberra-gtk-play; then
        if [[ -n "$event_id" ]]; then
          canberra-gtk-play -i "$event_id" >/dev/null 2>&1 || true
          return
        fi
      fi
      if have_cmd paplay && [[ -n "$file_path" && -r "$file_path" ]]; then
        paplay "$file_path" >/dev/null 2>&1 || true
      fi
      ;;
    canberra)
      if have_cmd canberra-gtk-play && [[ -n "$event_id" ]]; then
        canberra-gtk-play -i "$event_id" >/dev/null 2>&1 || true
      fi
      ;;
    paplay)
      if have_cmd paplay && [[ -n "$file_path" && -r "$file_path" ]]; then
        paplay "$file_path" >/dev/null 2>&1 || true
      fi
      ;;
    none)
      ;;
    *)
      ;;
  esac
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

power_state_bucket() {
  case "$1" in
    charging|fully-charged|pending-charge)
      printf 'plugged\n'
      ;;
    discharging|pending-discharge)
      printf 'unplugged\n'
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

battery_level_bucket() {
  local capacity="$1"
  if (( capacity <= LOW_BATTERY_POWEROFF_THRESHOLD )); then
    printf 'critical\n'
  elif (( capacity <= LOW_BATTERY_WARN_THRESHOLD )); then
    printf 'low\n'
  else
    printf 'normal\n'
  fi
}

handle_power_state_sound() {
  local state="$1"
  local bucket last_bucket

  bucket="$(power_state_bucket "$state")"
  if [[ "$bucket" == "unknown" ]]; then
    return
  fi

  last_bucket=""
  if [[ -f "$LAST_POWER_STATE_FILE" ]]; then
    last_bucket="$(cat "$LAST_POWER_STATE_FILE" 2>/dev/null || true)"
  fi

  if [[ -z "$last_bucket" ]]; then
    printf '%s\n' "$bucket" >"$LAST_POWER_STATE_FILE"
    if [[ "$BATTERY_SOUND_ON_STARTUP" == "1" ]]; then
      if [[ "$bucket" == "plugged" ]]; then
        play_sound "$BATTERY_SOUND_EVENT_PLUGGED" "$BATTERY_SOUND_FILE_PLUGGED"
      else
        play_sound "$BATTERY_SOUND_EVENT_UNPLUGGED" "$BATTERY_SOUND_FILE_UNPLUGGED"
      fi
    fi
    return
  fi

  if [[ "$bucket" == "$last_bucket" ]]; then
    return
  fi

  printf '%s\n' "$bucket" >"$LAST_POWER_STATE_FILE"
  if [[ "$bucket" == "plugged" ]]; then
    play_sound "$BATTERY_SOUND_EVENT_PLUGGED" "$BATTERY_SOUND_FILE_PLUGGED"
  else
    play_sound "$BATTERY_SOUND_EVENT_UNPLUGGED" "$BATTERY_SOUND_FILE_UNPLUGGED"
  fi
}

handle_level_state_sound() {
  local capacity="$1"
  local state="$2"
  local bucket last_bucket

  if ! is_discharging_state "$state"; then
    printf 'normal\n' >"$LAST_LEVEL_STATE_FILE"
    return
  fi

  bucket="$(battery_level_bucket "$capacity")"
  last_bucket=""
  if [[ -f "$LAST_LEVEL_STATE_FILE" ]]; then
    last_bucket="$(cat "$LAST_LEVEL_STATE_FILE" 2>/dev/null || true)"
  fi

  if [[ -z "$last_bucket" ]]; then
    printf '%s\n' "$bucket" >"$LAST_LEVEL_STATE_FILE"
    return
  fi

  if [[ "$bucket" == "$last_bucket" ]]; then
    return
  fi

  printf '%s\n' "$bucket" >"$LAST_LEVEL_STATE_FILE"
  case "$bucket" in
    low)
      play_sound "$BATTERY_SOUND_EVENT_LOW" "$BATTERY_SOUND_FILE_LOW"
      ;;
    critical)
      play_sound "$BATTERY_SOUND_EVENT_CRITICAL" "$BATTERY_SOUND_FILE_CRITICAL"
      ;;
    *)
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

  handle_power_state_sound "$state"
  handle_level_state_sound "$capacity" "$state"

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
