# Running the images on Kubernetes

The Helm chart in `charts/grommunio/` deploys these images. The containers
behave as under docker-compose unless one of the environment variables below
is set; the chart sets them. They are listed here for use with other
orchestration tools.

## Differences to docker-compose

| Topic | docker-compose | Kubernetes |
|---|---|---|
| Volumes | named volumes are populated from the image on first use | PVCs start empty; the entrypoints seed them from a build-time snapshot (`/usr/share/gromox-container/seed`) |
| TLS | gromox-core generates/obtains the certificate and shares it through a volume | one TLS Secret is mounted into every pod, `SSL_INSTALL_TYPE=3`; `cert-watch` reloads on rotation; certbot (`SSL_INSTALL_TYPE=2`) is not available |
| Service discovery | Docker DNS (`127.0.0.11`), short names | CoreDNS from `/etc/resolv.conf`, fully qualified Service names |
| Postfix trust | the compose network is trusted (`mynetworks` from the routing table) | loopback only (`POSTFIX_MYNETWORKS=""`); archive/office use a dedicated listener (`POSTFIX_INTERNAL_RELAY_PORT`) |
| Hairpin to `https://FQDN` | works through the Docker bridge | `/etc/hosts` alias to the internal Service (`FQDN_INTERNAL_TARGET` or `hostAliases`) |
| Logs | files under `/var/log` inside the container | stdout/stderr (`LOG_TO_STDOUT=true`) |
| Health | `healthcheck.sh` (every program) | `healthcheck.sh --essential` (programs in `HEALTHCHECK_ESSENTIAL`) |

## Environment variables

All images:

| Variable | Default | Effect |
|---|---|---|
| `LOG_TO_STDOUT` | `false` | rewrite the supervisor program logs to the container's stdout/stderr; nginx logs likewise. Combine with `LOGFILE=/dev/stdout`. |
| `DB_WAIT_SECONDS` | `120` | how long the entrypoint waits for the database before exiting |
| `CERT_WATCH` | `false` | run the `cert-watch` supervisor program: re-installs the certificate when the files behind `SSL_BUNDLE`/`SSL_KEY`/`SSL_CA` change (`SSL_INSTALL_TYPE=3`) and reloads/restarts the TLS services |
| `CERT_WATCH_INTERVAL` | `60` | seconds between checks |
| `CERT_WATCH_RELOAD` | core: `nginx postfix`, others: `nginx` | services reloaded without downtime on rotation |
| `CERT_WATCH_RESTART` | core: `gromox-http gromox-imap gromox-pop3`, office: `ds-docservice ds-converter` | supervisor programs restarted on rotation (they do not reload certificates) |
| `SSL_CA` | | with `SSL_INSTALL_TYPE=3`: a CA certificate file installed as trust anchor for in-container calls to `https://FQDN` (e.g. `ca.crt` of a Kubernetes TLS Secret issued by a private cert-manager CA). Without it, CA certificates contained in `SSL_BUNDLE` are used. |
| `HEALTHCHECK_ESSENTIAL` | set per image | programs checked by `healthcheck.sh --essential`; programs with `autostart=false` are ignored |
| `SEED_DIR` | `/usr/share/gromox-container/seed` | location of the volume seed snapshot |

gromox-archive and gromox-office additionally:

| Variable | Default | Effect |
|---|---|---|
| `SSL_INSTALL_TYPE=3`, `SSL_BUNDLE`, `SSL_KEY` | | install the certificate from these files instead of waiting for gromox-core's shared volume |
| `FQDN_INTERNAL_TARGET` | | a host name (the core Service) whose address is mapped to `FQDN` and `autodiscover.DOMAIN` in `/etc/hosts` at start, so Files -> DAV and the document server -> Files reach core directly |
| `ARCHIVE_KEY_FILE` (archive) | | an encryption key to install on a fresh archive volume; the container refuses to start if the volume already holds a different key |
| `OFFICE_JWT_SECRET` (office) | | the Files <-> document server secret; takes precedence over the file persisted with the office data |

gromox-core additionally:

| Variable | Default | Effect |
|---|---|---|
| `NGINX_RESOLVER` | first `nameserver` of `/etc/resolv.conf`, else `127.0.0.11` | DNS server nginx uses for `ARCHIVE_HOST`/`OFFICE_HOST` (no search list is applied: use fully qualified names) |
| `NGINX_RESOLVER_FLAGS` | `valid=30s ipv6=off` | resolver options |
| `NGINX_REAL_IP_FROM` | | space separated CIDRs of trusted reverse proxies; writes `set_real_ip_from`/`real_ip_header` so gromox, rspamd and the logs see the client address behind an Ingress |
| `NGINX_REAL_IP_HEADER` | `X-Forwarded-For` | header carrying the client address |
| `ADMIN_URL` | `https://FQDN:8443` | where the admin UI is reachable (the rspamd UI link in the admin UI is derived from it) |
| `POSTFIX_MYNETWORKS` | unset | when set (even empty): `mynetworks = 127.0.0.0/8 [::1]/128 <value>` instead of deriving the trusted networks from the routing table. Kubernetes: kube-proxy may SNAT external connections to a pod-network address, so the pod network must never be trusted. |
| `POSTFIX_INTERNAL_RELAY_PORT` | unset | additional smtpd listener for the other containers of the deployment, no SASL, `permit_auth_destination` (hosted domains only) |
| `POSTFIX_INTERNAL_RELAY_POLICY` | `auth_destination` | `permit` lets the internal listener relay to any destination (Files share-by-mail to external recipients); restrict access to the port with a NetworkPolicy |
| `POSTFIX_INET_PROTOCOLS` | `all` | `ipv4` on IPv4-only clusters |
| `X500` | generated | X.500 organisation id (persisted on the config volume) |

## Persistent paths

Mount these (PVC subPaths are fine; empty mounts are seeded):

* core: `/var/lib/gromox`, `/var/lib/grommunio-admin-api`, `/var/lib/grommunio-antispam`,
  `/var/lib/grommunio-dav`, `/var/lib/grommunio-web`, `/var/lib/grommunio-chat`,
  `/var/lib/redis`, `/var/spool/postfix`, `/etc/gromox`, `/etc/grommunio-admin-api`,
  `/etc/grommunio-admin-common/license`, `/etc/grommunio-chat`
* archive: `/var/lib/grommunio-archive`
* office: `/var/lib/grommunio-files`; `/var/lib/grommunio-office`, `/var/lib/rabbitmq`,
  `/var/lib/redis` may be ephemeral

`/etc/grommunio-common/ssl` is a working directory (emptyDir); the TLS Secret
is mounted below it at `.../ssl/own` and referenced through `SSL_BUNDLE`,
`SSL_KEY`, `SSL_CA`.

## Capabilities

The containers run as root and need `CHOWN DAC_OVERRIDE FOWNER FSETID SETUID
SETGID SETPCAP KILL AUDIT_WRITE`; everything else can be dropped. No listener
binds a port below 1024. `allowPrivilegeEscalation: false` and the
`RuntimeDefault` seccomp profile are fine.
