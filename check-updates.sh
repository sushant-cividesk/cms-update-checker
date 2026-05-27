#!/usr/bin/env bash

set -u
set -o pipefail

BASE_DIR="${BASE_DIR:-/opt/tools/update-checks}"
CLIENTS_FILE="${CLIENTS_FILE:-$BASE_DIR/clients.conf}"
REPORT_DIR="${REPORT_DIR:-$BASE_DIR/reports}"
LOG_DIR="${LOG_DIR:-$BASE_DIR/logs}"

MAIL_TO="${MAIL_TO:-}"
MAIL_FROM="${MAIL_FROM:-cms-update-checker@example.local}"
SMTP_HOST="${SMTP_HOST:-}"
SMTP_PORT="${SMTP_PORT:-25}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
SMTP_TLS="${SMTP_TLS:-0}"

DATE="$(date '+%Y-%m-%d %H:%M:%S %Z')"
DATE_FILE="$(date '+%Y-%m-%d_%H-%M-%S')"
HOST="$(hostname)"
REPORT_FILE="$REPORT_DIR/update-check-$HOST-$DATE_FILE.txt"
MAIL_SUBJECT="[Update Check] $HOST Drupal/WordPress report - $DATE"

mkdir -p "$REPORT_DIR" "$LOG_DIR"

run_in_container() {
  local container="$1"
  local command="$2"

  docker exec -u www-data "$container" bash -lc "$command" 2>&1
}

container_exists() {
  local container="$1"

  docker ps --format '{{.Names}}' | grep -qx "$container"
}

write_header() {
  {
    echo "Drupal/WordPress Update Check Report"
    echo "================================================"
    echo "Host: $HOST"
    echo "Date: $DATE"
    echo "Mode: CHECK ONLY / DRY RUN"
    echo ""
  } > "$REPORT_FILE"
}

check_drupal() {
  local client="$1"
  local env="$2"
  local app_path="$3"
  local container="$4"
  local url="$5"

  {
    echo ""
    echo "------------------------------------------------"
    echo "$client [$env] - Drupal"
    echo "URL: $url"
    echo "Container: $container"
    echo "App path: $app_path"
    echo "------------------------------------------------"
  } >> "$REPORT_FILE"

  if ! container_exists "$container"; then
    {
      echo "STATUS: SKIPPED"
      echo "Reason: Container is not running or not found: $container"
      echo "Suggested action: cd $app_path && make ENV=$env rebuild"
    } >> "$REPORT_FILE"
    return
  fi

  {
    echo ""
    echo "Current Drupal/core packages:"
    echo "-----------------------------"
    run_in_container "$container" "cd /var/www/html && composer show 'drupal/core-*'"

    echo ""
    echo "Drush status:"
    echo "-------------"
    run_in_container "$container" "cd /var/www/html && (vendor/bin/drush status || drush status)"

    echo ""
    echo "Composer dry-run for Drupal core:"
    echo "---------------------------------"
    run_in_container "$container" "cd /var/www/html && composer update 'drupal/core-*' --with-all-dependencies --dry-run"

    echo ""
    echo "Pending DB updates:"
    echo "-------------------"
    run_in_container "$container" "cd /var/www/html && (vendor/bin/drush updatedb:status || drush updatedb:status || true)"

    echo ""
    echo "Composer audit summary:"
    echo "-----------------------"
    run_in_container "$container" "cd /var/www/html && composer audit || true"
  } >> "$REPORT_FILE"
}

check_wordpress() {
  local client="$1"
  local env="$2"
  local app_path="$3"
  local container="$4"
  local url="$5"

  {
    echo ""
    echo "------------------------------------------------"
    echo "$client [$env] - WordPress"
    echo "URL: $url"
    echo "Container: $container"
    echo "App path: $app_path"
    echo "------------------------------------------------"
  } >> "$REPORT_FILE"

  if ! container_exists "$container"; then
    {
      echo "STATUS: SKIPPED"
      echo "Reason: Container is not running or not found: $container"
      echo "Suggested action: cd $app_path && make ENV=$env rebuild"
    } >> "$REPORT_FILE"
    return
  fi

  {
    echo ""
    echo "Current WordPress version:"
    echo "--------------------------"
    run_in_container "$container" "cd /var/www/html && (wp core version --allow-root || wp core version)"

    echo ""
    echo "WordPress core update check:"
    echo "----------------------------"
    run_in_container "$container" "cd /var/www/html && (wp core check-update --allow-root || wp core check-update || true)"

    echo ""
    echo "Plugin update check:"
    echo "--------------------"
    run_in_container "$container" "cd /var/www/html && (wp plugin list --update=available --allow-root || wp plugin list --update=available || true)"

    echo ""
    echo "Theme update check:"
    echo "-------------------"
    run_in_container "$container" "cd /var/www/html && (wp theme list --update=available --allow-root || wp theme list --update=available || true)"
  } >> "$REPORT_FILE"
}

send_report() {
  if [[ -z "$MAIL_TO" ]]; then
    echo "Email not sent: MAIL_TO is empty." >> "$REPORT_FILE"
    return
  fi

  if [[ -z "$SMTP_HOST" ]]; then
    echo "Email not sent: SMTP_HOST is empty." >> "$REPORT_FILE"
    return
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "Email not sent: python3 is not available." >> "$REPORT_FILE"
    return
  fi

  MAIL_TO="$MAIL_TO" \
  MAIL_FROM="$MAIL_FROM" \
  MAIL_SUBJECT="$MAIL_SUBJECT" \
  SMTP_HOST="$SMTP_HOST" \
  SMTP_PORT="$SMTP_PORT" \
  SMTP_USER="$SMTP_USER" \
  SMTP_PASSWORD="$SMTP_PASSWORD" \
  SMTP_TLS="$SMTP_TLS" \
  REPORT_FILE="$REPORT_FILE" \
  python3 - <<'PY'
import os
import smtplib
from email.message import EmailMessage

mail_to = os.environ["MAIL_TO"]
mail_from = os.environ["MAIL_FROM"]
subject = os.environ["MAIL_SUBJECT"]
smtp_host = os.environ["SMTP_HOST"]
smtp_port = int(os.environ["SMTP_PORT"])
smtp_user = os.environ.get("SMTP_USER", "")
smtp_password = os.environ.get("SMTP_PASSWORD", "")
smtp_tls = os.environ.get("SMTP_TLS", "0") == "1"
report_file = os.environ["REPORT_FILE"]

with open(report_file, "r", encoding="utf-8") as handle:
    body = handle.read()

msg = EmailMessage()
msg["From"] = mail_from
msg["To"] = mail_to
msg["Subject"] = subject
msg.set_content(body)

with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as smtp:
    if smtp_tls:
        smtp.starttls()
    if smtp_user:
        smtp.login(smtp_user, smtp_password)
    smtp.send_message(msg)
PY

  echo "Email sent to $MAIL_TO via $SMTP_HOST:$SMTP_PORT" >> "$REPORT_FILE"
}

if [[ ! -f "$CLIENTS_FILE" ]]; then
  echo "Missing config file: $CLIENTS_FILE"
  exit 1
fi

write_header

while IFS='|' read -r client type env app_path container url; do
  [[ -z "${client:-}" ]] && continue
  [[ "$client" =~ ^# ]] && continue

  case "$type" in
    drupal)
      check_drupal "$client" "$env" "$app_path" "$container" "$url"
      ;;
    wordpress)
      check_wordpress "$client" "$env" "$app_path" "$container" "$url"
      ;;
    *)
      echo "Unknown type for $client: $type" >> "$REPORT_FILE"
      ;;
  esac
done < "$CLIENTS_FILE"

send_report

echo "Report created: $REPORT_FILE"
