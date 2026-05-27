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
EXAMPLE-DRUPAL|drupal|prod|/home/docker/apps/example-drupal|example-drupal-prod|https://drupal.example.org
EXAMPLE-WORDPRESS|wordpress|prod|/home/docker/apps/example-wordpress|example-wordpress-prod|https://wordpress.example.org
```

Fields:

| Field | Description | Example |
|---|---|---|
| `client` | Client or site name | `EXAMPLE-DRUPAL` |
| `type` | CMS type | `drupal` or `wordpress` |
| `env` | Environment name | `prod` |
| `app_path` | App path on host | `/home/docker/apps/example-drupal` |
| `container` | Docker container name | `example-drupal-prod` |
| `url` | Site URL | `https://drupal.example.org` |

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

The workflow runs as a multi-stage action.

### Test Stage

The test stage runs on every push to `main` and on pull requests.

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

### Release Stage

The release stage runs only after the test stage passes.

It runs only on pushes to `main` when the commit message starts with one of these prefixes:

| Commit prefix | Version bump |
|---|---|
| `release:` | Major version bump |
| `major-release:` | Minor version bump |
| `minor-release:` | Patch version bump |

Example release commits:

```bash
git commit --allow-empty -m "minor-release: update installer"
git push
```

```bash
git commit --allow-empty -m "release: initial stable release"
git push
```

Normal commits do not create a release.

Example normal commit:

```bash
git commit -m "Update README"
git push
```

The release package includes only runtime files:

```text
install.sh
check-updates.sh
README.md
VERSION
```

Local Docker test fixtures are not included in the release package.

## Recommended Release Flow

Before creating a release, make sure the normal test workflow is passing.

Then create a release commit:

```bash
git commit --allow-empty -m "release: initial stable release"
git push
```

The GitHub workflow will:

1. Run the full test stage.
2. Stop if tests fail.
3. Determine the next version.
4. Build the release package.
5. Create the GitHub release.
6. Upload the release tarball and checksum file.

## First Server Rollout

After the release is created and tests are passing, start with one server and one or two configured containers.

Install:

```bash
curl -fsSL https://raw.githubusercontent.com/sushant-cividesk/cms-update-checker/main/install.sh | sudo bash
```

Edit clients:

```bash
sudo nano /opt/tools/update-checks/clients.conf
```

Use generic format:

```text
EXAMPLE-DRUPAL|drupal|prod|/home/docker/apps/example-drupal|example-drupal-prod|https://drupal.example.org
EXAMPLE-WORDPRESS|wordpress|prod|/home/docker/apps/example-wordpress|example-wordpress-prod|https://wordpress.example.org
```

Edit mail settings:

```bash
sudo nano /opt/tools/update-checks/settings.env
```

Run manually:

```bash
sudo bash -lc 'set -a; source /opt/tools/update-checks/settings.env; set +a; /opt/tools/update-checks/check-updates.sh'
```

Check generated reports:

```bash
sudo ls -lt /opt/tools/update-checks/reports | head
```

Check cron file:

```bash
sudo cat /etc/cron.d/cms-update-checker
```

Check cron log after the scheduled run:

```bash
sudo tail -n 100 /opt/tools/update-checks/logs/cron.log
```

Once the manual report and email look correct, add the remaining containers to `clients.conf`.

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
