#!/usr/bin/env bash

set -euo pipefail

if ! command -v nmcli >/dev/null 2>&1; then
  exit 0
fi

networking_state="$(nmcli -t -f NETWORKING general status 2>/dev/null | head -n 1 || true)"

if [[ "$networking_state" == "enabled" ]]; then
  exec nmcli networking off
fi

exec nmcli networking on