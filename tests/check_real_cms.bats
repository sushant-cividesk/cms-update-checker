#!/usr/bin/env bats

setup_file() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  cd "$REPO_ROOT"

  rm -rf reports-real logs-real
  mkdir -p reports-real logs-real

  docker compose -f docker-compose.real.yml up -d --build

  for i in $(seq 1 90); do
    drupal_ready=0
    wordpress_ready=0

    if docker exec -u www-data real-drupal bash -lc 'cd /var/www/html && drush status 2>/dev/null | grep -q "Drupal bootstrap.*Successful"'; then
      drupal_ready=1
    fi

    if docker exec real-wordpress bash -lc 'wp core is-installed --allow-root --path=/var/www/html >/dev/null 2>&1'; then
      wordpress_ready=1
    fi

    if [[ "$drupal_ready" -eq 1 && "$wordpress_ready" -eq 1 ]]; then
      return 0
    fi

    sleep 3
  done

  docker logs real-drupal || true
  docker logs real-wordpress || true
  docker logs real-drupal-db || true
  docker logs real-wordpress-db || true
  return 1
}

teardown_file() {
  cd "$REPO_ROOT"
  docker compose -f docker-compose.real.yml down -v >/dev/null
}

@test "real CMS checker creates a report and sends SMTP email" {
  run env \
    BASE_DIR="$REPO_ROOT" \
    CLIENTS_FILE="$REPO_ROOT/config/clients.real.conf" \
    REPORT_DIR="$REPO_ROOT/reports-real" \
    LOG_DIR="$REPO_ROOT/logs-real" \
    MAIL_TO="sushant@local.test" \
    MAIL_FROM="update-checker@local.test" \
    SMTP_HOST="127.0.0.1" \
    SMTP_PORT="1025" \
    "$REPO_ROOT/check-updates.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Report created:"* ]]
}

@test "real report contains Drupal and WordPress sections" {
  report="$(find "$REPO_ROOT/reports-real" -type f -name '*.txt' -print0 | xargs -0 ls -t | head -n 1)"

  grep -q "REAL-DRUPAL \\[local\\] - Drupal" "$report"
  grep -q "REAL-WORDPRESS \\[local\\] - WordPress" "$report"
}

@test "real report includes Drupal status and WordPress version" {
  report="$(find "$REPO_ROOT/reports-real" -type f -name '*.txt' -print0 | xargs -0 ls -t | head -n 1)"

  grep -q "Drupal version" "$report"
  grep -q "Drupal bootstrap" "$report"
  grep -q "Current WordPress version" "$report"
}

@test "real report includes SMTP sent marker" {
  report="$(find "$REPO_ROOT/reports-real" -type f -name '*.txt' -print0 | xargs -0 ls -t | head -n 1)"

  grep -q "Email sent via SMTP" "$report"
}
