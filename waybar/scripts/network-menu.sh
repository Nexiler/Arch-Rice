#!/usr/bin/env bash

set -euo pipefail

launch_nmtui() {
  if command -v nmcli >/dev/null 2>&1; then
    nmcli device wifi rescan >/dev/null 2>&1 || true
  fi

  if command -v hyprctl >/dev/null 2>&1 && command -v kitty >/dev/null 2>&1; then
    hyprctl dispatch exec "[float; center; size 980 700] kitty --class waybar-network --title waybar-network nmtui"
    exit 0
  fi

  if command -v kitty >/dev/null 2>&1; then
    exec kitty --class waybar-network --title waybar-network nmtui
  fi

  exec nmtui
}

launch_nmtui