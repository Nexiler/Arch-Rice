#!/usr/bin/env bash

set -euo pipefail

WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
SCRIPT_PATH="$WAYBAR_DIR/scripts/battery-guard.sh"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_PATH="$UNIT_DIR/waybar-battery-guard.service"

if [[ ! -x "$SCRIPT_PATH" ]]; then
  printf '{"text":"","class":"hidden","tooltip":"battery guard script not executable"}\n'
  exit 0
fi

mkdir -p "$UNIT_DIR"

cat >"$UNIT_PATH" <<UNIT
[Unit]
Description=Waybar low battery guard
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNIT

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user enable --now waybar-battery-guard.service >/dev/null 2>&1 || true
fi

printf '{"text":"","class":"hidden","tooltip":""}\n'
