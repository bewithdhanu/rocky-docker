# rocky-docker

Rocky Linux 9 desktop in Docker. Open it in a browser — no VM install needed.

![Rocky Linux desktop](docs/desktop.png)

GNOME with a Windows-style taskbar and start menu, plus the usual apps (Firefox, LibreOffice, GIMP, etc.). Works on Mac (Apple Silicon), Linux, and Windows (Docker Desktop).

## Requirements

- Docker + Docker Compose
- ~4 GB free RAM (8 GB is more comfortable)
- Port 6080 free

## Quick start

```bash
cp .env.example .env
docker compose up -d --build
```

First build takes a few minutes. When it's up:

1. Open http://localhost:6080/vnc.html
2. Click **Connect** and enter the VNC password (`changeme` by default)
3. Desktop user is `rocky` — password is whatever you set as `ROCKY_PASSWORD`

These are two different passwords on purpose.

## Config

`.env` controls the basics:

```env
# Linux user rocky (sudo / terminal login)
ROCKY_PASSWORD=changeme

# noVNC prompt when you click Connect (first 8 chars count)
VNC_PASSWORD=changeme

NOVNC_PORT=6080

# host folders mounted into the desktop
ROCKY_HOME=./data/home
SHARED_DIR=./data/shared
DOCUMENTS_DIR=./data/documents
DOWNLOADS_DIR=./data/downloads
```

Point `SHARED_DIR` at a real folder if you want host files inside the container:

```env
SHARED_DIR=/Users/you/Projects
```

They show up under `/home/rocky/Shared` (also Documents / Downloads).

## Useful commands

```bash
docker compose logs -f
docker compose down
docker compose up -d
```

## Notes

- Needs `--privileged` / host cgroups because GNOME wants systemd-logind. Compose sets that for you.
- Image is architecture-specific. Build on the machine you'll run it on (arm64 vs amd64).
- This is Rocky Linux, not RHEL. Same package layout as RHEL 9, no Red Hat subscription required.

## License

MIT
