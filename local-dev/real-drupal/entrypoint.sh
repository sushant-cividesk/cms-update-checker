#!/usr/bin/env bash

set -euo pipefail

DB_HOST="${DRUPAL_DB_HOST:-real-drupal-db}"
DB_PORT="${DRUPAL_DB_PORT:-3306}"
DB_NAME="${DRUPAL_DB_NAME:-drupal}"
DB_USER="${DRUPAL_DB_USER:-drupal}"
DB_PASSWORD="${DRUPAL_DB_PASSWORD:-drupal}"
SMTP_HOST="${SMTP_HOST:-mailpit}"
SMTP_PORT="${SMTP_PORT:-1025}"

echo "Waiting for Drupal DB at ${DB_HOST}:${DB_PORT}..."

for attempt in $(seq 1 60); do
  if MYSQL_PWD="$DB_PASSWORD" mysqladmin ping \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --user="$DB_USER" \
    --silent; then
    echo "Drupal DB is ready."
    break
  fi

  if [[ "$attempt" -eq 60 ]]; then
    echo "ERROR: Drupal DB did not become ready."
    exit 1
  fi

  echo "Still waiting for Drupal DB... attempt $attempt/60"
  sleep 2
done

cd /var/www/html

if [[ ! -f web/sites/default/settings.php ]]; then
  echo "Installing Drupal..."

  vendor/bin/drush site:install standard -y \
    --db-url="mysql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME" \
    --site-name="Local Drupal" \
    --account-name=admin \
    --account-pass=admin

  echo "Running Drupal cache rebuild after install..."
  vendor/bin/drush cr -y || vendor/bin/drush cr

  echo "Drupal install complete."
else
  echo "Drupal already installed."
fi

echo "Fixing Drupal file ownership..."
chown -R www-data:www-data /var/www/html/web/sites/default/files || true

echo "Configuring Drupal container mail to ${SMTP_HOST}:${SMTP_PORT}..."

cat > /etc/msmtprc <<MSMTP
defaults
auth off
tls off
account default
host ${SMTP_HOST}
port ${SMTP_PORT}
from drupal@example.local
MSMTP

chmod 600 /etc/msmtprc || true

echo "Drupal is ready."
exec "$@"
