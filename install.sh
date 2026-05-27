#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="/opt/tools/update-checks"
SCRIPT_NAME="check-updates.sh"
CONFIG_NAME="clients.conf"

echo "Installing cms-update-checker..."

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Please run as root or with sudo:"
  echo "sudo ./install.sh"
  exit 1
fi

mkdir -p "$INSTALL_DIR/logs" "$INSTALL_DIR/reports"

cp "./$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"

if [[ ! -f "$INSTALL_DIR/$CONFIG_NAME" ]]; then
  cp "./config/clients.conf.example" "$INSTALL_DIR/$CONFIG_NAME"
  echo "Created config: $INSTALL_DIR/$CONFIG_NAME"
else
  echo "Config already exists, keeping existing file: $INSTALL_DIR/$CONFIG_NAME"
  cp "./config/clients.conf.example" "$INSTALL_DIR/$CONFIG_NAME.example"
  echo "Installed example config: $INSTALL_DIR/$CONFIG_NAME.example"
fi

chmod 750 "$INSTALL_DIR/$SCRIPT_NAME"
chmod 640 "$INSTALL_DIR/$CONFIG_NAME" || true
chmod 750 "$INSTALL_DIR"

if id docker >/dev/null 2>&1; then
  chown -R docker:docker "$INSTALL_DIR"
  echo "Set ownership to docker:docker"
else
  echo "User 'docker' not found. Keeping current ownership."
fi

echo ""
echo "Install complete."
echo ""
echo "Next steps:"
echo "1. Edit config:"
echo "   sudo nano $INSTALL_DIR/$CONFIG_NAME"
echo ""
echo "2. Run manually:"
echo "   $INSTALL_DIR/$SCRIPT_NAME"
echo ""
echo "3. Add cron:"
echo "   crontab -e"
echo ""
echo "   30 6 * * * $INSTALL_DIR/$SCRIPT_NAME >> $INSTALL_DIR/logs/cron.log 2>&1"
