#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

echo "Starting mock local test containers..."
docker compose up -d --build test-drupal test-wordpress

echo "Running update checker..."
BASE_DIR="$(pwd)" \
CLIENTS_FILE="$(pwd)/config/clients.conf.example" \
REPORT_DIR="$(pwd)/reports" \
LOG_DIR="$(pwd)/logs" \
./check-updates.sh

echo ""
echo "Latest report:"
latest_report="$(find reports -type f -name '*.txt' -print0 | xargs -0 ls -t | head -n 1)"
echo "$latest_report"
echo ""

cat "$latest_report"

echo ""
echo "Mock local test complete."
