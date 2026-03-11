#!/usr/bin/env bash

set -euo pipefail

cat <<'EOF'
Bluetooth pairing session

This window handles passkey confirmation directly.

Useful commands:
  devices
  pair <MAC>
  trust <MAC>
  connect <MAC>
  remove <MAC>
  scan off
  quit

When prompted with "Confirm passkey" or "Authorize service",
type yes and press Enter.
EOF

exec bluetoothctl --agent KeyboardDisplay --init-script /home/fahad/.config/waybar/scripts/bluetoothctl-init.txt