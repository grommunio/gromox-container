#!/bin/bash
# gromox-core container entrypoint.
#
#   1. environment defaults
#   2. runtime directories (/run/*, no systemd-tmpfiles service here)
#   3. wait for the core database
#   4. one-time initialisation (db.sh, entrypoint.sh) guarded by marker files
#   5. configure.sh: idempotent configuration, applied on EVERY start so a
#      recreated container (image update, compose up) is fully configured
#      from the environment and the persistent volumes
#   6. exec supervisord as PID 1
set -e

# Defaults for variables that older var.env files do not define
export LOGFILE="${LOGFILE:-/var/log/grommunio-setup.log}"
export CHAT_CONFIG="${CHAT_CONFIG:-/etc/grommunio-chat/config.json}"
export ENABLE_CHAT="${ENABLE_CHAT:-true}"
export ENABLE_FILES="${ENABLE_FILES:-false}"
export ENABLE_OFFICE="${ENABLE_OFFICE:-false}"
export ENABLE_ARCHIVE="${ENABLE_ARCHIVE:-false}"
export ENABLE_KEYCLOAK="${ENABLE_KEYCLOAK:-false}"
export OFFICE_HOST="${OFFICE_HOST:-gromox-office}"
export ARCHIVE_HOST="${ARCHIVE_HOST:-gromox-archive}"
export SSL_INSTALL_TYPE="${SSL_INSTALL_TYPE:-0}"
export CLEAR_DBS="${CLEAR_DBS:-false}"
export MYSQL_HOST="${MYSQL_HOST:-gromox-db}"
export MYSQL_USER="${MYSQL_USER:-grommunio}"
export MYSQL_DB="${MYSQL_DB:-grommunio}"
export INDEX_SCHEDULE="${INDEX_SCHEDULE-*/15 * * * *}"
# Kubernetes settings (see docs/kubernetes.md); the defaults keep the docker-compose behaviour
export LOG_TO_STDOUT="${LOG_TO_STDOUT:-false}"
export CERT_WATCH="${CERT_WATCH:-false}"
export CERT_OWNER="gromox:gromox"
export CERT_WATCH_RELOAD="${CERT_WATCH_RELOAD:-nginx postfix}"
export CERT_WATCH_RESTART="${CERT_WATCH_RESTART:-gromox-http gromox-imap gromox-pop3}"

. /home/common/helpers

for v in FQDN DOMAIN MYSQL_PASS ADMIN_PASS; do
  if [ -z "${!v:-}" ]; then
    echo "ERROR: ${v} is not set (check var.env / var.local.env)" >&2
    exit 1
  fi
done
if [ "${ENABLE_CHAT}" = "true" ] && { [ -z "${CHAT_MYSQL_PASS:-}" ] || [ -z "${CHAT_ADMIN_PASS:-}" ]; }; then
  echo "ERROR: ENABLE_CHAT=true requires CHAT_MYSQL_PASS and CHAT_ADMIN_PASS" >&2
  exit 1
fi
# The shipped defaults are public knowledge: say so loudly on every start.
for v in ADMIN_PASS CHAT_ADMIN_PASS FILES_ADMIN_PASS MYSQL_PASS CHAT_MYSQL_PASS FILES_MYSQL_PASS OFFICE_MYSQL_PASS ARCHIVE_MYSQL_PASS; do
  case "${!v:-}" in
    admin|grommunio|sfaedre3r32re23|Lu3s3WmFxXghtLwJnuqN)
      echo "WARNING: ${v} still has the default value from var.env - change it in var.local.env before exposing this host" >&2 ;;
  esac
done

if [ "${LOGFILE}" != "/dev/stdout" ] && [ "${LOGFILE}" != "/dev/stderr" ]; then
  touch "${LOGFILE}"
  chmod 0600 "${LOGFILE}"
fi
setup_stdout_logging
# the TLS working directory must not be writable by the service users
install -d -m 0755 -o root -g root /etc/grommunio-common/ssl

# ── Persistent volumes ────────────────────────────────────────────
# Restore the package-provided content into volumes that are still empty
# (Kubernetes PVCs; no-op for Docker named volumes, which are populated
# from the image on first use).
for p in /etc/gromox /etc/grommunio-admin-api /etc/grommunio-admin-common/license \
         /etc/grommunio-chat /var/lib/grommunio-chat \
         /var/lib/grommunio-admin-api /var/lib/grommunio-antispam /var/lib/grommunio-dav \
         /var/lib/grommunio-web /var/lib/redis /var/lib/gromox /var/spool/postfix; do
  seed_volume "$p"
done

# Apply timezone from var.env (TIMEZONE); falls back to the image default if unset/invalid
if [ -n "${TIMEZONE:-}" ] && [ -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then
  ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  echo "${TIMEZONE}" > /etc/timezone
fi

# ── Runtime directories ───────────────────────────────────────────
# /run is empty on every container start and there is no systemd to apply the
# packages' tmpfiles.d entries (/run/gromox, /run/grommunio, /run/php-fpm,
# /run/redis, ...). Without them admin-api, php-fpm, zcore, delivery, event
# and timer cannot bind their sockets.
systemd-tmpfiles --create >/dev/null 2>&1 || true
install -d -m 0775 -o gromox -g gromox /run/gromox
install -d -m 0775 -o grommunio -g nginx /run/grommunio
install -d -m 0711 /run/php-fpm
install -d -m 0755 -o redis -g redis /run/redis
install -d -m 0770 -o gromox -g gromox /var/tmp/gromox-fpm

# Use persistent marker directory (survives restarts with volumes)
MARKER_DIR="/etc/gromox/.setup"
mkdir -p "${MARKER_DIR}"

# Allow forced re-initialisation via environment variable (db.sh is state
# checked and would only act again with CLEAR_DBS=true; leave it alone)
if [ "${FORCE_RECONFIG:-false}" = "true" ]; then
  echo "FORCE_RECONFIG=true: re-running one-time initialisation"
  rm -f "${MARKER_DIR}/entry_done"
fi

# ── Wait for database to be reachable ─────────────────────────────
wait_for_db "${MYSQL_HOST}" "${MYSQL_USER}" "${MYSQL_PASS}" || exit 1

# ── One-time initialisation / configuration ───────────────────────
if [ ! -f "${MARKER_DIR}/db_done" ]; then
  /home/scripts/db.sh
  touch "${MARKER_DIR}/db_done"
fi

# Configuration derived from the environment, applied on every start.
/home/configure.sh

if [ ! -f "${MARKER_DIR}/entry_done" ]; then
  # entrypoint.sh fails (and the container restarts) only when something
  # essential could not be set up; the marker is then not written.
  /home/entrypoint.sh
  touch "${MARKER_DIR}/entry_done"
  # the initialisation created the certificate: re-apply the parts that depend on it
  /home/configure.sh
fi

enable_program cert-watch "${CERT_WATCH}"

# Secrets are only needed by the scripts above; do not hand them to every
# supervised process (they would be visible in /proc/*/environ).
unset MYSQL_PASS MYSQL_ROOT_PASS CHAT_MYSQL_PASS FILES_MYSQL_PASS OFFICE_MYSQL_PASS ARCHIVE_MYSQL_PASS \
      ADMIN_PASS CHAT_ADMIN_PASS FILES_ADMIN_PASS ARCHIVE_ADMIN_PASS ARCHIVE_AUDIT_PASS KEYCLOAK_CLIENT_SECRET SSL_PASS OFFICE_JWT_SECRET

exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
