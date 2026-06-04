#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Instalando Docker (si no está instalado)..."
if ! command -v docker &>/dev/null; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "Docker instalado. Si es la primera vez, cierra sesión SSH y vuelve a entrar para usar docker sin sudo."
fi

echo "==> Instalando plugin Docker Compose..."
if ! docker compose version &>/dev/null 2>&1; then
  sudo apt-get install -y docker-compose-plugin 2>/dev/null || true
fi

run_docker() {
  if docker info &>/dev/null; then
    docker "$@"
  else
    sudo docker "$@"
  fi
}

echo "==> Descargando imagen Audiobookshelf (arm64)..."
run_docker compose pull

echo "==> Iniciando Audiobookshelf..."
run_docker compose up -d

echo ""
echo "Listo. Audiobookshelf en: http://$(hostname -I | awk '{print $1}'):${ABS_PORT:-13378}"
echo "También: http://raspberrypi.local:${ABS_PORT:-13378}"
run_docker compose ps
