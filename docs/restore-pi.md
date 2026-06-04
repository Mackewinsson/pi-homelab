# Restore Raspberry Pi from this repo

Assumes Raspberry Pi OS, user `mackewinsson`, SSH host `pi` (see your Mac `~/.ssh/config`).

## 1. Clone on the Pi

```bash
mkdir -p ~/projects
git clone git@github.com:Mackewinsson/pi-homelab.git ~/projects/pi-homelab
```

## 2. Audiobookshelf (Docker)

```bash
cd ~/projects/pi-homelab/stacks/audiobookshelf
cp .env.example .env   # optional
chmod +x install.sh
./install.sh
```

Or manually:

```bash
docker compose pull
docker compose up -d
```

Open: `http://raspberrypi.local:13378`

## 3. Restore data (if you have backups)

See [backup.md](./backup.md). Copy `config/`, `metadata/`, and media folders into `~/projects/pi-homelab/stacks/audiobookshelf/` (or symlink from another disk).

## 4. Scraper (optional, not Docker)

```bash
cd ~/projects/pi-homelab/apps/scraper
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python -m src.scraper
```

## SSH on a new Pi

1. Flash Raspberry Pi OS, enable SSH.
2. Copy your public key: `ssh-copy-id -i ~/.ssh/id_ed25519_raspberry.pub mackewinsson@raspberrypi.local`
3. Add the same `Host pi` block to `~/.ssh/config` on your Mac.
