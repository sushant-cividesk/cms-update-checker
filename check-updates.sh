#!/usr/bin/env bash

set -u
set -o pipefail

BASE_DIR="${BASE_DIR:-/opt/tools/update-checks}"
CLIENTS_FILE="${CLIENTS_FILE:-$BASE_DIR/clients.conf}"
REPORT_DIR="${REPORT_DIR:-$BASE_DIR/reports}"
LOG_DIR="${LOG_DIR:-$BASE_DIR/logs}"

MAIL_TO="${MAIL_TO:-}"
MAIL_FROM="${MAIL_FROM:-cms-update-checker@example.org}"
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
    echo "===================================="
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
    run_in_container "$container" "cd /var/www/html && COMPOSER_CACHE_DIR=/tmp/composer-cache composer show 'drupal/core-*'"

    echo ""
    echo "Drush status:"
    echo "-------------"
    run_in_container "$container" "cd /var/www/html && (vendor/bin/drush status || drush status)"

    echo ""
    echo "Composer dry-run for Drupal core:"
    echo "---------------------------------"
    run_in_container "$container" "cd /var/www/html && COMPOSER_CACHE_DIR=/tmp/composer-cache composer update 'drupal/core-*' --with-all-dependencies --dry-run"

    echo ""
    echo "Pending DB updates:"
    echo "-------------------"
    run_in_container "$container" "cd /var/www/html && (vendor/bin/drush updatedb:status || drush updatedb:status || true)"

    echo ""
    echo "Composer audit summary:"
    echo "-----------------------"
    run_in_container "$container" "cd /var/www/html && COMPOSER_CACHE_DIR=/tmp/composer-cache composer audit || true"
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

  if ! command -v curl >/dev/null 2>&1; then
    echo "Email not sent: curl is not available." >> "$REPORT_FILE"
    return
  fi

  local email_file
  email_file="$(mktemp)"

  {
    echo "From: $MAIL_FROM"
    echo "To: $MAIL_TO"
    echo "Subject: $MAIL_SUBJECT"
    echo "Date: $(date -R)"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo ""
    cat "$REPORT_FILE"
  } > "$email_file"

  local smtp_url
  smtp_url="smtp://$SMTP_HOST:$SMTP_PORT"

  local curl_args
  curl_args=(
    --silent
    --show-error
    --url "$smtp_url"
    --mail-from "$MAIL_FROM"
    --mail-rcpt "$MAIL_TO"
    --upload-file "$email_file"
  )

  if [[ "$SMTP_TLS" == "1" ]]; then
    curl_args+=(--ssl-reqd)
  fi

  if [[ -n "$SMTP_USER" ]]; then
    curl_args+=(--user "$SMTP_USER:$SMTP_PASSWORD")
  fi

  if curl "${curl_args[@]}"; then
    echo "Email sent to $MAIL_TO via $SMTP_HOST:$SMTP_PORT" >> "$REPORT_FILE"
  else
    echo "Email failed to send to $MAIL_TO via $SMTP_HOST:$SMTP_PORT" >> "$REPORT_FILE"
  fi

  rm -f "$email_file"
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
