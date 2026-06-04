# Backup (not in Git)

These paths live on the Pi and are **ignored by Git** on purpose. Copy them elsewhere regularly (USB, NAS, `rsync` to your Mac).

| Path on Pi | Contents |
|------------|----------|
| `~/projects/audiobookshelf/config/` | SQLite DB, server settings |
| `~/projects/audiobookshelf/metadata/` | Covers, backups |
| `~/projects/audiobookshelf/audiobooks/` | Your audiobook files |
| `~/projects/audiobookshelf/podcasts/` | Podcast files |

## Example: backup to Mac

```bash
rsync -avz --progress pi:~/projects/audiobookshelf/config/ ~/Backups/pi/audiobookshelf/config/
rsync -avz --progress pi:~/projects/audiobookshelf/metadata/ ~/Backups/pi/audiobookshelf/metadata/
# Large media — adjust paths as needed:
# rsync -avz --progress pi:~/projects/audiobookshelf/audiobooks/ ~/Backups/pi/audiobookshelf/audiobooks/
```

## Restore config after fresh install

```bash
ssh pi
mkdir -p ~/projects/audiobookshelf
# From Mac:
rsync -avz ~/Backups/pi/audiobookshelf/config/ pi:~/projects/audiobookshelf/config/
cd ~/projects/audiobookshelf && docker compose up -d
```
