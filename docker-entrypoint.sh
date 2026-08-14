#!/bin/bash
# Runs before systemd. Applies the desktop password from ROCKY_PASSWORD
# (default: changeme) and prepares shared folders for host volume mounts.
set -euo pipefail

PASSWORD="${ROCKY_PASSWORD:-changeme}"
echo "rocky:${PASSWORD}" | chpasswd

# Preserve VNC session config if a volume replaced $HOME
if [ ! -f /home/rocky/.vnc/config ]; then
  mkdir -p /home/rocky/.vnc
  printf 'session=gnome-xorg\ngeometry=1440x900\ndepth=24\n' > /home/rocky/.vnc/config
fi

# Host mounts (especially on Docker Desktop) often arrive as root-owned.
for dir in /home/rocky /home/rocky/Shared /home/rocky/Documents /home/rocky/Downloads \
           /home/rocky/Desktop /home/rocky/.vnc /home/rocky/.config /home/rocky/.local \
           /home/rocky/.cache; do
  mkdir -p "$dir"
done
chown -R rocky:rocky /home/rocky || true

exec "$@"
