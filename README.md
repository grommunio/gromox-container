# Grommunio Containers

Docker Compose deployment for [grommunio](https://grommunio.com/) groupware, based on openSUSE Leap 16.0 with supervisord as process manager.

> **Warning**: This is complex software with sane defaults. For production use, change all default passwords and review the configuration carefully.

## Architecture

```
                    ┌──────────────────────────────────────────┐
  Host ports        │        Docker Network (grommunio)        │
  ──────────        │                                          │
  25  ──► 2525  ──► │  ┌──────────────┐   ┌──────────────┐     │
  80  ──► 8081  ──► │  │  gromox-core │   │gromox-archive│     │
  443 ──► 8443  ──► │  │              │   │  :8443 :2693 │     │
  465 ──► 2465  ──► │  │  supervisord │   │  supervisord │     │
  587 ──► 2587  ──► │  │  18 services │   │  7 services  │     │
  993 ──► 2993  ──► │  └──────┬───────┘   └──────┬───────┘     │
  143 ──► 2143  ──► │         │                  │             │
  110 ──► 2110  ──► │  ┌──────┴───────┐   ┌──────┴───────┐     │
  995 ──► 2995  ──► │  │  gromox-db   │   │  archive-db  │     │
  8443──► 9443  ──► │  │  chat-db     │   └──────────────┘     │
                    │  │  files-db    │                        │
                    │  │  office-db   │   ┌───────────────┐    │
                    │  └──────────────┘   │ gromox-office │    │
                    │                     │  supervisord  │    │
                    │                     │  7 services   │    │
                    │                     └───────────────┘    │
                    └──────────────────────────────────────────┘
```

All service containers run unprivileged - no `privileged: true`, `SYS_ADMIN`, or special runtimes required. Internal ports are remapped above 1024.

## Requirements

- Docker Engine with Docker Compose v2.24 or newer (`docker compose version`)
- at least 4 GB RAM for gromox-core (8 GB with Office)
- a DNS name (`FQDN`) that points to the host; for Let's Encrypt, port 80 must be reachable from the internet
- SELinux hosts (openSUSE Leap 16, Fedora, RHEL) work out of the box: the only
  bind mount (`./gromox_letsencrypt`) is declared with the `z` label

## Quick Start

### 1. Configure

`var.env` holds the defaults and is tracked in git. Put your own values into
`var.local.env` (git-ignored); it is read after `var.env` and overrides it:

```bash
cat > var.local.env <<'EOF'
FQDN=mail.example.com
DOMAIN=example.com
ADMIN_PASS=ChangeMe
CHAT_ADMIN_PASS=ChangeMe
FILES_ADMIN_PASS=ChangeMe
SSL_INSTALL_TYPE=2
EOF
```

Change the database passwords in `docker-compose.yml` (the five MariaDB
services) and set the matching `*_MYSQL_PASS` values in `var.local.env`.

### 2. Start services

```bash
docker compose up -d
```

The first startup takes several minutes as each container initializes databases, generates certificates, and configures services. Follow the progress with `docker compose logs -f gromox-core` and `docker compose ps` (the containers report `healthy` once every service runs).

### 3. Access

| Service | URL |
|---------|-----|
| Webmail | `https://<FQDN>/` |
| Admin UI | `https://<FQDN>:8443/` |
| ActiveSync | `https://<FQDN>/Microsoft-Server-ActiveSync` |
| CalDAV/CardDAV | `https://<FQDN>/dav/` |
| Chat | `https://<FQDN>/chat/` (if enabled) |
| Files | `https://<FQDN>/files/` (if enabled) |
| Archive | `https://<FQDN>/archive/` (if enabled, built-in accounts `admin@local`, `auditor@local`) |

Login to the admin UI with username `admin` and the password set via `ADMIN_PASS`. Create a domain and users there; mail users log in to webmail, IMAP and SMTP with their e-mail address.

## Containers

### gromox-core

The main container running all core groupware services:

| Service | Process | Description |
|---------|---------|-------------|
| nginx | `nginx -g "daemon off;"` | Reverse proxy (web, admin, sync, DAV, files, office, archive) |
| postfix | `master -d` | Mail transport agent |
| gromox-http | `/usr/libexec/gromox/http` | HTTP/MAPI/AutoDiscover |
| gromox-imap | `/usr/libexec/gromox/imap` | IMAP server |
| gromox-pop3 | `/usr/libexec/gromox/pop3` | POP3 server |
| gromox-delivery | `/usr/libexec/gromox/delivery` | Local mail delivery |
| gromox-delivery-queue | `/usr/libexec/gromox/delivery-queue` | Delivery queue processor |
| gromox-zcore | `/usr/libexec/gromox/zcore` | MAPI core |
| gromox-midb | `/usr/libexec/gromox/midb` | Message index DB |
| gromox-event | `/usr/libexec/gromox/event` | Event notification |
| gromox-timer | `/usr/libexec/gromox/timer` | Scheduled tasks |
| grommunio-admin-api | `uwsgi` | Admin REST API |
| grommunio-antispam | `rspamd` | Spam filtering |
| grommunio-chat | `grommunio-chat` | Messaging (optional) |
| php-fpm | `php-fpm -F` | PHP FastCGI |
| redis | `redis-server` | Cache/session store |
| saslauthd | `saslauthd -d -r -a pam` | SMTP authentication |
| crond | `cron -n` | Scheduled tasks (search index, cleanup, certbot) |

### gromox-archive

Email archiving with full-text search:

| Service | Process | Description |
|---------|---------|-------------|
| grommunio-archive | `/usr/sbin/piler` | Archive daemon |
| grommunio-archive-smtp | `/usr/sbin/piler-smtp` | Archive SMTP receiver (port 2693) |
| grommunio-archive-indexer-delta | loop | Delta indexing every `ARCHIVE_INDEXER_DELTA_INTERVAL` |
| grommunio-archive-indexer-main | loop | Daily housekeeping (merge, purge, sign, statistics) |
| searchd | `searchd --nodetach` | Sphinx full-text search |
| nginx | `nginx -g "daemon off;"` | Web interface |
| php-fpm | `php-fpm -F` | PHP FastCGI |

### gromox-office

Document editing and file sync:

| Service | Process | Description |
|---------|---------|-------------|
| ds-docservice | `DocService/docservice` | Document editor server |
| ds-converter | `FileConverter/converter` | Document format converter |
| rabbitmq | `rabbitmq-server` | Message queue for office |
| nginx | `nginx -g "daemon off;"` | Web interface |
| php-fpm | `php-fpm -F` | PHP FastCGI |
| redis | `redis-server` | Cache |
| crond | `cron -n` | Files background tasks |

## Configuration

### Environment Variables (var.env / var.local.env)

#### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `FQDN` | Server fully qualified domain name | `mail.example.com` |
| `DOMAIN` | Mail domain | `example.com` |
| `ADMIN_PASS` | Admin password for grommunio (admin UI, rspamd UI) | `SecurePassword123` |
| `MYSQL_HOST` | MySQL host for gromox core | `gromox-db` |
| `MYSQL_USER` | MySQL user for gromox | `grommunio` |
| `MYSQL_PASS` | MySQL password | `ChangeMe` |
| `MYSQL_DB` | MySQL database name | `grommunio` |

#### SSL/TLS

| Variable | Description | Default |
|----------|-------------|---------|
| `SSL_INSTALL_TYPE` | `0` = certificate from a built-in CA (10 years, renewed automatically), `2` = Let's Encrypt, `3` = own certificate | `0` |
| `SSL_BUNDLE` / `SSL_KEY` | Type 3: paths (inside gromox-core) of the full-chain certificate and the private key, e.g. mounted below `/etc/grommunio-common/ssl/own/` | |
| `SSL_EMAIL` | Email for Let's Encrypt notifications | `admin@DOMAIN` |
| `MAIL_DOMAINS` | Additional names for the Let's Encrypt certificate (comma separated) | |

#### Chat (optional)

| Variable | Description |
|----------|-------------|
| `ENABLE_CHAT` | `true` to set up and run grommunio-chat (default: `true`) |
| `CHAT_MYSQL_HOST` | MySQL host for chat |
| `CHAT_MYSQL_USER` | MySQL user for chat |
| `CHAT_MYSQL_PASS` | MySQL password for chat |
| `CHAT_MYSQL_DB` | MySQL database for chat |
| `CHAT_ADMIN_PASS` | Chat admin password |
| `CHAT_CONFIG` | Path to chat config (default: `/etc/grommunio-chat/config.json`) |

#### Files (optional)

| Variable | Description |
|----------|-------------|
| `ENABLE_FILES` | `true` to enable grommunio Files |
| `FILES_HOST` | Hostname of the files container (default: `gromox-office`) |
| `FILES_MYSQL_HOST` | MySQL host for Files |
| `FILES_MYSQL_USER` | MySQL user for Files |
| `FILES_MYSQL_PASS` | MySQL password for Files |
| `FILES_MYSQL_DB` | MySQL database for Files |
| `FILES_ADMIN_PASS` | Files admin password |
| `TRUSTED_PROXIES` | Networks Files trusts as reverse proxies (default: the compose network) |

#### Office (optional)

| Variable | Description |
|----------|-------------|
| `ENABLE_OFFICE` | `true` to enable grommunio Office |
| `OFFICE_HOST` | Hostname of office container (default: `gromox-office`) |
| `OFFICE_MYSQL_HOST` | MySQL host for Office |
| `OFFICE_MYSQL_USER` | MySQL user for Office |
| `OFFICE_MYSQL_PASS` | MySQL password for Office |
| `OFFICE_MYSQL_DB` | MySQL database for Office |

#### Archive (optional)

| Variable | Description |
|----------|-------------|
| `ENABLE_ARCHIVE` | `true` to enable email archiving |
| `ARCHIVE_HOST` | Hostname of archive container (default: `gromox-archive`) |
| `ARCHIVE_MYSQL_HOST` | MySQL host for Archive |
| `ARCHIVE_MYSQL_USER` | MySQL user for Archive |
| `ARCHIVE_MYSQL_PASS` | MySQL password for Archive |
| `ARCHIVE_MYSQL_DB` | MySQL database for Archive |
| `ARCHIVE_ADMIN_PASS` | Password of the built-in `admin@local` account (default: `ADMIN_PASS`) |
| `ARCHIVE_AUDIT_PASS` | Password of the built-in `auditor@local` account (default: `ADMIN_PASS`) |
| `ARCHIVE_RETENTION_DAYS` | Retention of newly archived mail in days. Default: `2557` (7 years) |
| `ARCHIVE_INDEXER_DELTA_INTERVAL` | Sphinx delta indexer interval (sleep-compatible format, e.g. `600`, `10m`, `1h`). Default: `10m` |
| `ARCHIVE_INDEXER_MAIN_INTERVAL` | Interval between daily housekeeping runs (main merge, purge, sign, stats, daily-report). Default: `24h` |

#### Keycloak SSO (optional)

| Variable | Description |
|----------|-------------|
| `ENABLE_KEYCLOAK` | `true` to enable Keycloak integration |
| `KEYCLOAK_REALM` | Keycloak realm name |
| `KEYCLOAK_URL` | Keycloak server URL |
| `KEYCLOAK_CLIENT_ID` | OAuth client ID |
| `KEYCLOAK_CLIENT_SECRET` | OAuth client secret |

#### Advanced

| Variable | Description | Default |
|----------|-------------|---------|
| `INDEX_SCHEDULE` | cron schedule for the webmail full-text search index (`grommunio-index`), empty disables | `*/15 * * * *` |
| `CLEAR_DBS` | `true` to drop and recreate the core database during (re)initialisation. **Destroys all mail metadata** | `false` |
| `MYSQL_ROOT_PASS` | MySQL root password (required if `CLEAR_DBS=true`) | |
| `FORCE_RECONFIG` | `true` to re-run the one-time initialisation on the next start | `false` |
| `RELAYHOST` | SMTP relay host for outbound mail | (empty) |
| `TIMEZONE` | Timezone | `Europe/Vienna` |
| `TRUSTED_PROXIES` | Networks grommunio Files trusts as reverse proxies | the compose network |
| `LOGFILE` | Setup log file path | `/var/log/grommunio-setup.log` |
| `X500` | X.500 organization identifier (auto-generated if empty) | |

## Port Mapping

All internal ports are above 1024 so containers run without privileges.

| Host Port | Container Port | Protocol | Service |
|-----------|---------------|----------|---------|
| 25 | 2525 | SMTP | Postfix inbound mail |
| 80 | 8081 | HTTP | nginx (Let's Encrypt challenges, HTTP→HTTPS redirect) |
| 443 | 8443 | HTTPS | nginx (webmail, sync, DAV, files, office, archive) |
| 465 | 2465 | SMTPS | Postfix implicit TLS, authenticated submission |
| 587 | 2587 | Submission | Postfix STARTTLS, authenticated submission |
| 993 | 2993 | IMAPS | Gromox IMAP over TLS |
| 995 | 2995 | POP3S | Gromox POP3 over TLS |
| 143 | 2143 | IMAP | Gromox IMAP (STARTTLS) |
| 110 | 2110 | POP3 | Gromox POP3 (STARTTLS) |
| 8443 | 9443 | HTTPS | Grommunio Admin Web UI |

The archive container exposes ports **8443** (nginx) and **2693** (archive SMTP) on the Docker network only (not on the host). The office container exposes **8443** on the Docker network only.

## Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `cert_data` | `/etc/grommunio-common/ssl` | TLS certificate and key (shared across containers) |
| `gromox_config` | `/etc/gromox` | Gromox service configuration, X500 id, init markers |
| `gromox` | `/var/lib/gromox` | Gromox data (mailboxes) |
| `postfix_spool` | `/var/spool/postfix` | Mail queue |
| `grommunio_admin_api` | `/var/lib/grommunio-admin-api` | Admin API data |
| `grommunio_admin_config` | `/etc/grommunio-admin-api` | Admin API configuration (LDAP settings) and JWT signing key |
| `grommunio_admin_license` | `/etc/grommunio-admin-common/license` | Uploaded license |
| `grommunio_antispam` | `/var/lib/grommunio-antispam` | Antispam data |
| `grommunio_dav` | `/var/lib/grommunio-dav` | CalDAV/CardDAV sync state |
| `grommunio_web` | `/var/lib/grommunio-web` | Webmail sessions and search indexes |
| `grommunio_chat_config` | `/etc/grommunio-chat` | Chat configuration |
| `grommunio_chat_data` | `/var/lib/grommunio-chat` | Chat uploads |
| `./gromox_letsencrypt` (bind) | `/etc/letsencrypt` | Let's Encrypt account, certificates and renewal state |
| `files_data` | `/var/lib/grommunio-files` | Files configuration and user data |
| `office_data` | `/var/lib/grommunio-office` | Office document cache and the Files/Office JWT secret |
| `archive_config` | `/etc/grommunio-archive` | Archive configuration and **encryption key** |
| `archive_data` | `/var/lib/grommunio-archive` | Archived mail store and search index |
| `opensuse_data` | `/data` | Shared data volume (legacy) |
| `gromox_services` | `/home/gromox-services` | Service scripts (legacy) |
| `gromox_mysql_data` | MariaDB data | Core database |
| `chat_mysql_data` | MariaDB data | Chat database |
| `files_mysql_data` | MariaDB data | Files database |
| `office_mysql_data` | MariaDB data | Office database |
| `archive_mysql_data` | MariaDB data | Archive database |

Everything that is not on a volume is regenerated from the environment on every container start, so containers can be recreated (image update, `docker compose up` after a configuration change) without losing anything.

## Operations

### Viewing service status

```bash
docker compose ps                                    # healthy = all services running
docker exec gromox-core supervisorctl status
docker exec gromox-archive supervisorctl status
docker exec gromox-office supervisorctl status
```

### Restarting a single service

```bash
docker exec gromox-core supervisorctl restart nginx
docker exec gromox-core supervisorctl restart postfix
docker exec gromox-core supervisorctl restart gromox-imap
```

### Viewing service logs

```bash
# Container log (entrypoint, configuration)
docker compose logs gromox-core

# Supervisor logs (service start/stop/crash)
docker exec gromox-core cat /var/log/supervisord.log

# Per-service logs
docker exec gromox-core cat /var/log/supervisor-nginx.log
docker exec gromox-core cat /var/log/supervisor-gromox-imap-err.log

# Setup log (initialisation and configuration)
docker exec gromox-core cat /var/log/grommunio-setup.log

# Follow logs in real-time
docker exec gromox-core tail -f /var/log/supervisor-postfix.log
```

### Changing the configuration

Edit `var.local.env` and recreate the containers:

```bash
docker compose up -d
```

Configuration derived from the environment (hostnames, feature flags, nginx,
postfix, gromox settings, Files settings) is re-applied on every start.
Credentials of already created accounts are not changed by this; to reset the
grommunio admin password to `ADMIN_PASS` (and re-run the other one-time steps:
certificate check, chat admin creation) set `FORCE_RECONFIG=true` once, run
`docker compose up -d`, then remove it again.

### Updating

```bash
git pull
docker compose build --pull
docker compose up -d
```

Database schema upgrades are applied automatically (gromox by `gromox-http`,
Files by `occ upgrade`, MariaDB by `MARIADB_AUTO_UPGRADE`).

### Updating SSL certificates

**Built-in CA** (`SSL_INSTALL_TYPE=0`, the default): gromox-core creates a local CA and issues the server certificate from it (valid 10 years, renewed automatically before expiry). The CA certificate is trusted by all containers; install it on your clients to avoid certificate warnings:
```bash
docker cp gromox-core:/etc/grommunio-common/ssl/ca.pem grommunio-ca.pem
```
To start over with a new CA and certificate:
```bash
docker exec gromox-core rm -f /etc/grommunio-common/ssl/ca.key /etc/grommunio-common/ssl/ca.pem /etc/grommunio-common/ssl/server-bundle.pem /etc/grommunio-common/ssl/server.key /etc/gromox/.setup/entry_done
docker compose restart gromox-core gromox-archive gromox-office
```

**Let's Encrypt** (set `SSL_INSTALL_TYPE=2`):
- Certbot runs during the first start; port 80 must be reachable from the internet
- Renewal is attempted every 12 hours via cron; nginx is stopped only while a renewal actually runs
- Renewal deploys the new certificate and restarts the TLS services automatically
- If Certbot fails, an existing certificate is kept, otherwise one from the built-in CA is generated

**Own certificates** (set `SSL_INSTALL_TYPE=3`): mount the full-chain certificate and the key into gromox-core and point `SSL_BUNDLE` / `SSL_KEY` at them, e.g. in a `docker-compose.override.yml`:
```yaml
services:
  gromox-core:
    volumes:
      - ./certs:/etc/grommunio-common/ssl/own:ro
```
```
SSL_INSTALL_TYPE=3
SSL_BUNDLE=/etc/grommunio-common/ssl/own/fullchain.pem
SSL_KEY=/etc/grommunio-common/ssl/own/privkey.pem
```
The files are copied into the shared certificate volume on every start of gromox-core, so a renewed certificate is picked up with `docker compose restart gromox-core gromox-archive gromox-office`.

### Backup

Key data to back up:

```bash
# Databases (consistent dumps)
for db in gromox-db chat-db files-db office-db archive-db; do
  docker exec $db sh -c 'mariadb-dump --all-databases -uroot -p"$MARIADB_ROOT_PASSWORD"' > backup/$db.sql
done

# Mailboxes, configuration, certificates, Files data, archive store + key
for v in gromox gromox_config cert_data grommunio_admin_config grommunio_admin_license files_data archive_data archive_config grommunio_chat_data; do
  docker run --rm -v grommunio_$v:/data -v $(pwd)/backup:/backup busybox tar czf /backup/$v.tar.gz /data
done

# Let's Encrypt state
tar czf backup/letsencrypt.tar.gz gromox_letsencrypt/
```

### Upgrading from the previous container layout

Deployments created before the `configure.sh` split kept the archive store and
key, the Files data and the chat uploads in the container layer. If those
containers were never recreated, copy the data out before the first
`docker compose up -d` with the new version, otherwise the new (empty) volumes
start fresh:

```bash
docker cp grommunio-gromox-archive-1:/etc/grommunio-archive/grommunio-archive.key ./archive.key
docker cp grommunio-gromox-archive-1:/var/lib/grommunio-archive/store ./archive-store
docker cp grommunio-gromox-office-1:/var/lib/grommunio-files/config/config.php ./files-config.php
docker cp grommunio-gromox-office-1:/var/lib/grommunio-files/data ./files-data
```

After the upgrade copy them back into the new containers (`gromox-archive:/etc/grommunio-archive/`,
`gromox-archive:/var/lib/grommunio-archive/`, `gromox-office:/var/lib/grommunio-files/`) and restart.
The Files database is kept; without its `config.php` the entrypoint refuses to
re-install Files and logs a warning. Everything else (mailboxes, databases,
certificates, Let's Encrypt state) was already on volumes and is picked up
unchanged. `var.env` is still read; move your changes to `var.local.env` at your
convenience.

### Resetting everything

```bash
docker compose down -v    # Removes containers AND volumes (all data lost!)
docker compose up -d      # Fresh start
```

## Troubleshooting

### Container won't start

```bash
docker compose logs gromox-core
docker compose ps          # are the databases healthy?
```

The entrypoint aborts (and Docker restarts the container) when the database
is unreachable or a required variable (`FQDN`, `DOMAIN`, passwords) is missing.

### Service in FATAL state

```bash
docker exec gromox-core cat /var/log/supervisor-<service-name>-err.log
```

### Files or Archive show a 502

The gromox-core nginx proxies `/files`, `/office` and `/archive` to the other containers; check that they are healthy (`docker compose ps`) and that `ENABLE_FILES`/`ENABLE_OFFICE`/`ENABLE_ARCHIVE` match in all containers (they share the same env files).

### Chat not starting

Chat only starts if `ENABLE_CHAT=true` and `CHAT_CONFIG` points to an existing config file:

```bash
docker exec gromox-core ls -la /etc/grommunio-chat/config.json
docker exec gromox-core supervisorctl status grommunio-chat
```

### Checking port bindings

```bash
docker exec gromox-core ss -tlnp
```

All ports should be above 1024. Expected nginx ports: 8081, 8443 (web), 8080 (admin HTTP, internal), 9443 (admin HTTPS).

Postfix trusts (`mynetworks`) only loopback and the compose network, excluding the network gateways through which Docker proxies connections from the host; everything else must authenticate to relay.

## Project Structure

```
.
├── docker-compose.yml              # Service orchestration
├── var.env                         # Default environment (tracked)
├── var.local.env                   # Your overrides (git-ignored)
├── README.md                       # This file
├── gromox-core/
│   ├── Dockerfile                  # Core container image
│   ├── docker-entrypoint.sh        # Startup: runtime dirs → DB wait → init → configure → supervisord
│   ├── entrypoint.sh               # One-time initialisation (certificate, admin password, chat)
│   ├── configure.sh                # Idempotent configuration applied on every start
│   ├── healthcheck.sh              # Container health (all supervised programs running)
│   ├── supervisord.conf            # Supervisord main config
│   ├── supervisor.d/               # Per-service configs
│   ├── scripts/db.sh               # Core database initialisation
│   ├── common/                     # Shared helpers, SSL setup
│   └── config/                     # Config templates
├── gromox-archive/
│   ├── Dockerfile
│   ├── docker-entrypoint.sh
│   ├── configure.sh                # Every start: piler, sphinx, nginx configuration
│   ├── entrypoint.sh               # Initialisation: schema, encryption key, initial index
│   ├── healthcheck.sh
│   ├── supervisord.conf
│   ├── supervisor.d/
│   ├── common/
│   └── config/
└── gromox-office/
    ├── Dockerfile
    ├── docker-entrypoint.sh
    ├── configure.sh                # Every start: Files settings (occ), Office default.json, nginx
    ├── entrypoint.sh               # Initialisation: Files install, Office schema, fonts
    ├── healthcheck.sh
    ├── supervisord.conf
    ├── supervisor.d/
    ├── common/
    └── config/
```

## Startup Sequence

Each container follows this startup sequence:

1. **docker-entrypoint.sh** applies environment defaults, creates the runtime directories under `/run` (the packages' `tmpfiles.d` entries, since there is no systemd) and waits for its database(s)
2. **gromox-core** waits for its database and runs `db.sh` and `entrypoint.sh` once (guarded by marker files on the `gromox_config` volume); **archive/office** wait for the shared certificate written by gromox-core and run their `entrypoint.sh`, which checks the persistent state itself
3. **configure.sh** (re)generates all configuration derived from the environment: nginx listeners and location blocks, postfix, gromox `*.cfg`, admin-api/admin-web configuration, PHP, cron jobs
4. **supervisord** starts as PID 1 and manages all long-running services

## Maintainer

- [Grommunio Team](https://github.com/grommunio)
- [Open Circle](https://github.com/open-circle-ltd)
