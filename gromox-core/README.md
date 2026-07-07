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
