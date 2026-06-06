# Cloudflare Tunnel — Audiobookshelf

Expose Audiobookshelf (`http://127.0.0.1:13378`) on the Pi through [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) using the **CLI** (locally-managed tunnel). No port forwarding on your router.

## Prerequisites

- Domain on Cloudflare (DNS managed there)
- Audiobookshelf running: `stacks/audiobookshelf` on port `13378`
- SSH to the Pi as `mackewinsson`

## One-time setup (on the Pi)

```bash
cd ~/projects/pi-homelab/stacks/cloudflared
cp .env.example .env
# Edit .env: set TUNNEL_HOSTNAME=audiobooks.yourdomain.com
chmod +x install.sh
```

### 1. Log in to Cloudflare (browser)

```bash
cloudflared tunnel login
```

Open the URL shown, pick the zone that will host your hostname, and approve. This creates `~/.cloudflared/cert.pem`.

### 2. Run the installer

```bash
./install.sh
```

The script will:

1. Install `cloudflared` if missing
2. `cloudflared tunnel create pi-audiobookshelf` (name from `.env`)
3. Write `~/.cloudflared/config.yml` with ingress to Audiobookshelf
4. `cloudflared tunnel route dns` for your hostname
5. Install and start a **user** systemd unit (`systemctl --user`, survives reboot with `loginctl enable-linger`)

## Manual CLI (equivalent steps)

```bash
cloudflared tunnel login
cloudflared tunnel create pi-audiobookshelf
cloudflared tunnel route dns pi-audiobookshelf audiobooks.yourdomain.com

# Edit ~/.cloudflared/config.yml (see config.yml.example)
cloudflared tunnel run pi-audiobookshelf   # foreground test

# User service (what install.sh does):
systemctl --user enable --now cloudflared
loginctl enable-linger "$USER"
```

## Verify

```bash
curl -sI https://audiobooks.yourdomain.com | head -5
sudo journalctl -u cloudflared -n 50 --no-pager
ssh pi 'docker ps --filter name=audiobookshelf'
```

## Security

A tunnel publishes the service to the internet. Consider [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/policies/access/) (email OTP, Google login, etc.) on the hostname so only you can open the UI.

## Audiobookshelf notes

- Use **HTTPS** at the public URL; Cloudflare terminates TLS.
- WebSockets are proxied automatically (required for playback/UI).
- If you later put ABS behind a subpath, upstream requires `/audiobookshelf` — a tunnel hostname at the root is simpler.

## Troubleshooting

| Issue | Action |
|-------|--------|
| `login` fails | Run on the Pi with a browser on another machine; copy the URL |
| 502 / origin error | `curl -sI http://127.0.0.1:13378` on Pi; restart audiobookshelf stack |
| DNS not resolving | `cloudflared tunnel route dns list`; check hostname zone in dashboard |
| Service won't start | `sudo journalctl -u cloudflared -e`; validate `~/.cloudflared/config.yml` paths |
