# cms-update-checker

A check-only Drupal and WordPress update checker for Docker-based CMS containers.

The checker scans configured Drupal and WordPress containers, generates a report, and can email the report through SMTP.

It does **not** apply updates or make production changes.

## What It Checks

For Drupal containers:

- Drupal core package versions
- Drush status
- Drupal core Composer dry-run
- Pending Drupal database updates
- Composer security advisories

For WordPress containers:

- Current WordPress version
- Available WordPress core updates
- Available plugin updates
- Available theme updates

It also reports containers that are missing or stopped.

## What It Does Not Do

This tool does not run:

```bash
composer update
drush updb -y
wp core update
wp plugin update
wp theme update
docker restart
docker pull
```

It is check-only.

## Install

Run this on the server:

```bash
curl -fsSL https://raw.githubusercontent.com/sushant-cividesk/cms-update-checker/main/install.sh | sudo bash
```

This installs the checker to:

```text
/opt/tools/update-checks
```

The installer creates:

```text
/opt/tools/update-checks/
├── check-updates.sh
├── clients.conf
├── settings.env
├── logs/
└── reports/
```

It also creates a daily cron job:

```text
/etc/cron.d/cms-update-checker
```

The cron runs every day at **6:30 AM**.

## Server Assumptions

The server should already be a Docker-based CMS server with access to the target Drupal or WordPress containers.

SMTP details for real server installations are provided by the server/admin team and configured manually in:

```text
/opt/tools/update-checks/settings.env
```

For local and GitHub Actions testing, this project uses Mailpit as the SMTP test server.

Mailpit is only for testing. It is not required on production servers.

## Configure Clients

Edit:

```bash
sudo nano /opt/tools/update-checks/clients.conf
```

Format:

```text
client|type|env|app_path|container|url
```

Example:

```text
abc|drupal|prod|/home/docker/apps/abc|abc-prod|https://abc.org
xyz|drupal|prod|/home/docker/apps/xyz|xyz-prod|https://xyz.org
EXAMPLEWP|wordpress|prod|/home/docker/apps/examplewp|examplewp-prod|https://example.org
```

Fields:

| Field | Description | Example |
|---|---|---|
| `client` | Client or site name | `WFSB` |
| `type` | CMS type | `drupal` or `wordpress` |
| `env` | Environment name | `prod` |
| `app_path` | App path on host | `/home/docker/apps/wfsb` |
| `container` | Docker container name | `wfsb-prod` |
| `url` | Site URL | `https://womensfundsb.org` |

## Configure Email

Edit:

```bash
sudo nano /opt/tools/update-checks/settings.env
```

For real server installations, the SMTP values should be provided by the server/admin team.

Example server SMTP settings:

```bash
MAIL_TO="ops@example.org"
MAIL_FROM="cms-update-checker@example.org"

SMTP_HOST="smtp.example.org"
SMTP_PORT="25"
SMTP_USER=""
SMTP_PASSWORD=""
SMTP_TLS="0"
```

For SMTP with STARTTLS:

```bash
SMTP_TLS="1"
SMTP_PORT="587"
```

For local and GitHub Actions testing, Mailpit is used:

```bash
MAIL_TO="ops@example.local"
MAIL_FROM="cms-update-checker@example.local"

SMTP_HOST="localhost"
SMTP_PORT="1025"
SMTP_USER=""
SMTP_PASSWORD=""
SMTP_TLS="0"
```

If `MAIL_TO` or `SMTP_HOST` is empty, the checker still creates a report but skips email sending.

## Run Manually

After editing `clients.conf` and `settings.env`, run:

```bash
sudo bash -lc 'set -a; source /opt/tools/update-checks/settings.env; set +a; /opt/tools/update-checks/check-updates.sh'
```

Reports are saved in:

```text
/opt/tools/update-checks/reports
```

Cron logs are saved in:

```text
/opt/tools/update-checks/logs/cron.log
```

## Cron

The installer adds:

```text
/etc/cron.d/cms-update-checker
```

Default schedule:

```cron
30 6 * * *
```

To change the schedule:

```bash
sudo nano /etc/cron.d/cms-update-checker
```

Example for every 30 minutes during a security release window:

```cron
*/30 * * * * root set -a; source /opt/tools/update-checks/settings.env; set +a; /opt/tools/update-checks/check-updates.sh >> /opt/tools/update-checks/logs/cron.log 2>&1
```

After the security window, change it back to daily.

## Drupal Commands Used

Inside each Drupal container, the checker runs:

```bash
cd /var/www/html
composer show 'drupal/core-*'
vendor/bin/drush status || drush status
composer update 'drupal/core-*' --with-all-dependencies --dry-run
vendor/bin/drush updatedb:status || drush updatedb:status || true
composer audit || true
```

## WordPress Commands Used

Inside each WordPress container, the checker runs:

```bash
cd /var/www/html
wp core version --allow-root || wp core version
wp core check-update --allow-root || wp core check-update || true
wp plugin list --update=available --allow-root || wp plugin list --update=available || true
wp theme list --update=available --allow-root || wp theme list --update=available || true
```

## Local Real Test

The repository includes a real local test environment using:

- Drupal
- WordPress
- MariaDB
- Mailpit

Run:

```bash
docker compose down -v
rm -rf reports logs
mkdir -p reports logs

./tests/run-real-local-test.sh
```

Local test URLs:

| Service | URL |
|---|---|
| Drupal | `http://localhost:8081` |
| WordPress | `http://localhost:8082` |
| Mailpit | `http://localhost:8025` |

Expected test result:

```text
Drupal bootstrap is ready.
WordPress install is ready.
Mailpit API is ready.
Drupal HTTP is ready.
WordPress HTTP is ready.
Report created:
Mailpit has 1 messages.
Testing CMS container email delivery to Mailpit...
Mailpit has 3 messages.
Real local test complete.
```

## GitHub Actions

The workflow runs the real local test.

It verifies:

- ShellCheck passes
- Real Drupal installs with Drush
- Real WordPress installs with WP-CLI
- The checker runs against both CMS containers
- The report is generated
- The checker email reaches Mailpit
- Drupal test email reaches Mailpit
- WordPress test email reaches Mailpit
- The installer creates `/opt/tools/update-checks`
- The installer creates `/etc/cron.d/cms-update-checker`

## Troubleshooting

### No email received

Check mail settings:

```bash
sudo cat /opt/tools/update-checks/settings.env
```

Run manually:

```bash
sudo bash -lc 'set -a; source /opt/tools/update-checks/settings.env; set +a; /opt/tools/update-checks/check-updates.sh'
```

Check the latest report:

```bash
ls -lt /opt/tools/update-checks/reports | head
```

### Container not found

Confirm the container name:

```bash
docker ps --format '{{.Names}}'
```

Then update:

```bash
sudo nano /opt/tools/update-checks/clients.conf
```

### Drupal command fails

Enter the container and test:

```bash
docker exec -it <container> bash
cd /var/www/html
composer show 'drupal/core-*'
vendor/bin/drush status || drush status
```

### WordPress command fails

Enter the container and test:

```bash
docker exec -it <container> bash
cd /var/www/html
wp core version --allow-root || wp core version
```

## Uninstall

Remove installed files:

```bash
sudo rm -rf /opt/tools/update-checks
sudo rm -f /etc/cron.d/cms-update-checker
```
