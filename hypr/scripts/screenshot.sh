#!/bin/sh

set -eu

mode="${1:-menu}"
pictures_dir=""

if command -v xdg-user-dir >/dev/null 2>&1; then
    pictures_dir="$(xdg-user-dir PICTURES 2>/dev/null || true)"
fi

if [ -z "$pictures_dir" ] || [ "$pictures_dir" = "$HOME" ]; then
    pictures_dir="$HOME/Pictures"
fi

save_dir="$pictures_dir/Screenshots"
timestamp="$(date +"%Y-%m-%d_%H-%M-%S")"
file="$save_dir/screenshot_$timestamp.png"

mkdir -p "$save_dir"

choose_mode() {
    printf '%s\n' "Screen" "Region" | rofi -dmenu -i -p "Screenshot" -theme ~/.config/rofi/style.rasi
}

capture_screen() {
    geometry="$(slurp -o)"
    [ -n "$geometry" ] || exit 0
    grim -g "$geometry" "$file"
}

capture_region() {
    geometry="$(slurp)"
    [ -n "$geometry" ] || exit 0
    grim -g "$geometry" "$file"
}

case "$mode" in
    menu)
        selection="$(choose_mode)" || exit 0
        case "$selection" in
            Screen) mode="screen" ;;
            Region) mode="region" ;;
            *) exit 0 ;;
        esac
        ;;
    screen|region)
        ;;
    *)
        notify-send "Screenshot" "Unknown mode: $mode"
        exit 1
        ;;
esac

case "$mode" in
    screen) capture_screen ;;
    region) capture_region ;;
esac

wl-copy --type image/png < "$file"
notify-send "Screenshot saved" "$(basename "$file") copied to clipboard"