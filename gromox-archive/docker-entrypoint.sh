#!/bin/bash
# gromox-archive container entrypoint.
#
#   1. environment defaults, runtime directories
#   2. wait for the shared certificate (written by gromox-core) and the DB
#   3. configure.sh: idempotent configuration, applied on EVERY start
#   4. entrypoint.sh: initialisation that is skipped when already done
#      (database schema, encryption key, initial search index)
#   5. exec supervisord as PID 1
set -e

export LOGFILE="${LOGFILE:-/var/log/grommunio-setup.log}"
export ARCHIVE_MYSQL_HOST="${ARCHIVE_MYSQL_HOST:-archive-db}"
export ARCHIVE_MYSQL_USER="${ARCHIVE_MYSQL_USER:-groarchive}"
export ARCHIVE_MYSQL_DB="${ARCHIVE_MYSQL_DB:-groarchive}"
export ARCHIVE_RETENTION_DAYS="${ARCHIVE_RETENTION_DAYS:-2557}"
export ARCHIVE_ADMIN_PASS="${ARCHIVE_ADMIN_PASS:-${ADMIN_PASS}}"
export ARCHIVE_AUDIT_PASS="${ARCHIVE_AUDIT_PASS:-${ADMIN_PASS}}"

for v in FQDN DOMAIN ARCHIVE_MYSQL_PASS ARCHIVE_ADMIN_PASS; do
  if [ -z "${!v:-}" ]; then
    echo "ERROR: ${v} is not set (check var.env / var.local.env)" >&2
    exit 1
  fi
done

touch "${LOGFILE}"
chmod 0600 "${LOGFILE}"

# Apply timezone from var.env (TIMEZONE); falls back to the image default if unset/invalid
if [ -n "${TIMEZONE:-}" ] && [ -f "/usr/share/zoneinfo/${TIMEZONE}" ]; then
  ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
  echo "${TIMEZONE}" > /etc/timezone
fi

# Runtime directories (no systemd to apply tmpfiles.d)
systemd-tmpfiles --create >/dev/null 2>&1 || true
install -d -m 0711 /run/php-fpm
install -d -m 0775 -o groarchive -g sphinx /run/grommunio-archive
install -d -m 0755 -o sphinx -g sphinx /run/sphinx

. /home/common/ssl_setup
wait_for_shared_cert

echo "Waiting for database ${ARCHIVE_MYSQL_HOST}..."
DB_READY=false
for i in $(seq 1 60); do
  if mariadb -u "${ARCHIVE_MYSQL_USER}" -h "${ARCHIVE_MYSQL_HOST}" -p"${ARCHIVE_MYSQL_PASS}" -e "SELECT 1" >/dev/null 2>&1; then
    DB_READY=true
    break
  fi
  echo "  attempt $i/60 - retrying in 2s..."
  sleep 2
done
if [ "${DB_READY}" != "true" ]; then
  echo "ERROR: database ${ARCHIVE_MYSQL_HOST} is not reachable" >&2
  exit 1
fi

/home/configure.sh
/home/entrypoint.sh

# Secrets are only needed by the scripts above; do not hand them to every
# supervised process (they would be visible in /proc/*/environ).
unset MYSQL_PASS MYSQL_ROOT_PASS CHAT_MYSQL_PASS FILES_MYSQL_PASS OFFICE_MYSQL_PASS ARCHIVE_MYSQL_PASS \
      ADMIN_PASS CHAT_ADMIN_PASS FILES_ADMIN_PASS ARCHIVE_ADMIN_PASS ARCHIVE_AUDIT_PASS KEYCLOAK_CLIENT_SECRET SSL_PASS

exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
