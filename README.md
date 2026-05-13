# Grommunio Containers

Docker Compose deployment for [grommunio](https://grommunio.com/) groupware, based on openSUSE Leap 15.6 with supervisord as process manager.

> **Warning**: This is complex software with sane defaults. For production use, change all default passwords and review the configuration carefully.

## Architecture

```
                    ┌──────────────────────────────────────────┐
  Host ports        │        Docker Network (grommunio)        │
  ──────────        │                                          │
  25  ──► 2525  ──► │  ┌──────────────┐   ┌──────────────┐     │
  80  ──► 8080  ──► │  │  gromox-core │   │gromox-archive│     │
  443 ──► 8443  ──► │  │              │   │  :8443 :2693 │     │
  465 ──► 2465  ──► │  │  supervisord │   │  supervisord │     │
  587 ──► 2587  ──► │  │  18 services │   │  6 services  │     │
  993 ──► 2993  ──► │  └──────┬───────┘   └──────┬───────┘     │
  143 ──► 2143  ──► │         │                  │             │
  110 ──► 2110  ──► │  ┌──────┴───────┐   ┌──────┴───────┐     │
  995 ──► 2995  ──► │  │  gromox-db   │   │  archive-db  │     │
  8443──► 9443  ──► │  │  chat-db     │   └──────────────┘     │
                    │  │  files-db    │                        │
                    │  │  office-db   │   ┌───────────────┐    │
                    │  └──────────────┘   │ gromox-office │    │
                    │                     │  supervisord  │    │
                    │                     │  8 services   │    │
                    │                     └───────────────┘    │
                    └──────────────────────────────────────────┘
```

All service containers run unprivileged - no `privileged: true`, `SYS_ADMIN`, or special runtimes required. Internal ports are remapped above 1024.

## Quick Start

### 1. Configure environment

```bash
cp var.env.example var.env   # or edit the existing var.env
# Edit var.env with your domain, passwords, and feature flags
```

### 2. Prepare volumes

```bash
mkdir -p variables_data gromox_letsencrypt
cp var.env variables_data/var.env
```

Or use the pre-launch script:

```bash
./pre-launch.sh
```

### 3. Start services

```bash
docker compose up -d
```

The first startup takes several minutes as each container initializes databases, generates certificates, and configures services.

### 4. Access

| Service | URL |
|---------|-----|
| Webmail | `https://<FQDN>` |
| Admin UI | `https://<FQDN>:8443` |
| ActiveSync | `https://<FQDN>/Microsoft-Server-ActiveSync` |
| CalDAV/CardDAV | `https://<FQDN>/dav` |
| Files | `https://<FQDN>/files` (if enabled) |
| Archive | `https://<FQDN>/archive` (if enabled) |

Login with username `admin` and the password set via `ADMIN_PASS`.

## Containers

### gromox-core

The main container running all core groupware services:

| Service | Process | Description |
|---------|---------|-------------|
| nginx | `nginx -g "daemon off;"` | Reverse proxy (web, admin, sync, DAV) |
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
| saslauthd | `saslauthd -d -a pam` | SMTP authentication |
| crond | `cron -n` | Scheduled tasks (certbot, etc.) |

### gromox-archive

Email archiving with full-text search:

| Service | Process | Description |
|---------|---------|-------------|
| grommunio-archive | `/usr/sbin/piler` | Archive daemon |
| grommunio-archive-smtp | `/usr/sbin/piler-smtp` | Archive SMTP receiver |
| searchd | `searchd --nodetach` | Sphinx full-text search |
| nginx | `nginx -g "daemon off;"` | Web interface |
| php-fpm | `php-fpm -F` | PHP FastCGI |
| saslauthd | `saslauthd -d -a pam` | Authentication |

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
| saslauthd | `saslauthd -d -a pam` | Authentication |
| crond | `cron -n` | Files background tasks |

## Configuration

### Environment Variables (var.env)

#### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `FQDN` | Server fully qualified domain name | `mail.example.com` |
| `DOMAIN` | Mail domain | `example.com` |
| `ADMIN_PASS` | Admin password for grommunio | `SecurePassword123` |
| `MYSQL_HOST` | MySQL host for gromox core | `gromox-db` |
| `MYSQL_USER` | MySQL user for gromox | `grommunio` |
| `MYSQL_PASS` | MySQL password | `ChangeMe` |
| `MYSQL_DB` | MySQL database name | `grommunio` |

#### SSL/TLS

| Variable | Description | Default |
|----------|-------------|---------|
| `SSL_INSTALL_TYPE` | `0` = self-signed, `2` = Let's Encrypt | `0` |
| `SSL_BUNDLE` | Path to custom cert bundle (if providing own) | |
| `SSL_KEY` | Path to custom private key (if providing own) | |
| `SSL_EMAIL` | Email for Let's Encrypt notifications | `admin@DOMAIN` |

#### Chat (optional)

| Variable | Description |
|----------|-------------|
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
| `FILES_MYSQL_HOST` | MySQL host for Files |
| `FILES_MYSQL_USER` | MySQL user for Files |
| `FILES_MYSQL_PASS` | MySQL password for Files |
| `FILES_MYSQL_DB` | MySQL database for Files |
| `FILES_ADMIN_PASS` | Files admin password |

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
| `ARCHIVE_INDEXER_DELTA_INTERVAL` | Sphinx delta indexer interval (sleep-compatible format, e.g. `600`, `10m`, `1h`). Default: `10m` |
| `ARCHIVE_INDEXER_MAIN_INTERVAL` | Interval between daily housekeeping runs (main merge, attachments, purge, sign, stats, daily-report). Default: `24h` |

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
| `CLEAR_DBS` | `true` to drop and recreate databases on startup | `false` |
| `MYSQL_ROOT_PASS` | MySQL root password (required if `CLEAR_DBS=true`) | |
| `FORCE_RECONFIG` | `true` to re-run setup scripts on next restart | `false` |
| `RELAYHOST` | SMTP relay host for outbound mail | (empty) |
| `ORGANIZATION` | Organization name for autodiscover | |
| `TIMEZONE` | Timezone | `Europe/Vienna` |
| `LOGFILE` | Setup log file path | `/var/log/grommunio-setup.log` |
| `X500` | X.500 organization identifier (auto-generated if empty) | |

## Port Mapping

All internal ports are above 1024 so containers run without privileges.

| Host Port | Container Port | Protocol | Service |
|-----------|---------------|----------|---------|
| 25 | 2525 | SMTP | Postfix inbound mail |
| 80 | 8080 | HTTP | nginx (Let's Encrypt challenges, HTTP→HTTPS redirect) |
| 443 | 8443 | HTTPS | nginx (webmail, sync, DAV, files, office, archive) |
| 465 | 2465 | SMTPS | Postfix implicit TLS |
| 587 | 2587 | Submission | Postfix authenticated submission |
| 993 | 2993 | IMAPS | Gromox IMAP over TLS |
| 995 | 2995 | POP3S | Gromox POP3 over TLS |
| 143 | 2143 | IMAP | Gromox IMAP (STARTTLS) |
| 110 | 2110 | POP3 | Gromox POP3 (STARTTLS) |
| 8443 | 9443 | HTTPS | Grommunio Admin Web UI |

The archive container exposes ports **8443** (nginx) and **2693** (archive SMTP) on the Docker network only (not on the host).

## Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `variables_data` | `/home/vars` | Environment configuration (var.env) |
| `cert_data` | `/etc/grommunio-common/ssl` | SSL certificates (shared across containers) |
| `gromox_config` | `/etc/gromox` | Gromox service configuration files |
| `gromox` | `/var/lib/gromox` | Gromox data (mailboxes) |
| `gromox_services` | `/home/gromox-services` | Service scripts |
| `grommunio_admin_api` | `/var/lib/grommunio-admin-api` | Admin API data |
| `grommunio_antispam` | `/var/lib/grommunio-antispam` | Antispam data |
| `grommunio_dav` | `/var/lib/grommunio-dav` | CalDAV/CardDAV data |
| `grommunio_web` | `/var/lib/grommunio-web` | Webmail data |
| `gromox_letsencrypt` | `/etc/letsencrypt` | Let's Encrypt certificates and state |
| `opensuse_data` | `/data` | Shared data volume (setup markers) |
| `gromox_mysql_data` | MariaDB data | Core database |
| `chat_mysql_data` | MariaDB data | Chat database |
| `files_mysql_data` | MariaDB data | Files database |
| `office_mysql_data` | MariaDB data | Office database |
| `archive_mysql_data` | MariaDB data | Archive database |

## Operations

### Viewing service status

```bash
# All services in gromox-core
docker exec gromox-core supervisorctl status

# All services in gromox-archive
docker exec gromox-archive supervisorctl status

# All services in gromox-office
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
# Supervisor logs (service start/stop/crash)
docker exec gromox-core cat /var/log/supervisord.log

# Per-service logs
docker exec gromox-core cat /var/log/supervisor-nginx.log
docker exec gromox-core cat /var/log/supervisor-postfix.log
docker exec gromox-core cat /var/log/supervisor-gromox-imap-err.log

# Setup log (from initial configuration)
docker exec gromox-core cat /var/log/grommunio-setup.log

# Follow logs in real-time
docker exec gromox-core tail -f /var/log/supervisor-nginx.log
```

### Reconfiguring after var.env changes

The setup scripts only run once (on first start). To re-run them after changing `var.env`:

```bash
# Option 1: Set FORCE_RECONFIG in var.env and restart
echo "FORCE_RECONFIG=true" >> variables_data/var.env
docker compose restart gromox-core

# Option 2: Delete marker files manually
docker exec gromox-core rm -f /etc/gromox/.setup/entry_done /etc/gromox/.setup/db_done
docker compose restart gromox-core
```

> **Warning**: Reconfiguration re-runs the full setup, which may drop and recreate optional databases (chat, files, office, archive). Only core gromox database is preserved (it checks for existing tables).

### Updating SSL certificates

**Self-signed** (regenerated automatically on first start):
```bash
docker exec gromox-core rm -f /etc/gromox/.setup/entry_done
docker compose restart gromox-core
```

**Let's Encrypt** (set `SSL_INSTALL_TYPE=2` in var.env):
- Certbot runs automatically on first start
- Auto-renewal runs every 12 hours via cron
- Ensure port 80 is accessible from the internet
- Renewal deploys new certs and restarts nginx automatically

**Custom certificates**:
```bash
# Copy your certificates to the shared volume
docker cp your-cert.pem gromox-core:/etc/grommunio-common/ssl/server-bundle.pem
docker cp your-key.pem gromox-core:/etc/grommunio-common/ssl/server.key

# Restart nginx in all containers
docker exec gromox-core supervisorctl restart nginx
docker exec gromox-archive supervisorctl restart nginx
docker exec gromox-office supervisorctl restart nginx
```

### Rebuilding images

```bash
docker compose build
docker compose up -d
```

### Backup

Key data to back up:

```bash
# Database volumes
docker run --rm -v gromox_mysql_data:/data -v $(pwd)/backup:/backup busybox tar czf /backup/gromox-db.tar.gz /data

# Mailbox data
docker run --rm -v gromox:/data -v $(pwd)/backup:/backup busybox tar czf /backup/gromox-data.tar.gz /data

# Configuration
docker run --rm -v gromox_config:/data -v $(pwd)/backup:/backup busybox tar czf /backup/gromox-config.tar.gz /data

# SSL certificates
docker run --rm -v cert_data:/data -v $(pwd)/backup:/backup busybox tar czf /backup/certs.tar.gz /data

# Let's Encrypt state
tar czf backup/letsencrypt.tar.gz gromox_letsencrypt/
```

### Resetting everything

```bash
docker compose down -v    # Removes containers AND volumes (all data lost!)
docker compose up -d      # Fresh start
```

## Troubleshooting

### Container won't start

```bash
# Check container logs
docker compose logs gromox-core

# Check if databases are healthy
docker compose ps
```

### Service in FATAL state

```bash
# Check the service-specific error log
docker exec gromox-core cat /var/log/supervisor-<service-name>-err.log

# Common causes:
# - gromox-http FATAL: Port conflict - ensure entrypoint.sh completed (check setup log)
# - postfix FATAL: Missing mail configuration - check var.env has FQDN/DOMAIN set
# - ds-docservice FATAL: Missing database - check OFFICE_MYSQL_* variables
```

### Files service fails with self-signed certificates

Grommunio Files (NextCloud-based) rejects self-signed certificates by default. Workaround:

```bash
docker exec gromox-office bash
cd /usr/share/grommunio-files
sudo -u grofiles ./occ -q -n config:system:set trusted_domains 3 --value="<YOUR_SERVER_IP>"
```

Or use Let's Encrypt certificates (`SSL_INSTALL_TYPE=2`).

### Chat not starting

Chat only starts if `CHAT_CONFIG` points to an existing config file. Verify:

```bash
docker exec gromox-core ls -la /etc/grommunio-chat/config.json
docker exec gromox-core supervisorctl status grommunio-chat
```

### Checking port bindings

```bash
docker exec gromox-core ss -tlnp
```

All ports should be above 1024. Expected nginx ports: 8080, 8443 (web), 9080, 9443 (admin).

## Project Structure

```
.
├── docker-compose.yml              # Service orchestration
├── var.env                         # Environment configuration
├── pre-launch.sh                   # Volume setup helper
├── README.md                       # This file
├── gromox-core/
│   ├── Dockerfile                  # Core container image
│   ├── docker-entrypoint.sh        # Startup: env → config → port remap → supervisord
│   ├── entrypoint.sh               # Service configuration (SSL, postfix, nginx, etc.)
│   ├── supervisord.conf            # Supervisord main config
│   ├── supervisor.d/               # Per-service configs (18 files)
│   ├── scripts/db.sh               # Database initialization
│   ├── common/                     # Shared helpers, SSL setup
│   └── config/                     # Config templates
├── gromox-archive/
│   ├── Dockerfile
│   ├── docker-entrypoint.sh
│   ├── entrypoint.sh
│   ├── supervisord.conf
│   ├── supervisor.d/               # Per-service configs (6 files)
│   ├── common/
│   └── config/
└── gromox-office/
    ├── Dockerfile
    ├── docker-entrypoint.sh
    ├── entrypoint.sh
    ├── supervisord.conf
    ├── supervisor.d/               # Per-service configs (8 files)
    ├── common/
    └── config/
```

## Startup Sequence

Each container follows this startup sequence:

1. **docker-entrypoint.sh** starts, sources `var.env`
2. **db.sh** runs (core only) - initializes gromox database schema
3. **entrypoint.sh** runs - configures all services (SSL, postfix, nginx, gromox, optional features)
4. **Port remapping** - rewrites nginx/postfix/gromox configs to use high ports
5. **supervisord** starts as PID 1 - manages all long-running services

Steps 2-3 only run on first start (marker files prevent re-execution). Port remapping (step 4) is idempotent and runs on every start.

## Maintainer

- [Grommunio Team](https://github.com/grommunio)
- [Open Circle](https://github.com/open-circle-ltd)
