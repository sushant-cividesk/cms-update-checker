#!/usr/bin/env bash

set -euo pipefail

DB_HOST_RAW="${WORDPRESS_DB_HOST:-real-wordpress-db}"
DB_PORT="${WORDPRESS_DB_PORT:-3306}"

if [[ "$DB_HOST_RAW" == *":"* ]]; then
  DB_HOST="${DB_HOST_RAW%%:*}"
  DB_PORT="${DB_HOST_RAW##*:}"
else
  DB_HOST="$DB_HOST_RAW"
fi

DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"
DB_USER="${WORDPRESS_DB_USER:-wordpress}"
DB_PASSWORD="${WORDPRESS_DB_PASSWORD:-wordpress}"
SITE_URL="${WORDPRESS_SITE_URL:-http://localhost:8082}"
SITE_TITLE="${WORDPRESS_SITE_TITLE:-Local WordPress}"
ADMIN_USER="${WORDPRESS_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${WORDPRESS_ADMIN_PASSWORD:-admin}"
ADMIN_EMAIL="${WORDPRESS_ADMIN_EMAIL:-admin@example.com}"
SMTP_HOST="${SMTP_HOST:-mailpit}"
SMTP_PORT="${SMTP_PORT:-1025}"

echo "Preparing WordPress files..."

if [[ ! -f /var/www/html/wp-includes/version.php ]]; then
  echo "WordPress not found in /var/www/html; copying from /usr/src/wordpress..."
  rsync -a /usr/src/wordpress/ /var/www/html/
  chown -R www-data:www-data /var/www/html
else
  echo "WordPress files already exist."
fi

echo "Waiting for WordPress DB at ${DB_HOST}:${DB_PORT}..."

for attempt in $(seq 1 60); do
  if MYSQL_PWD="$DB_PASSWORD" mysqladmin ping \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --user="$DB_USER" \
    --silent; then
    echo "WordPress DB is ready."
    break
  fi

  if [[ "$attempt" -eq 60 ]]; then
    echo "ERROR: WordPress DB did not become ready."
    exit 1
  fi

  echo "Still waiting for WordPress DB... attempt $attempt/60"
  sleep 2
done

cd /var/www/html

if [[ ! -f wp-config.php ]]; then
  echo "Creating wp-config.php..."

  wp config create \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASSWORD" \
    --dbhost="${DB_HOST}:${DB_PORT}" \
    --allow-root
fi

if ! wp core is-installed --allow-root >/dev/null 2>&1; then
  echo "Installing WordPress..."

  wp core install \
    --url="$SITE_URL" \
    --title="$SITE_TITLE" \
    --admin_user="$ADMIN_USER" \
    --admin_password="$ADMIN_PASSWORD" \
    --admin_email="$ADMIN_EMAIL" \
    --skip-email \
    --allow-root

  echo "WordPress install complete."
else
  echo "WordPress already installed."
fi

echo "Configuring WordPress container mail to ${SMTP_HOST}:${SMTP_PORT}..."

cat > /etc/msmtprc <<MSMTP
defaults
auth off
tls off
account default
host ${SMTP_HOST}
port ${SMTP_PORT}
from wordpress@example.local
MSMTP

chmod 600 /etc/msmtprc || true

echo "WordPress is ready."
exec "$@"
