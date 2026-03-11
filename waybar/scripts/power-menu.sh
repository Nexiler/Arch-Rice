#!/usr/bin/env bash

set -euo pipefail

lock_screen() {
  if command -v hyprlock >/dev/null 2>&1; then
    if ! pgrep -x hyprlock >/dev/null 2>&1; then
      hyprlock >/dev/null 2>&1 &
      disown || true
    fi
    return 0
  fi

  loginctl lock-session
}

choose_menu() {
  if command -v rofi >/dev/null 2>&1; then
    rofi -dmenu -i -p "Power" -theme ~/.config/rofi/power-menu.rasi
    return
  fi

  if command -v wofi >/dev/null 2>&1; then
    wofi --dmenu --prompt "Power"
    return
  fi

  exit 1
}

run_action() {
  case "$1" in
    lock)
      lock_screen
      ;;
    suspend)
      lock_screen || true
      sleep 1
      systemctl suspend
      ;;
    logout)
      if command -v hyprctl >/dev/null 2>&1; then
        hyprctl dispatch exit
      else
        loginctl terminate-user "$USER"
      fi
      ;;
    reboot)
      systemctl reboot
      ;;
    poweroff)
      systemctl poweroff
      ;;
  esac
}

case "${1:-menu}" in
  lock|suspend|logout|reboot|poweroff)
    run_action "$1"
    exit 0
    ;;
esac

selection=$(printf 'Lock\nSuspend\nLogout\nReboot\nPower Off\n' | choose_menu)
[[ -z "$selection" ]] && exit 0

case "$selection" in
  Lock)
    run_action lock
    ;;
  Suspend)
    run_action suspend
    ;;
  Logout)
    run_action logout
    ;;
  Reboot)
    run_action reboot
    ;;
  "Power Off")
    run_action poweroff
    ;;
esac