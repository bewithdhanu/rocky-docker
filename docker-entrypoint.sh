#!/bin/bash
# Runs before systemd.
# - ROCKY_PASSWORD: Linux user "rocky" login/sudo password (default: changeme)
# - VNC_PASSWORD: noVNC / VNC connection password (default: changeme) — separate
set -euo pipefail

ROCKY_PASS="${ROCKY_PASSWORD:-changeme}"
VNC_PASS="${VNC_PASSWORD:-changeme}"

echo "rocky:${ROCKY_PASS}" | chpasswd
echo "[init] linux user 'rocky' password set (${#ROCKY_PASS} chars)"

# The VNC protocol only carries 8 characters, so anything longer is silently
# ignored by clients. Truncate here and say so, instead of failing to log in.
VNC_PASS_EFFECTIVE="${VNC_PASS:0:8}"
if [ "${#VNC_PASS}" -gt 8 ]; then
  echo "[init] WARNING: VNC_PASSWORD is ${#VNC_PASS} chars; VNC only uses the first 8."
  echo "[init] WARNING: connect using these 8 characters: ${VNC_PASS_EFFECTIVE}"
fi
echo "[init] vnc password set (${#VNC_PASS_EFFECTIVE} chars in use)"

mkdir -p /home/rocky/.vnc

# Preserve VNC session config if a volume replaced $HOME
if [ ! -f /home/rocky/.vnc/config ]; then
  printf 'session=gnome-xorg\ngeometry=1440x900\ndepth=24\n' > /home/rocky/.vnc/config
fi

printf '%s\n' "$VNC_PASS_EFFECTIVE" | vncpasswd -f > /home/rocky/.vnc/passwd
chmod 600 /home/rocky/.vnc/passwd

# A mounted $HOME hides /etc/skel, which leaves an unconfigured "bash-5.1$" shell
for f in .bashrc .bash_profile .bash_logout; do
  [ -f "/home/rocky/$f" ] || cp -n "/etc/skel/$f" "/home/rocky/$f" 2>/dev/null || true
done

# Host mounts (especially on Docker Desktop) often arrive as root-owned.
for dir in /home/rocky /home/rocky/Shared /home/rocky/Documents /home/rocky/Downloads \
           /home/rocky/Desktop /home/rocky/.vnc /home/rocky/.config /home/rocky/.local \
           /home/rocky/.cache; do
  mkdir -p "$dir"
done
chown -R rocky:rocky /home/rocky || true

exec "$@"
