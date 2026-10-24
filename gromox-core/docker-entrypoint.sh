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

touch "${LOGFILE}"
chmod 0600 "${LOGFILE}"

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
echo "Waiting for database ${MYSQL_HOST}..."
DB_READY=false
for i in $(seq 1 60); do
  if mariadb -u "${MYSQL_USER}" -h "${MYSQL_HOST}" -p"${MYSQL_PASS}" -e "SELECT 1" >/dev/null 2>&1; then
    DB_READY=true
    break
  fi
  echo "  attempt $i/60 - retrying in 2s..."
  sleep 2
done
if [ "${DB_READY}" != "true" ]; then
  echo "ERROR: database ${MYSQL_HOST} is not reachable" >&2
  exit 1
fi

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

# Secrets are only needed by the scripts above; do not hand them to every
# supervised process (they would be visible in /proc/*/environ).
unset MYSQL_PASS MYSQL_ROOT_PASS CHAT_MYSQL_PASS FILES_MYSQL_PASS OFFICE_MYSQL_PASS ARCHIVE_MYSQL_PASS \
      ADMIN_PASS CHAT_ADMIN_PASS FILES_ADMIN_PASS ARCHIVE_ADMIN_PASS ARCHIVE_AUDIT_PASS KEYCLOAK_CLIENT_SECRET SSL_PASS

exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
