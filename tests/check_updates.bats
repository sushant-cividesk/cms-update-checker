#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  cd "$REPO_ROOT"

  rm -rf reports logs
  mkdir -p reports logs

  docker compose up -d --build test-drupal test-wordpress >/dev/null
}

teardown() {
  cd "$REPO_ROOT"
  docker compose down -v >/dev/null
}

@test "script creates a report" {
  run env \
    BASE_DIR="$REPO_ROOT" \
    CLIENTS_FILE="$REPO_ROOT/config/clients.conf.example" \
    REPORT_DIR="$REPO_ROOT/reports" \
    LOG_DIR="$REPO_ROOT/logs" \
    "$REPO_ROOT/check-updates.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Report created:"* ]]

  report_count="$(find "$REPO_ROOT/reports" -type f -name '*.txt' | wc -l | tr -d ' ')"
  [ "$report_count" -eq 1 ]
}

@test "report contains Drupal check output" {
  env \
    BASE_DIR="$REPO_ROOT" \
    CLIENTS_FILE="$REPO_ROOT/config/clients.conf.example" \
    REPORT_DIR="$REPO_ROOT/reports" \
    LOG_DIR="$REPO_ROOT/logs" \
    "$REPO_ROOT/check-updates.sh" >/dev/null

  report="$(find "$REPO_ROOT/reports" -type f -name '*.txt' -print0 | xargs -0 ls -t | head -n 1)"

  grep -q "TEST-DRUPAL \\[local\\] - Drupal" "$report"
  grep -q "Drupal version   : 10.6.8" "$report"
  grep -q "drupal/core-recommended       10.6.8" "$report"
  grep -q "Upgrading drupal/core (10.6.8 => 10.6.9)" "$report"
}

@test "report contains WordPress check output" {
  env \
    BASE_DIR="$REPO_ROOT" \
    CLIENTS_FILE="$REPO_ROOT/config/clients.conf.example" \
    REPORT_DIR="$REPO_ROOT/reports" \
    LOG_DIR="$REPO_ROOT/logs" \
    "$REPO_ROOT/check-updates.sh" >/dev/null

  report="$(find "$REPO_ROOT/reports" -type f -name '*.txt' -print0 | xargs -0 ls -t | head -n 1)"

  grep -q "TEST-WP \\[local\\] - WordPress" "$report"
  grep -q "6.5.5" "$report"
  grep -q "6.5.6" "$report"
  grep -q "contact-form" "$report"
}

@test "missing container is reported as skipped" {
  env \
    BASE_DIR="$REPO_ROOT" \
    CLIENTS_FILE="$REPO_ROOT/config/clients.conf.example" \
    REPORT_DIR="$REPO_ROOT/reports" \
    LOG_DIR="$REPO_ROOT/logs" \
    "$REPO_ROOT/check-updates.sh" >/dev/null

  report="$(find "$REPO_ROOT/reports" -type f -name '*.txt' -print0 | xargs -0 ls -t | head -n 1)"

  grep -q "MISSING-DRUPAL \\[local\\] - Drupal" "$report"
  grep -q "STATUS: SKIPPED" "$report"
  grep -q "missing-drupal-container" "$report"
}

@test "script fails when config file is missing" {
  run env \
    BASE_DIR="$REPO_ROOT" \
    CLIENTS_FILE="$REPO_ROOT/config/does-not-exist.conf" \
    REPORT_DIR="$REPO_ROOT/reports" \
    LOG_DIR="$REPO_ROOT/logs" \
    "$REPO_ROOT/check-updates.sh"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing config file:"* ]]
}
