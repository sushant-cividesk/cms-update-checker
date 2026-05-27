FROM debian:12-slim

RUN apt-get update \
  && apt-get install -y bash grep coreutils \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m www-data || true
RUN mkdir -p /var/www/html

RUN cat > /usr/local/bin/wp <<'EOS'
#!/usr/bin/env bash

if [[ "$*" == *"core version"* ]]; then
  echo "6.5.5"
  exit 0
fi

if [[ "$*" == *"core check-update"* ]]; then
  echo "+---------+-------------+-------------------------------------------------------------+"
  echo "| version | update_type | package_url                                                 |"
  echo "+---------+-------------+-------------------------------------------------------------+"
  echo "| 6.5.6   | minor       | https://downloads.wordpress.org/release/wordpress-6.5.6.zip |"
  echo "+---------+-------------+-------------------------------------------------------------+"
  exit 0
fi

if [[ "$*" == *"plugin list"* ]]; then
  echo "+---------------+----------+--------+---------+"
  echo "| name          | status   | update | version |"
  echo "+---------------+----------+--------+---------+"
  echo "| contact-form  | active   | yes    | 1.0.0   |"
  echo "+---------------+----------+--------+---------+"
  exit 0
fi

if [[ "$*" == *"theme list"* ]]; then
  echo "+------------+----------+--------+---------+"
  echo "| name       | status   | update | version |"
  echo "+------------+----------+--------+---------+"
  echo "| custom     | active   | none   | 1.0.0   |"
  echo "+------------+----------+--------+---------+"
  exit 0
fi

echo "Mock wp: $*"
EOS

RUN chmod +x /usr/local/bin/wp

WORKDIR /var/www/html
