#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

backup_dir="/etc/greetd/backup-$(date +%Y%m%d-%H%M%S)-regreet"

echo "Installing required packages..."
pacman -S --needed greetd greetd-regreet cage

echo "Creating backup in ${backup_dir}..."
install -d -m 755 "${backup_dir}"

if [[ -f /etc/greetd/config.toml ]]; then
    cp -a /etc/greetd/config.toml "${backup_dir}/config.toml"
fi

if [[ -f /etc/greetd/cosmic-greeter.toml ]]; then
    cp -a /etc/greetd/cosmic-greeter.toml "${backup_dir}/cosmic-greeter.toml"
fi

cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "cage -s -- regreet"
user = "greeter"
EOF

echo "Switching display-manager service to greetd..."
systemctl disable cosmic-greeter.service || true
systemctl disable lightdm.service || true
systemctl enable greetd.service

echo
echo "Migration prepared successfully."
echo "Backup: ${backup_dir}"
echo "Reboot to test ReGreet."
echo "If anything goes wrong, run: sudo $PWD/regreet-rollback.sh ${backup_dir}"