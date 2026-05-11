#!/usr/bin/env bash

set -euo pipefail

if ! command -v nmcli >/dev/null 2>&1; then
  exit 0
fi

wifi_state="$(nmcli radio wifi 2>/dev/null | awk 'NR==1 { print tolower($0) }')"

if [[ "$wifi_state" == "enabled" ]]; then
  exec nmcli radio wifi off
fi

exec nmcli radio wifi on