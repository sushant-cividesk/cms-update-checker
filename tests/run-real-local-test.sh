#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

wait_for_command() {
  local name="$1"
  local command="$2"
  local max_attempts="${3:-60}"
  local sleep_seconds="${4:-5}"

  echo "Waiting for $name..."

  for attempt in $(seq 1 "$max_attempts"); do
    if bash -lc "$command" >/dev/null 2>&1; then
      echo "$name is ready."
      return 0
    fi

    echo "Still waiting for $name... attempt $attempt/$max_attempts"
    sleep "$sleep_seconds"
  done

  echo "ERROR: $name did not become ready in time."

  echo ""
  echo "Debug logs for real-drupal:"
  docker logs real-drupal --tail=160 || true

  echo ""
  echo "Debug logs for real-wordpress:"
  docker logs real-wordpress --tail=160 || true

  echo ""
  echo "Current containers:"
  docker ps -a

  return 1
}

mailpit_count() {
  curl -fsS http://localhost:8025/api/v1/messages \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("total", 0))'
}

wait_for_mail_count() {
  local expected="$1"
  local max_attempts="${2:-30}"

  echo "Waiting for Mailpit message count >= $expected..."

  for attempt in $(seq 1 "$max_attempts"); do
    count="$(mailpit_count || echo 0)"

    if [[ "$count" -ge "$expected" ]]; then
      echo "Mailpit has $count messages."
      return 0
    fi

    echo "Mailpit has $count messages; waiting... attempt $attempt/$max_attempts"
    sleep 2
  done

  echo "ERROR: Mailpit did not receive expected messages."
  curl -fsS http://localhost:8025/api/v1/messages || true
  return 1
}

echo "Starting real local Drupal, WordPress, DB, and Mailpit containers..."
docker compose up -d --build real-drupal real-wordpress mailpit

wait_for_command \
  "Drupal bootstrap" \
  "docker exec real-drupal bash -lc 'cd /var/www/html && vendor/bin/drush status | grep -q \"Drupal bootstrap : Successful\"'"

wait_for_command \
  "WordPress install" \
  "docker exec real-wordpress bash -lc 'cd /var/www/html && wp core is-installed --allow-root'"

wait_for_command \
  "Mailpit API" \
  "curl -fsS http://localhost:8025/api/v1/messages"

wait_for_command \
  "Drupal HTTP" \
  "curl -fsS -o /dev/null -w '%{http_code}' http://localhost:8081 | grep -Eq '^(200|301|302)$'"

wait_for_command \
  "WordPress HTTP" \
  "curl -fsS -o /dev/null -w '%{http_code}' http://localhost:8082 | grep -Eq '^(200|301|302)$'"

echo "Running update checker against real local CMS containers and sending report to Mailpit..."

BASE_DIR="$(pwd)" \
CLIENTS_FILE="$(pwd)/config/clients.real-local.conf" \
REPORT_DIR="$(pwd)/reports" \
LOG_DIR="$(pwd)/logs" \
MAIL_TO="ops@example.local" \
MAIL_FROM="cms-update-checker@example.local" \
SMTP_HOST="localhost" \
SMTP_PORT="1025" \
SMTP_TLS="0" \
./check-updates.sh

wait_for_mail_count 1

echo ""
echo "Latest report:"
latest_report="$(find reports -type f -name '*.txt' -print0 | xargs -0 ls -t | head -n 1)"
echo "$latest_report"
echo ""
cat "$latest_report"

echo ""
echo "Testing CMS container email delivery to Mailpit..."

docker exec real-drupal bash -lc 'echo "Drupal test mail" | mail -s "Drupal Mailpit Test" test@example.local'
docker exec real-wordpress bash -lc 'echo "WordPress test mail" | mail -s "WordPress Mailpit Test" test@example.local'

wait_for_mail_count 3

echo ""
echo "Real local test complete."
echo ""
echo "Open local Drupal:    http://localhost:8081"
echo "Open local WordPress: http://localhost:8082"
echo "Open Mailpit:         http://localhost:8025"
