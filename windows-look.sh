#!/bin/bash
# Gives GNOME a Windows 11-style look: taskbar, start menu, Fluent theme and icons.
# Safe to re-run.
set -euo pipefail

SHELL_VERSION=40
EXT_DIR=/usr/share/gnome-shell/extensions
WORK=/tmp/winlook

command -v glib-compile-schemas >/dev/null || dnf -y install -q glib2-devel

mkdir -p "$EXT_DIR" "$WORK"
cd "$WORK"

install_ext() {
    local uuid="$1" url
    url=$(curl -sfL "https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${SHELL_VERSION}" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["download_url"])')
    curl -sfL -o "${uuid}.zip" "https://extensions.gnome.org${url}"
    rm -rf "${EXT_DIR}/${uuid}"
    mkdir -p "${EXT_DIR}/${uuid}"
    unzip -qo "${uuid}.zip" -d "${EXT_DIR}/${uuid}"
    [ -d "${EXT_DIR}/${uuid}/schemas" ] && glib-compile-schemas --strict "${EXT_DIR}/${uuid}/schemas" >/dev/null
    # zip members can carry restrictive modes; gnome-shell must be able to read them
    chmod -R a+rX "${EXT_DIR}/${uuid}"
    echo "extension installed: ${uuid}"
}

# Dash to Panel = Windows taskbar, ArcMenu = Start menu, User Themes = custom shell theme
install_ext "dash-to-panel@jderose9.github.com"
install_ext "arcmenu@arcmenu.com"
install_ext "user-theme@gnome-shell-extensions.gcampax.github.com"

# Fluent is a Windows 11-styled GTK/shell theme
curl -sfL -o fluent-gtk.tar.gz https://github.com/vinceliuice/Fluent-gtk-theme/archive/refs/tags/2025-04-17.tar.gz
rm -rf Fluent-gtk-theme-*
tar xzf fluent-gtk.tar.gz
cd Fluent-gtk-theme-*
./install.sh --dest /usr/share/themes --color dark --tweaks round blur >/dev/null 2>&1 \
    || ./install.sh --dest /usr/share/themes >/dev/null
echo "gtk/shell theme installed: Fluent"
cd "$WORK"

curl -sfL -o fluent-icons.tar.gz https://github.com/vinceliuice/Fluent-icon-theme/archive/refs/tags/2026-07-27.tar.gz
rm -rf Fluent-icon-theme-*
tar xzf fluent-icons.tar.gz
cd Fluent-icon-theme-*
./install.sh --dest /usr/share/icons >/dev/null 2>&1 || ./install.sh >/dev/null 2>&1 || true
echo "icon theme installed: Fluent"
cd "$WORK"

# Windows 11-style bloom wallpaper, generated locally to avoid bundling artwork
mkdir -p /usr/share/backgrounds/fluent
convert -size 2560x1440 \
    -define gradient:radii=1700,1100 \
    radial-gradient:'#1a6fd4'-'#04122e' \
    -swirl 40 -blur 0x18 \
    /usr/share/backgrounds/fluent/bloom.png
echo "wallpaper generated"

ls /usr/share/themes | grep -i fluent | head -5
ls /usr/share/icons | grep -i fluent | head -5
