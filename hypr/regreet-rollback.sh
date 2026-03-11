#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

backup_dir="${1:-}"

if [[ -z "${backup_dir}" ]]; then
    backup_dir="$(ls -dt /etc/greetd/backup-*-regreet 2>/dev/null | head -n1 || true)"
fi

if [[ -z "${backup_dir}" || ! -d "${backup_dir}" ]]; then
    echo "Backup directory not found." >&2
    exit 1
fi

if [[ -f "${backup_dir}/config.toml" ]]; then
    cp -a "${backup_dir}/config.toml" /etc/greetd/config.toml
fi

if [[ -f "${backup_dir}/cosmic-greeter.toml" ]]; then
    cp -a "${backup_dir}/cosmic-greeter.toml" /etc/greetd/cosmic-greeter.toml
fi

systemctl disable greetd.service || true
systemctl enable cosmic-greeter.service

echo "Rollback prepared successfully. Reboot to return to COSMIC Greeter."