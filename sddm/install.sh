#!/usr/bin/env bash
# Installs the "cristal" SDDM theme.
#
#   sudo ~/Projects/set-up/sddm/install.sh
#
# The greeter runs as the "sddm" user and cannot read the home directory, so
# the theme is copied to /usr/share/sddm/themes and the current desktop
# wallpaper (the one in hyprpaper.conf) is copied next to it, scaled down so
# the greeter does not decode a 4000px JPEG on every boot. Re-run it after
# changing the wallpaper.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run it with sudo: sudo $0" >&2
    exit 1
fi

here="$(cd "$(dirname "$0")" && pwd)"
user_home="$(getent passwd "${SUDO_USER:-ishimimain}" | cut -d: -f6)"
dest=/usr/share/sddm/themes/cristal

wallpaper="$(sed -n 's/^[[:space:]]*path[[:space:]]*=[[:space:]]*//p' "$user_home/.config/hypr/hyprpaper.conf" | head -n1)"
if [[ ! -f "$wallpaper" ]]; then
    echo "Wallpaper not found: '$wallpaper'" >&2
    exit 1
fi

install -d "$dest"
install -m 644 "$here"/themes/cristal/{Main.qml,metadata.desktop,theme.conf} "$dest"/
magick "$wallpaper" -resize '2560x1440^' -gravity center -extent 2560x1440 -quality 92 "$dest/background.jpg"
chmod 644 "$dest/background.jpg"

install -d /etc/sddm.conf.d
install -m 644 "$here/10-cristal.conf" /etc/sddm.conf.d/10-cristal.conf

echo "Installed. Preview without logging out:"
echo "  sddm-greeter-qt6 --test-mode --theme $dest"
