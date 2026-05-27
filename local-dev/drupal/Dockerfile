FROM debian:12-slim

RUN apt-get update \
  && apt-get install -y bash grep coreutils \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m www-data || true
RUN mkdir -p /var/www/html/web

RUN cat > /usr/local/bin/composer <<'EOS'
#!/usr/bin/env bash

if [[ "$*" == *"show drupal/core-*"* ]] || [[ "$*" == *"show 'drupal/core-*'"* ]]; then
  echo "drupal/core-composer-scaffold 10.6.8 A flexible Composer project scaffold builder."
  echo "drupal/core-project-message   10.6.8 Adds a message after Composer installation."
  echo "drupal/core-recommended       10.6.8 Core and its dependencies with known-compatible minor versions."
  exit 0
fi

if [[ "$*" == *"update"* && "$*" == *"drupal/core-"* && "$*" == *"--dry-run"* ]]; then
  echo "Loading composer repositories with package information"
  echo "Updating dependencies"
  echo "Lock file operations: 0 installs, 2 updates, 0 removals"
  echo "  - Upgrading drupal/core (10.6.8 => 10.6.9)"
  echo "  - Upgrading drupal/core-recommended (10.6.8 => 10.6.9)"
  exit 0
fi

if [[ "$*" == *"audit"* ]]; then
  echo "No security vulnerability advisories found."
  exit 0
fi

echo "Mock composer: $*"
EOS

RUN cat > /usr/local/bin/drush <<'EOS'
#!/usr/bin/env bash

if [[ "$*" == *"status"* ]]; then
  echo "Drupal version   : 10.6.8"
  echo "Database         : Connected"
  echo "Drupal bootstrap : Successful"
  echo "PHP version      : 8.3.30"
  echo "Drush version    : 12.5.3.0"
  echo "Drupal root      : /var/www/html/web"
  exit 0
fi

if [[ "$*" == *"updatedb:status"* ]]; then
  echo "No pending updates."
  exit 0
fi

echo "Mock drush: $*"
EOS

RUN mkdir -p /var/www/html/vendor/bin \
  && chmod +x /usr/local/bin/composer /usr/local/bin/drush \
  && ln -s /usr/local/bin/drush /var/www/html/vendor/bin/drush

WORKDIR /var/www/html
