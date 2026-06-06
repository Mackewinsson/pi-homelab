#!/bin/bash
# Cloudflare Tunnel (cloudflared) for exposing Audiobookshelf on the Pi.
# Run on the Pi after: cp .env.example .env && edit TUNNEL_HOSTNAME
set -euo pipefail
cd "$(dirname "$0")"

if [[ -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

TUNNEL_NAME="${TUNNEL_NAME:-pi-audiobookshelf}"
TUNNEL_HOSTNAME="${TUNNEL_HOSTNAME:-}"
LOCAL_SERVICE_URL="${LOCAL_SERVICE_URL:-http://127.0.0.1:13378}"
CLOUDFLARED_DIR="${HOME}/.cloudflared"
CONFIG_PATH="${CLOUDFLARED_DIR}/config.yml"
LOCAL_BIN="${HOME}/.local/bin"
LOCAL_CLOUDFLARED="${LOCAL_BIN}/cloudflared"

cloudflared_cmd() {
  if command -v cloudflared &>/dev/null; then
    command cloudflared "$@"
  elif [[ -x "${LOCAL_CLOUDFLARED}" ]]; then
    "${LOCAL_CLOUDFLARED}" "$@"
  else
    echo "cloudflared not found" >&2
    return 127
  fi
}

install_cloudflared() {
  if command -v cloudflared &>/dev/null; then
    echo "==> cloudflared already installed: $(cloudflared --version)"
    return
  fi
  if [[ -x "${LOCAL_CLOUDFLARED}" ]]; then
    echo "==> cloudflared (user): $("${LOCAL_CLOUDFLARED}" --version)"
    export PATH="${LOCAL_BIN}:${PATH}"
    return
  fi

  echo "==> Installing cloudflared binary to ${LOCAL_BIN} (no sudo)..."
  arch="$(uname -m)"
  case "${arch}" in
    aarch64|arm64) bin="cloudflared-linux-arm64" ;;
    armv7l|armv6l) bin="cloudflared-linux-arm" ;;
    x86_64|amd64) bin="cloudflared-linux-amd64" ;;
    *)
      echo "Unsupported architecture: ${arch}" >&2
      exit 1
      ;;
  esac

  mkdir -p "${LOCAL_BIN}"
  curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/${bin}" -o "${LOCAL_CLOUDFLARED}"
  chmod +x "${LOCAL_CLOUDFLARED}"
  export PATH="${LOCAL_BIN}:${PATH}"
  cloudflared_cmd --version
  if ! grep -qF '.local/bin' "${HOME}/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${HOME}/.bashrc"
    echo "==> Added ~/.local/bin to PATH in ~/.bashrc"
  fi
}

ensure_logged_in() {
  if [[ -f "${CLOUDFLARED_DIR}/cert.pem" ]]; then
    echo "==> Cloudflare login cert found at ${CLOUDFLARED_DIR}/cert.pem"
    return
  fi
  echo ""
  echo "Not logged in to Cloudflare yet. On the Pi, run:"
  echo "  cloudflared tunnel login"
  echo "That opens a browser URL — complete login for the zone that will host ${TUNNEL_HOSTNAME:-your hostname}."
  echo "Then re-run: ./install.sh"
  exit 1
}

create_tunnel_if_missing() {
  mkdir -p "${CLOUDFLARED_DIR}"
  if cloudflared_cmd tunnel list 2>/dev/null | grep -q "${TUNNEL_NAME}"; then
    echo "==> Tunnel already exists: ${TUNNEL_NAME}"
    return
  fi
  echo "==> Creating tunnel: ${TUNNEL_NAME}"
  cloudflared_cmd tunnel create "${TUNNEL_NAME}"
}

write_config() {
  local tunnel_id cred_file
  tunnel_id="$(cloudflared_cmd tunnel list -o json 2>/dev/null | python3 -c "
import json, sys
name = sys.argv[1]
for t in json.load(sys.stdin):
    if t.get('name') == name:
        print(t['id'])
        break
" "${TUNNEL_NAME}" 2>/dev/null || true)"

  if [[ -z "${tunnel_id}" ]]; then
    tunnel_id="$(cloudflared_cmd tunnel info "${TUNNEL_NAME}" 2>/dev/null | awk '/uuid:/ {print $2; exit}')"
  fi

  cred_file="${CLOUDFLARED_DIR}/${tunnel_id}.json"
  if [[ ! -f "${cred_file}" ]]; then
    # Fallback: single *.json in .cloudflared besides cert
    cred_file="$(find "${CLOUDFLARED_DIR}" -maxdepth 1 -name '*.json' ! -name '*.json.bak' | head -1)"
  fi

  if [[ -z "${tunnel_id}" || ! -f "${cred_file}" ]]; then
    echo "Could not resolve tunnel UUID/credentials for ${TUNNEL_NAME}" >&2
    exit 1
  fi

  if [[ -z "${TUNNEL_HOSTNAME}" ]]; then
    echo "Set TUNNEL_HOSTNAME in .env (e.g. audiobooks.yourdomain.com) then re-run ./install.sh" >&2
    exit 1
  fi

  echo "==> Writing ${CONFIG_PATH}"
  cat > "${CONFIG_PATH}" <<EOF
tunnel: ${tunnel_id}
credentials-file: ${cred_file}

ingress:
  - hostname: ${TUNNEL_HOSTNAME}
    service: ${LOCAL_SERVICE_URL}
    originRequest:
      httpHostHeader: ${TUNNEL_HOSTNAME}
  - service: http_status:404
EOF
}

route_dns() {
  echo "==> Routing DNS: ${TUNNEL_HOSTNAME} -> tunnel ${TUNNEL_NAME}"
  cloudflared_cmd tunnel route dns "${TUNNEL_NAME}" "${TUNNEL_HOSTNAME}" || true
}

install_systemd() {
  local unit_dir="${HOME}/.config/systemd/user"
  local unit_file="${unit_dir}/cloudflared.service"
  local cf_bin
  cf_bin="$(command -v cloudflared 2>/dev/null || true)"
  [[ -z "${cf_bin}" && -x "${LOCAL_CLOUDFLARED}" ]] && cf_bin="${LOCAL_CLOUDFLARED}"
  mkdir -p "${unit_dir}"

  echo "==> Installing user systemd unit: ${unit_file}"
  cat > "${unit_file}" <<EOF
[Unit]
Description=Cloudflare Tunnel (${TUNNEL_NAME})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${cf_bin} --config ${CONFIG_PATH} tunnel run ${TUNNEL_NAME}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable cloudflared
  systemctl --user restart cloudflared
  loginctl enable-linger "${USER}" 2>/dev/null || true
  systemctl --user --no-pager status cloudflared
}

install_cloudflared
ensure_logged_in
create_tunnel_if_missing
write_config
route_dns
install_systemd

echo ""
echo "Tunnel ready. Audiobookshelf should be reachable at:"
echo "  https://${TUNNEL_HOSTNAME}"
echo ""
echo "Check: curl -sI https://${TUNNEL_HOSTNAME} | head -5"
echo "Logs:  sudo journalctl -u cloudflared -f"
