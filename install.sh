#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="/opt/tools/update-checks"
SCRIPT_NAME="check-updates.sh"
CONFIG_NAME="clients.conf"
SETTINGS_NAME="settings.env"
CRON_FILE="/etc/cron.d/cms-update-checker"

RAW_BASE_URL="${RAW_BASE_URL:-https://raw.githubusercontent.com/sushant-cividesk/cms-update-checker/main}"

echo "Installing cms-update-checker..."

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Please run as root or with sudo."
  exit 1
fi

mkdir -p "$INSTALL_DIR/logs" "$INSTALL_DIR/reports"

if [[ -f "./$SCRIPT_NAME" ]]; then
  cp "./$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
else
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to download $SCRIPT_NAME."
    exit 1
  fi

  curl -fsSL "$RAW_BASE_URL/$SCRIPT_NAME" -o "$INSTALL_DIR/$SCRIPT_NAME"
fi

chmod 750 "$INSTALL_DIR/$SCRIPT_NAME"

if [[ ! -f "$INSTALL_DIR/$CONFIG_NAME" ]]; then
  cat > "$INSTALL_DIR/$CONFIG_NAME" <<'CONFIG'
# cms-update-checker client config
#
# Format:
# client|type|env|app_path|container|url
#
# type must be drupal or wordpress
#
# Examples:
# WFSB|drupal|prod|/home/docker/apps/wfsb|wfsb-prod|https://womensfundsb.org
# EXAMPLEWP|wordpress|prod|/home/docker/apps/examplewp|examplewp-prod|https://example.org
CONFIG
  echo "Created config: $INSTALL_DIR/$CONFIG_NAME"
else
  echo "Config already exists, keeping: $INSTALL_DIR/$CONFIG_NAME"
fi

if [[ ! -f "$INSTALL_DIR/$SETTINGS_NAME" ]]; then
  cat > "$INSTALL_DIR/$SETTINGS_NAME" <<'ENV'
# cms-update-checker mail settings
#
# Real server SMTP details should be provided by the server/admin team.
# For local and GitHub Actions testing, Mailpit is used.

MAIL_TO=""
MAIL_FROM="cms-update-checker@example.org"

SMTP_HOST=""
SMTP_PORT="25"
SMTP_USER=""
SMTP_PASSWORD=""
SMTP_TLS="0"
ENV
  echo "Created mail settings: $INSTALL_DIR/$SETTINGS_NAME"
else
  echo "Mail settings already exist, keeping: $INSTALL_DIR/$SETTINGS_NAME"
fi

chmod 640 "$INSTALL_DIR/$CONFIG_NAME" "$INSTALL_DIR/$SETTINGS_NAME"
chmod 750 "$INSTALL_DIR"

if id docker >/dev/null 2>&1; then
  chown -R docker:docker "$INSTALL_DIR"
else
  chown -R root:root "$INSTALL_DIR"
fi

cat > "$CRON_FILE" <<EOF_CRON
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Run cms-update-checker daily at 6:30 AM.
30 6 * * * root set -a; source $INSTALL_DIR/$SETTINGS_NAME; set +a; $INSTALL_DIR/$SCRIPT_NAME >> $INSTALL_DIR/logs/cron.log 2>&1
EOF_CRON

chmod 644 "$CRON_FILE"

echo ""
echo "Install complete."
echo ""
echo "Installed path:"
echo "  $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "  1. Edit clients:"
echo "     sudo nano $INSTALL_DIR/$CONFIG_NAME"
echo ""
echo "  2. Edit mail settings:"
echo "     sudo nano $INSTALL_DIR/$SETTINGS_NAME"
echo ""
echo "  3. Run manually:"
echo "     sudo bash -lc 'set -a; source $INSTALL_DIR/$SETTINGS_NAME; set +a; $INSTALL_DIR/$SCRIPT_NAME'"
echo ""
echo "  4. Cron installed:"
echo "     $CRON_FILE"
