#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")"

notify_error() {
  local body="$1"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Quick Menu" "$body"
  fi
}

status_badge() {
  if [[ "$1" == "1" ]]; then
    printf '[ON]'
  else
    printf '[OFF]'
  fi
}

is_wifi_on() {
  if ! command -v nmcli >/dev/null 2>&1; then
    return 1
  fi

  [[ "$(nmcli radio wifi 2>/dev/null | awk 'NR==1 { print tolower($0) }')" == "enabled" ]]
}

is_bluetooth_on() {
  if ! command -v bluetoothctl >/dev/null 2>&1; then
    return 1
  fi

  [[ "$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ { state=$2 } END { print state }')" == "yes" ]]
}

is_mic_muted() {
  if ! command -v wpctl >/dev/null 2>&1; then
    return 1
  fi

  wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q '\[MUTED\]'
}

get_power_profile() {
  if ! command -v powerprofilesctl >/dev/null 2>&1; then
    printf 'Unavailable'
    return
  fi

  case "$(powerprofilesctl get 2>/dev/null || true)" in
    power-saver)
      printf 'Power Saver'
      ;;
    balanced)
      printf 'Balanced'
      ;;
    performance)
      printf 'Performance'
      ;;
    *)
      printf 'Unknown'
      ;;
  esac
}

get_brightness() {
  if ! command -v brightnessctl >/dev/null 2>&1; then
    printf 'Unavailable'
    return
  fi

  local info="$(brightnessctl i 2>/dev/null | grep -i 'current brightness' || true)"
  if [[ -n "$info" ]]; then
    echo "$info" | sed -n 's/.*Current brightness: \(.*\)/\1/p'
  else
    printf 'Unknown'
  fi
}

toggle_wifi() {
  if [[ -x "$SCRIPT_DIR/network-toggle.sh" ]]; then
    "$SCRIPT_DIR/network-toggle.sh" >/dev/null 2>&1 || true
    return
  fi

  notify_error "Wi-Fi toggle script not found"
}

toggle_bluetooth() {
  if [[ -x "$SCRIPT_DIR/bluetooth-toggle.sh" ]]; then
    "$SCRIPT_DIR/bluetooth-toggle.sh" >/dev/null 2>&1 || true
    return
  fi

  notify_error "Bluetooth toggle script not found"
}

toggle_mic() {
  if [[ -x "$SCRIPT_DIR/microphone-menu.sh" ]]; then
    "$SCRIPT_DIR/microphone-menu.sh" toggle >/dev/null 2>&1 || true
    return
  fi

  if command -v wpctl >/dev/null 2>&1; then
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle >/dev/null 2>&1 || true
    return
  fi

  notify_error "Microphone control not available"
}

open_network_manager() {
  if [[ -x "$SCRIPT_DIR/network-menu.sh" ]]; then
    "$SCRIPT_DIR/network-menu.sh" >/dev/null 2>&1 &
    return
  fi

  notify_error "Network manager script not found"
}

open_bluetooth_manager() {
  if command -v blueman-manager >/dev/null 2>&1; then
    blueman-manager >/dev/null 2>&1 &
    return
  fi

  if [[ -x "$SCRIPT_DIR/bluetooth-ui.sh" ]]; then
    "$SCRIPT_DIR/bluetooth-ui.sh" >/dev/null 2>&1 &
    return
  fi

  notify_error "Bluetooth manager is not available"
}

open_audio_mixer() {
  if command -v pavucontrol >/dev/null 2>&1; then
    pavucontrol >/dev/null 2>&1 &
    return
  fi

  notify_error "pavucontrol is not installed"
}

set_power_profile() {
  local mode="$1"

  if ! command -v powerprofilesctl >/dev/null 2>&1; then
    notify_error "powerprofilesctl is not installed"
    return
  fi

  powerprofilesctl set "$mode" >/dev/null 2>&1 || notify_error "Failed to set power profile"
}

print_rofi_row() {
  local label="$1"
  local action="$2"
  printf '%s\0info\x1f%s\n' "$label" "$action"
}

print_rofi_separator() {
  local label="$1"
  printf '%s\0nonselectable\x1ftrue\n' "$label"
}

print_rofi_menu() {
  local wifi_state="0"
  local bt_state="0"
  local mic_unmuted="0"
  local power_state
  local brightness_val

  if is_wifi_on; then
    wifi_state="1"
  fi

  if is_bluetooth_on; then
    bt_state="1"
  fi

  if ! is_mic_muted; then
    mic_unmuted="1"
  fi

  power_state="$(get_power_profile)"
  brightness_val="$(get_brightness)"

  printf '\0prompt\x1fSystem Menu\n'
  printf '\0no-custom\x1ftrue\n'
  printf '\0keep-selection\x1ftrue\n'

  print_rofi_row "󰤨  Toggle Wi-Fi                 $(status_badge "$wifi_state")" "toggle_wifi"
  print_rofi_row "  Toggle Bluetooth             $(status_badge "$bt_state")" "toggle_bluetooth"
  print_rofi_row "  Toggle Microphone            $(status_badge "$mic_unmuted")" "toggle_mic"

  print_rofi_separator "──────── Display & Power ────────"
  print_rofi_row "󰃠  Brightness: ${brightness_val}" "noop"
  print_rofi_row "󰾆  Power: ${power_state}" "noop"
  print_rofi_row "󰏫  Set: Power Saver" "power_saver"
  print_rofi_row "󰾆  Set: Balanced" "power_balanced"
  print_rofi_row "󰓅  Set: Performance" "power_performance"

  print_rofi_separator "──────── Quick Access ────────"
  print_rofi_row "󰖩  Network Manager" "open_network"
  print_rofi_row "󰂯  Bluetooth Manager" "open_bluetooth"
  print_rofi_row "󰕾  Audio Mixer" "open_audio"
  print_rofi_row "󰅖  Close" "close"
}

menu_lines_plain() {
  local wifi_state="0"
  local bt_state="0"
  local mic_unmuted="0"
  local power_state
  local brightness_val

  if is_wifi_on; then
    wifi_state="1"
  fi

  if is_bluetooth_on; then
    bt_state="1"
  fi

  if ! is_mic_muted; then
    mic_unmuted="1"
  fi

  power_state="$(get_power_profile)"
  brightness_val="$(get_brightness)"

  printf '%s\n' \
    "󰤨  Toggle Wi-Fi                 $(status_badge "$wifi_state")" \
    "  Toggle Bluetooth             $(status_badge "$bt_state")" \
    "  Toggle Microphone            $(status_badge "$mic_unmuted")" \
    "──────── Display & Power ────────" \
    "󰃠  Brightness: ${brightness_val}" \
    "󰾆  Power: ${power_state}" \
    "󰏫  Set: Power Saver" \
    "󰾆  Set: Balanced" \
    "󰓅  Set: Performance" \
    "──────── Quick Access ────────" \
    "󰖩  Network Manager" \
    "󰂯  Bluetooth Manager" \
    "󰕾  Audio Mixer" \
    "󰅖  Close"
}

apply_action() {
  case "$1" in
    toggle_wifi)
      toggle_wifi
      ;;
    toggle_bluetooth)
      toggle_bluetooth
      ;;
    toggle_mic)
      toggle_mic
      ;;
    power_saver)
      set_power_profile power-saver
      ;;
    power_balanced)
      set_power_profile balanced
      ;;
    power_performance)
      set_power_profile performance
      ;;
    open_network)
      open_network_manager
      ;;
    open_bluetooth)
      open_bluetooth_manager
      ;;
    open_audio)
      open_audio_mixer
      ;;
  esac
}

run_rofi_mode() {
  local action="${ROFI_INFO:-}"
  local close_after_action="0"

  if [[ "${ROFI_RETV:-0}" == "1" && -n "$action" ]]; then
    if [[ "$action" == "close" ]]; then
      exit 1
    fi

    case "$action" in
      open_network|open_bluetooth|open_audio)
        close_after_action="1"
        ;;
    esac

    if [[ "$action" != "noop" ]]; then
      apply_action "$action"
    fi

    if [[ "$close_after_action" == "1" ]]; then
      exit 0
    fi
  fi

  print_rofi_menu
}

run_wofi_fallback() {
  while true; do
    local choice
    choice="$(menu_lines_plain | wofi --dmenu --prompt "System Menu" --hide-search)"

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
      *Toggle\ Wi-Fi*) apply_action toggle_wifi ;;
      *Toggle\ Bluetooth*) apply_action toggle_bluetooth ;;
      *Toggle\ Microphone*) apply_action toggle_mic ;;
      *Set:\ Power\ Saver*) apply_action power_saver ;;
      *Set:\ Balanced*) apply_action power_balanced ;;
      *Set:\ Performance*) apply_action power_performance ;;
      *Network\ Manager*) apply_action open_network ;;
      *Bluetooth\ Manager*) apply_action open_bluetooth ;;
      *Audio\ Mixer*) apply_action open_audio ;;
      *Close*|*────*) exit 0 ;;
      *) ;;
    esac
  done
}

if [[ "${1:-}" == "--rofi-mode" ]]; then
  run_rofi_mode
  exit 0
fi

if command -v rofi >/dev/null 2>&1; then
  exec rofi -show systemmenu \
    -modi "systemmenu:${SCRIPT_PATH} --rofi-mode" \
    -theme ~/.config/rofi/misc-menu.rasi
fi

if command -v wofi >/dev/null 2>&1; then
  run_wofi_fallback
fi

exit 1
