# gromox-core Container

Docker image for the core [grommunio](https://grommunio.com/) groupware services, based on openSUSE Leap 16.0 with supervisord.

## Services

| Service | Binary | Port (internal) | Description |
|---------|--------|-----------------|-------------|
| nginx | `/usr/sbin/nginx` | 8080, 8443, 9080, 9443 | Reverse proxy for all web services |
| postfix | `/usr/lib/postfix/bin/master` | 2525, 2587, 2465 | Mail transport agent |
| gromox-http | `/usr/libexec/gromox/http` | 10080, 10443 | HTTP/MAPI/AutoDiscover |
| gromox-imap | `/usr/libexec/gromox/imap` | 2143, 2993 | IMAP |
| gromox-pop3 | `/usr/libexec/gromox/pop3` | 2110, 2995 | POP3 |
| gromox-delivery | `/usr/libexec/gromox/delivery` | | Local mail delivery |
| gromox-delivery-queue | `/usr/libexec/gromox/delivery-queue` | 24 | Delivery queue (internal) |
| gromox-zcore | `/usr/libexec/gromox/zcore` | | MAPI core services |
| gromox-midb | `/usr/libexec/gromox/midb` | | Message index database |
| gromox-event | `/usr/libexec/gromox/event` | | Event notifications |
| gromox-timer | `/usr/libexec/gromox/timer` | | Scheduled maintenance |
| grommunio-admin-api | `/usr/sbin/uwsgi` | unix socket | Admin REST API |
| grommunio-antispam | `/usr/bin/rspamd` | 11332-11334 | Spam filtering |
| grommunio-chat | `/usr/bin/grommunio-chat` | | Mattermost messaging (optional) |
| php-fpm | `/usr/sbin/php-fpm` | 9000 | PHP FastCGI |
| redis | `/usr/sbin/redis-server` | 6379 | Cache |
| saslauthd | `/usr/sbin/saslauthd` | unix socket | SMTP auth |
| crond | `/usr/sbin/cron` | | Cron scheduler |

## Port Mapping (host:container)

| Host | Container | Service |
|------|-----------|---------|
| 25 | 2525 | SMTP |
| 80 | 8080 | HTTP redirect / Let's Encrypt |
| 443 | 8443 | HTTPS (webmail, sync, DAV) |
| 465 | 2465 | SMTPS |
| 587 | 2587 | Submission |
| 993 | 2993 | IMAPS |
| 995 | 2995 | POP3S |
| 143 | 2143 | IMAP (STARTTLS) |
| 110 | 2110 | POP3 (STARTTLS) |
| 8443 | 9443 | Admin Web UI |

## Startup Flow

```
docker-entrypoint.sh
  ├── source /home/vars/var.env
  ├── db.sh              (once: initialize gromox database schema)
  ├── entrypoint.sh      (once: SSL, postfix, nginx, gromox config, optional features)
  ├── port remapping     (every start: nginx, postfix, imap, pop3 → high ports)
  ├── chat enablement    (if CHAT_CONFIG exists)
  ├── certbot cron       (if SSL_INSTALL_TYPE=2)
  └── exec supervisord   (PID 1)
```

## Environment Variables

See the main [README.md](../README.md) for the complete environment variable reference.

## Operations

```bash
# Service status
docker exec gromox-core supervisorctl status

# Restart a service
docker exec gromox-core supervisorctl restart nginx

# View logs
docker exec gromox-core cat /var/log/supervisor-nginx.log
docker exec gromox-core tail -f /var/log/supervisor-postfix-err.log

# Force reconfiguration
docker exec gromox-core rm -f /etc/gromox/.setup/entry_done
docker compose restart gromox-core
```

### LDAP Sync

Automates the periodic `grommunio-admin ldap downsync` across all organizations
via a systemd timer. The LDAP connections themselves are configured out-of-band
(admin API / web UI); this only schedules the recurring sync.

| Variable | Description |
|---|---|
| `ENABLE_LDAP_SYNC` | Set to `true` to enable the periodic LDAP downsync timer |
| `LDAP_SYNC_INTERVAL` | systemd `OnCalendar` expression for the interval (default: `*:0/15`, i.e. every 15 min) |

Examples for `LDAP_SYNC_INTERVAL`:

```
*:0/15          # every 15 minutes (:00 :15 :30 :45)
hourly          # every hour
00/6:00         # every 6 hours
*-*-* 02:00:00  # daily at 02:00
```

When enabled, the entrypoint writes a systemd drop-in override
(`/etc/systemd/system/grommunio-ldap-sync.timer.d/override.conf`) with the given
interval and enables the timer. When disabled (default), the timer is stopped and
the override removed. Sync results are logged to journald under the
`grommunio-ldap-sync` tag (`journalctl -t grommunio-ldap-sync`). If no LDAP is
configured for an org, the sync logs `ERR_NO_LDAP` and makes no changes.

### Full-Text Search Index

Webmail full-text search relies on per-user SQLite indexes built by
`grommunio-index`. These indexes only exist once the tool has run against
provisioned mailboxes, so the entrypoint builds them once on first setup and
then refreshes them periodically via cron (`crond` runs under supervisord).
`grommunio-index -A -c` processes all users and creates the index if missing,
which also picks up newly created mailboxes.

| Variable | Description |
|---|---|
| `ENABLE_INDEX` | Set to `false` to disable the periodic index refresh (default: `true`) |
| `INDEX_SCHEDULE` | cron expression for the refresh interval (default: `0 * * * *`, i.e. hourly) |

Examples for `INDEX_SCHEDULE`:

```
0 * * * *       # every hour
*/30 * * * *    # every 30 minutes
0 */6 * * *     # every 6 hours
0 2 * * *       # daily at 02:00
```

When enabled (the default), the entrypoint runs an initial `grommunio-index -A -c`
(logged to `${LOGFILE}`) and writes `/etc/cron.d/grommunio-index` for the
recurring refresh (logged to `/var/log/grommunio-index.log`). When disabled, the
cron file is removed. A build can be triggered manually at any time with
`docker exec gromox-core grommunio-index -A -c`.
