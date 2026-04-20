#!/usr/bin/env bash

set -e

########################################
# CONFIG
########################################
PANEL_PORT="12453"
PANEL_USERNAME="adminner"
PANEL_PASSWORD="09768"

XUI_VERSION="${1:-latest}"

########################################
# COLORS
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
# ROOT CHECK
########################################
if [[ $EUID -ne 0 ]]; then
  err "Run as root"
  exit 1
fi

########################################
# INSTALL DEPENDENCIES
########################################
log "Installing dependencies..."

if command -v apt >/dev/null 2>&1; then
  apt update -y
  apt install -y curl wget tar
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y curl wget tar
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl wget tar
else
  err "Unsupported OS"
  exit 1
fi

########################################
# ARCH DETECT
########################################
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  armv7l) ARCH="armv7" ;;
  *)
    err "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

########################################
# INSTALL
########################################
if [[ "$XUI_VERSION" == "latest" ]]; then
  log "Installing latest x-ui..."
  bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/main/install.sh)
else
  log "Downloading x-ui v${XUI_VERSION}..."

  DOWNLOAD_URL="https://github.com/alireza0/x-ui/releases/download/${XUI_VERSION}/x-ui-linux-${ARCH}.tar.gz"

  if ! wget -O /tmp/x-ui.tar.gz "${DOWNLOAD_URL}"; then
    DOWNLOAD_URL="https://github.com/alireza0/x-ui/releases/download/v${XUI_VERSION}/x-ui-linux-${ARCH}.tar.gz"
    wget -O /tmp/x-ui.tar.gz "${DOWNLOAD_URL}"
  fi

  log "Installing files..."

  systemctl stop x-ui 2>/dev/null || true

  rm -rf /usr/local/x-ui
  mkdir -p /usr/local/x-ui

  tar -xzf /tmp/x-ui.tar.gz -C /usr/local/x-ui --strip-components=1
  chmod +x /usr/local/x-ui/x-ui

  ########################################
  # FIX SERVICE (IMPORTANT)
  ########################################
  cat >/etc/systemd/system/x-ui.service <<'EOF'
[Unit]
Description=x-ui Service
After=network.target
Wants=network.target

[Service]
Environment="XRAY_VMESS_AEAD_FORCED=false"
Type=simple
WorkingDirectory=/usr/local/x-ui/
ExecStart=/usr/local/x-ui/x-ui
ExecReload=kill -USR1 $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable x-ui
fi

########################################
# APPLY SETTINGS
########################################
log "Applying settings..."

if [[ -x /usr/local/x-ui/x-ui ]]; then
  /usr/local/x-ui/x-ui setting -username "${PANEL_USERNAME}" -password "${PANEL_PASSWORD}" -port "${PANEL_PORT}" || true
elif command -v x-ui >/dev/null 2>&1; then
  x-ui setting -username "${PANEL_USERNAME}" -password "${PANEL_PASSWORD}" -port "${PANEL_PORT}" || true
fi

########################################
# START SERVICE
########################################
log "Starting service..."

systemctl restart x-ui

########################################
# DONE
########################################
log "Done ✅"
echo "=============================="
echo "Version    : ${XUI_VERSION}"
echo "Panel Port : ${PANEL_PORT}"
echo "Username   : ${PANEL_USERNAME}"
echo "Password   : ${PANEL_PASSWORD}"
echo "=============================="
