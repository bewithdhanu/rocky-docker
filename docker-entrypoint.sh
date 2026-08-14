#!/bin/bash
# Runs before systemd.
# - ROCKY_PASSWORD: Linux user "rocky" login/sudo password (default: changeme)
# - VNC_PASSWORD: noVNC / VNC connection password (default: changeme) — separate
set -euo pipefail

ROCKY_PASS="${ROCKY_PASSWORD:-changeme}"
VNC_PASS="${VNC_PASSWORD:-changeme}"

echo "rocky:${ROCKY_PASS}" | chpasswd

mkdir -p /home/rocky/.vnc

# Preserve VNC session config if a volume replaced $HOME
if [ ! -f /home/rocky/.vnc/config ]; then
  printf 'session=gnome-xorg\ngeometry=1440x900\ndepth=24\n' > /home/rocky/.vnc/config
fi

# TigerVNC stores a DES-hashed password (max 8 characters are used)
printf '%s\n' "$VNC_PASS" | vncpasswd -f > /home/rocky/.vnc/passwd
chmod 600 /home/rocky/.vnc/passwd

# Host mounts (especially on Docker Desktop) often arrive as root-owned.
for dir in /home/rocky /home/rocky/Shared /home/rocky/Documents /home/rocky/Downloads \
           /home/rocky/Desktop /home/rocky/.vnc /home/rocky/.config /home/rocky/.local \
           /home/rocky/.cache; do
  mkdir -p "$dir"
done
chown -R rocky:rocky /home/rocky || true

exec "$@"
