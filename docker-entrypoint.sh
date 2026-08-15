#!/bin/bash
# Runs before systemd.
# - ROCKY_PASSWORD: Linux user "rocky" login/sudo password (default: changeme)
# - VNC_PASSWORD: noVNC / VNC connection password (default: changeme) — separate
# - NOVNC_PORT: host listen port for the noVNC web UI (default: 6080; not 5901)
set -euo pipefail

ROCKY_PASS="${ROCKY_PASSWORD:-changeme}"
VNC_PASS="${VNC_PASSWORD:-changeme}"
NOVNC_LISTEN="${NOVNC_PORT:-6080}"

echo "rocky:${ROCKY_PASS}" | chpasswd
usermod -U rocky 2>/dev/null || true
command -v faillock >/dev/null && faillock --user rocky --reset 2>/dev/null || true

# See the Dockerfile: on Ubuntu hosts PAM's helper is confined by the host's
# "unix-chkpwd" AppArmor profile and cannot use CAP_DAC_OVERRIDE, so it needs
# group-read on /etc/shadow. Re-assert it in case a password tool reset the mode.
chgrp shadow /etc/shadow 2>/dev/null || true
chmod 0640 /etc/shadow 2>/dev/null || true

# The desktop terminal's prompt shows this hostname. If it differs, the browser
# is attached to an older container and the new password will not match.
echo "[init] container $(hostname)"
echo "[init] linux user 'rocky' password set (${#ROCKY_PASS} chars): $(passwd -S rocky 2>/dev/null | awk '{print $2}')"

# The VNC protocol only carries 8 characters, so anything longer is silently
# ignored by clients. Truncate here and say so, instead of failing to log in.
VNC_PASS_EFFECTIVE="${VNC_PASS:0:8}"
if [ "${#VNC_PASS}" -gt 8 ]; then
  echo "[init] WARNING: VNC_PASSWORD is ${#VNC_PASS} chars; VNC only uses the first 8."
  echo "[init] WARNING: connect using these 8 characters: ${VNC_PASS_EFFECTIVE}"
fi
echo "[init] vnc password set (${#VNC_PASS_EFFECTIVE} chars in use)"

# Host networking: websockify binds NOVNC_PORT on the host. TigerVNC owns 5901.
if [ "$NOVNC_LISTEN" = "5901" ]; then
  echo "[init] WARNING: NOVNC_PORT=5901 conflicts with TigerVNC; using 6080 instead."
  NOVNC_LISTEN=6080
fi
if [ -f /etc/systemd/system/novnc.service ]; then
  sed -i -E "s|^(ExecStart=/usr/bin/websockify --web=/usr/share/novnc) [0-9]+ |\1 ${NOVNC_LISTEN} |" \
    /etc/systemd/system/novnc.service
fi
echo "[init] noVNC listening on http://0.0.0.0:${NOVNC_LISTEN}/vnc.html"

# Let rocky use the host Docker engine via the mounted socket.
if [ -S /var/run/docker.sock ]; then
  SOCK_GID="$(stat -c '%g' /var/run/docker.sock 2>/dev/null || echo "")"
  if [ -n "$SOCK_GID" ] && [ "$SOCK_GID" != "0" ]; then
    SOCK_GROUP="$(getent group "$SOCK_GID" | cut -d: -f1 || true)"
    if [ -z "$SOCK_GROUP" ]; then
      SOCK_GROUP=hostdocker
      groupadd -g "$SOCK_GID" "$SOCK_GROUP" 2>/dev/null || \
        groupadd "$SOCK_GROUP" 2>/dev/null || true
      SOCK_GROUP="$(getent group "$SOCK_GID" | cut -d: -f1 || echo hostdocker)"
    fi
    usermod -aG "$SOCK_GROUP" rocky 2>/dev/null || true
    echo "[init] docker.sock gid=${SOCK_GID} → rocky in group ${SOCK_GROUP}"
  else
    # Socket is root-only; still usable via sudo docker …
    echo "[init] docker.sock present (root-owned); use: sudo docker …"
  fi
else
  echo "[init] WARNING: /var/run/docker.sock not mounted — host Docker unavailable"
fi

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
