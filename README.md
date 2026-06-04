# pi-homelab

Infrastructure-as-code for my Raspberry Pi homelab: Docker stacks, env templates, and helper apps. Version-controlled so I can change services in Git and rebuild the Pi if hardware dies.

**Live Pi today:** `raspberrypi` — Audiobookshelf on port `13378`.

## Layout

```
pi-homelab/
├── stacks/                 # Docker Compose services
│   └── audiobookshelf/     # https://github.com/advplyr/audiobookshelf
├── apps/                   # Non-Docker apps on the Pi
│   └── scraper/
└── docs/
    ├── restore-pi.md
    └── backup.md
```

## Quick start (on the Pi)

```bash
git clone git@github.com:Mackewinsson/pi-homelab.git ~/projects/pi-homelab
cd ~/projects/pi-homelab/stacks/audiobookshelf
./install.sh
```

## Audiobookshelf

| Item | Value |
|------|--------|
| Image | `ghcr.io/advplyr/audiobookshelf:latest` |
| Port | `13378` → container `80` |
| Config | `./config` → `/config` |
| Metadata | `./metadata` → `/metadata` |
| Libraries | `./audiobooks`, `./podcasts` |

Env: copy `stacks/audiobookshelf/.env.example` to `.env` if you need a different host port.

```bash
cd stacks/audiobookshelf
docker compose pull
docker compose up -d
```

## From your Mac

```bash
ssh pi
cd ~/projects/pi-homelab/stacks/audiobookshelf && docker compose ps
```

## Adding another stack

1. Create `stacks/<service-name>/` with `docker-compose.yml` and `.env.example`.
2. Document ports and volumes in this README.
3. Commit and `git pull` on the Pi.

## Docs

- [AGENTS.md](AGENTS.md) — instructions for AI agents (SSH, deploy, safety)
- [Restore a dead Pi](docs/restore-pi.md)
- [What to back up outside Git](docs/backup.md)
