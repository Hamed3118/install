#!/usr/bin/env bash

set -e

########################################
# Config
########################################
PANEL_PORT="12453"
PANEL_USERNAME="adminner"
PANEL_PASSWORD="09768"
XUI_VERSION="1.8.9"

########################################
# Colors
########################################
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

err() {
  echo -e "${RED}[ERROR]${NC} $1"
}

########################################
# Root check
########################################
if [[ $EUID -ne 0 ]]; then
  err "Run as root"
  exit 1
fi

########################################
# Install dependencies
########################################
log "Installing dependencies..."

if command -v apt >/dev/null 2>&1; then
  apt update -y
  apt install -y curl wget tar
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl wget tar
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y curl wget tar
else
  err "Unsupported OS"
  exit 1
fi

########################################
# Detect architecture
########################################
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *) err "Unsupported architecture: $ARCH" ;;
esac

########################################
# Download specific version
########################################
log "Downloading x-ui v${XUI_VERSION}..."

DOWNLOAD_URL="https://github.com/alireza0/x-ui/releases/download/v${XUI_VERSION}/x-ui-linux-${ARCH}.tar.gz"

wget -O x-ui.tar.gz "${DOWNLOAD_URL}"

########################################
# Install
########################################
log "Installing..."

systemctl stop x-ui 2>/dev/null || true

rm -rf /usr/local/x-ui
mkdir -p /usr/local/x-ui

tar -xzf x-ui.tar.gz -C /usr/local/x-ui --strip-components=1

chmod +x /usr/local/x-ui/x-ui

########################################
# Create service
########################################
cat >/etc/systemd/system/x-ui.service <<EOF
[Unit]
Description=x-ui Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/x-ui/x-ui
Restart=always

[Install]
WantedBy=multi-user.target
EOF

########################################
# Apply settings
########################################
log "Applying settings..."

/usr/local/x-ui/x-ui setting -username "${PANEL_USERNAME}" -password "${PANEL_PASSWORD}" -port "${PANEL_PORT}" || true

########################################
# Start service
########################################
log "Starting service..."

systemctl daemon-reload
systemctl enable x-ui
systemctl restart x-ui

########################################
# Done
########################################
log "Done ✅"
echo "=============================="
echo "Version    : ${XUI_VERSION}"
echo "Panel Port : ${PANEL_PORT}"
echo "Username   : ${PANEL_USERNAME}"
echo "Password   : ${PANEL_PASSWORD}"
echo "=============================="