#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
wallpaper_src="${1:-/home/fahad/A4/Pictures/Wallpapers/1-totoro.png}"
wallpaper_name="$(basename -- "${wallpaper_src}")"
backup_dir="/etc/greetd/backup-$(date +%Y%m%d-%H%M%S)-regreet-theme"
wallpaper_dst="/etc/greetd/backgrounds/${wallpaper_name}"

if [[ ! -f "${wallpaper_src}" ]]; then
    echo "Wallpaper not found: ${wallpaper_src}" >&2
    exit 1
fi

install -d -m 755 "${backup_dir}"

for file in /etc/greetd/regreet.toml /etc/greetd/regreet.css /etc/greetd/config.toml; do
    if [[ -f "${file}" ]]; then
        cp -a "${file}" "${backup_dir}/$(basename -- "${file}")"
    fi
done

install -d -m 755 /etc/greetd/backgrounds
install -m 644 "${wallpaper_src}" "${wallpaper_dst}"
sed "s|/etc/greetd/backgrounds/1-totoro.png|${wallpaper_dst}|" "${script_dir}/regreet.toml" > /etc/greetd/regreet.toml
install -m 644 "${script_dir}/regreet.css" /etc/greetd/regreet.css

echo "Theme applied. Backup: ${backup_dir}"
echo "Wallpaper copied to: ${wallpaper_dst}"
echo "Reboot to load the new ReGreet theme."