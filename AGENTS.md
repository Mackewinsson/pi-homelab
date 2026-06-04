# Agent guide — pi-homelab

Instructions for AI agents (Cursor, CLI, etc.) operating this repository and the Raspberry Pi homelab.

## Purpose

This repo is **infrastructure-as-code** for a Raspberry Pi homelab. It is not the [audiobookshelf](https://github.com/advplyr/audiobookshelf) application source — only Docker Compose, env templates, install scripts, and optional Pi apps.

Goals:

- Change stacks in Git, deploy on the Pi
- Rebuild the Pi after hardware failure
- Add more open-source services under `stacks/`

## Environments

| Where | Path | Role |
|-------|------|------|
| **Mac (local)** | `~/projects/pi-homelab` | Edit, commit, push to GitHub |
| **GitHub** | `Mackewinsson/pi-homelab` | Source of truth |
| **Pi (production)** | See [Production paths](#production-paths) | Runs containers |

## SSH access (Mac → Pi)

Agents on the Mac should use the configured SSH host **`pi`** (alias `raspberrypi`):

```bash
ssh pi '<command>'
```

Expected `~/.ssh/config` on the Mac:

```
Host pi raspberrypi
    HostName raspberrypi.local
    User mackewinsson
    IdentityFile ~/.ssh/id_ed25519_raspberry
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

- Hostname: `raspberrypi.local` (mDNS; IP may change, often `10.100.200.176`)
- User: `mackewinsson`
- Architecture: **arm64** (use arm-compatible images)

Verify connectivity:

```bash
ssh pi 'hostname && docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
```

## Production paths

**Important:** Production may still use the **legacy** layout while this repo is the target layout.

| Layout | Audiobookshelf path on Pi |
|--------|---------------------------|
| **Legacy (current live)** | `~/projects/audiobookshelf/` |
| **Repo layout (target)** | `~/projects/pi-homelab/stacks/audiobookshelf/` |

Before changing production, check which path is active:

```bash
ssh pi 'docker inspect audiobookshelf --format "{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}"'
```

When migrating to the repo layout: stop the old stack, copy `config/`, `metadata/`, `audiobooks/`, `podcasts/` into the repo stack directory, then `docker compose up -d` from the new path. Update `docs/backup.md` paths after migration.

## Repository layout

```
pi-homelab/
├── AGENTS.md              # This file
├── README.md              # Human overview
├── stacks/                # Docker Compose — one folder per service
│   └── audiobookshelf/
│       ├── docker-compose.yml
│       ├── install.sh
│       ├── .env.example     # Copy to .env on Pi (gitignored)
│       ├── config/          # Runtime — gitignored
│       ├── metadata/        # Runtime — gitignored
│       ├── audiobooks/      # Media — gitignored
│       └── podcasts/        # Media — gitignored
├── apps/                  # Non-Docker apps (Python, etc.)
│   └── scraper/
└── docs/
    ├── restore-pi.md
    └── backup.md
```

## Conventions for new stacks

1. Add `stacks/<service-name>/` with:
   - `docker-compose.yml`
   - `.env.example` (never commit `.env`)
   - Optional `install.sh` if bootstrap is non-trivial
2. Use **bind mounts** under the stack directory for persistent data
3. Document port, image, and volumes in `README.md` and this file
4. Add paths to `.gitignore` for runtime data
5. Commit and push; on Pi: `git pull` then `docker compose up -d` in that stack folder

Do **not** fork upstream app repos into this repo — reference images and upstream docs only.

## Stack: Audiobookshelf

| Key | Value |
|-----|--------|
| Upstream | https://github.com/advplyr/audiobookshelf |
| Image | `ghcr.io/advplyr/audiobookshelf:latest` |
| Container name | `audiobookshelf` |
| Host port | `13378` (env `ABS_PORT` in `.env`) |
| Container port | `80` |
| Run as | `user: "1000:1000"` (Pi user `mackewinsson`) |

Volumes (relative to stack dir):

| Host | Container |
|------|-----------|
| `./audiobooks` | `/audiobooks` |
| `./podcasts` | `/podcasts` |
| `./metadata` | `/metadata` |
| `./config` | `/config` |

No custom `.env` is required for defaults. Optional:

```bash
cp .env.example .env
# ABS_PORT=13378
```

### Deploy / update (on Pi)

From the active stack directory:

```bash
docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f --tail=100
```

First-time or fresh Pi (from repo clone):

```bash
cd ~/projects/pi-homelab/stacks/audiobookshelf
chmod +x install.sh
./install.sh
```

### URLs

- http://raspberrypi.local:13378
- http://\<pi-ip\>:13378

### Reverse proxy note

Audiobookshelf requires **WebSocket** support if behind nginx/Traefik/Caddy. See upstream README. Subfolder path must be `/audiobookshelf` if using a subfolder (not configurable).

### Agent commands (Mac)

```bash
# Status
ssh pi 'docker ps -a --filter name=audiobookshelf'

# Restart stack (adjust cd if legacy path)
ssh pi 'cd ~/projects/audiobookshelf && docker compose restart'

# Pull latest image and recreate
ssh pi 'cd ~/projects/audiobookshelf && docker compose pull && docker compose up -d'
```

Replace `~/projects/audiobookshelf` with `~/projects/pi-homelab/stacks/audiobookshelf` after migration.

## App: Scraper (not Docker)

Path: `apps/scraper/`

```bash
ssh pi
cd ~/projects/pi-homelab/apps/scraper   # or legacy ~/projects/scraper
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # edit secrets locally, never commit .env
python -m src.scraper
# or: ./scripts/run.sh
```

Env vars (see `.env.example`): `SCRAPER_BASE_URL`, `SCRAPER_DELAY_SECONDS`, `LOG_LEVEL`.

## Git workflow

Local repo: `~/projects/pi-homelab`

```bash
cd ~/projects/pi-homelab
git status
git add <files>
git commit -m "message"
git push
```

On Pi after changes:

```bash
ssh pi 'cd ~/projects/pi-homelab && git pull'
```

Only create commits or push when the user asks.

## Backup and restore

**Never commit** runtime data listed in `.gitignore`.

| Data | Pi path (legacy) | Pi path (repo layout) |
|------|------------------|------------------------|
| DB + settings | `~/projects/audiobookshelf/config/` | `~/projects/pi-homelab/stacks/audiobookshelf/config/` |
| Metadata | `.../metadata/` | same under repo stack |
| Audiobooks | `.../audiobooks/` | same |
| Podcasts | `.../podcasts/` | same |

Backup to Mac (example):

```bash
rsync -avz --progress pi:~/projects/audiobookshelf/config/ ~/Backups/pi/audiobookshelf/config/
rsync -avz --progress pi:~/projects/audiobookshelf/metadata/ ~/Backups/pi/audiobookshelf/metadata/
```

Full restore procedure: `docs/restore-pi.md`  
Backup policy: `docs/backup.md`

## Safety rules for agents

1. **Do not commit** `.env`, SQLite DBs, `metadata/`, or media libraries
2. **Do not delete** `config/` or `metadata/` on the Pi without explicit user approval
3. **Do not run** `docker compose down -v` on production unless the user requests it (volumes are bind mounts but data loss risk remains)
4. **Do not** change `user: "1000:1000"` without checking Pi UID/GID (`id mackewinsson`)
5. **Prefer** `docker compose pull && docker compose up -d` over manual `docker rm` when updating
6. **Test** with `ssh pi 'docker compose ps'` after deploy changes
7. **Document** new ports in `README.md` and this file when adding stacks

## Troubleshooting

| Issue | Action |
|-------|--------|
| SSH fails | Ping `raspberrypi.local`; check VPN/LAN; try IP from router |
| Permission denied on volumes | Ensure dirs owned by `1000:1000` or matching compose `user` |
| Port in use | `ssh pi 'ss -tlnp \| grep 13378'`; change `ABS_PORT` in `.env` |
| Container unhealthy | `docker compose logs audiobookshelf` |
| Wrong data path | Inspect mounts: `docker inspect audiobookshelf --format '{{json .Mounts}}'` |

## Checklist: fresh Pi from this repo

1. Flash Raspberry Pi OS, enable SSH
2. `ssh-copy-id` with `id_ed25519_raspberry`
3. `git clone git@github.com:Mackewinsson/pi-homelab.git ~/projects/pi-homelab`
4. `cd ~/projects/pi-homelab/stacks/audiobookshelf && ./install.sh`
5. Restore `config/`, `metadata/`, media from backups if available
6. Open http://raspberrypi.local:13378

## Related docs

- [README.md](README.md) — human quick start
- [docs/restore-pi.md](docs/restore-pi.md) — disaster recovery
- [docs/backup.md](docs/backup.md) — what lives outside Git
