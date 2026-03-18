#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run as root: sudo $0"
  exit 1
fi

WAYBAR_DIR="/home/fahad/.config/waybar"
HOOK_SCRIPT="$WAYBAR_DIR/scripts/bluetooth-sleep-hook.sh"
POLICY_FILE="$WAYBAR_DIR/bluetooth-policy.conf"
SYSTEM_HOOK="/etc/systemd/system-sleep/waybar-bluetooth"
STATE_FILE="/var/lib/waybar-bluetooth-suspend.state"

if [[ ! -x "$HOOK_SCRIPT" ]]; then
  echo "Missing or non-executable hook: $HOOK_SCRIPT"
  exit 1
fi

mkdir -p /etc/systemd/system-sleep
mkdir -p /var/lib

cat >"$SYSTEM_HOOK" <<HOOK
#!/usr/bin/env bash
set -euo pipefail

export WAYBAR_BT_POLICY_FILE="$POLICY_FILE"
export WAYBAR_BT_STATE_FILE="$STATE_FILE"

exec "$HOOK_SCRIPT" "$1"
HOOK

chmod 0755 "$SYSTEM_HOOK"

echo "Installed: $SYSTEM_HOOK"
echo "Policy file: $POLICY_FILE"
echo "State file: $STATE_FILE"
