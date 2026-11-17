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
# Kubernetes settings (see docs/kubernetes.md); the defaults keep the docker-compose behaviour
export LOG_TO_STDOUT="${LOG_TO_STDOUT:-false}"
export CERT_WATCH="${CERT_WATCH:-false}"
export CERT_WATCH_RELOAD="${CERT_WATCH_RELOAD:-nginx}"
export CERT_WATCH_RESTART="${CERT_WATCH_RESTART:-}"

. /home/common/helpers

for v in FQDN DOMAIN ARCHIVE_MYSQL_PASS ARCHIVE_ADMIN_PASS; do
  if [ -z "${!v:-}" ]; then
    echo "ERROR: ${v} is not set (check var.env / var.local.env)" >&2
    exit 1
  fi
done

for v in ARCHIVE_MYSQL_PASS ARCHIVE_ADMIN_PASS ARCHIVE_AUDIT_PASS; do
  case "${!v:-}" in
    admin|grommunio|grommunioArchiveAdmin|grommunioArchiveAuditor|Lu3s3WmFxXghtLwJnuqN)
      echo "WARNING: ${v} still has a default value - change it in var.local.env before exposing this host" >&2 ;;
  esac
done

if [ "${LOGFILE}" != "/dev/stdout" ] && [ "${LOGFILE}" != "/dev/stderr" ]; then
  touch "${LOGFILE}"
  chmod 0600 "${LOGFILE}"
fi
setup_stdout_logging
# the TLS working directory must not be writable by the service users
install -d -m 0755 -o root -g root /etc/grommunio-common/ssl
seed_volume /var/lib/grommunio-archive

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
install_certificate || exit 1

wait_for_db "${ARCHIVE_MYSQL_HOST}" "${ARCHIVE_MYSQL_USER}" "${ARCHIVE_MYSQL_PASS}" || exit 1
add_hosts_alias "${FQDN}" "autodiscover.${DOMAIN}" || exit 1

/home/configure.sh
/home/entrypoint.sh
enable_program cert-watch "${CERT_WATCH}"

# Secrets are only needed by the scripts above; do not hand them to every
# supervised process (they would be visible in /proc/*/environ).
unset MYSQL_PASS MYSQL_ROOT_PASS CHAT_MYSQL_PASS FILES_MYSQL_PASS OFFICE_MYSQL_PASS ARCHIVE_MYSQL_PASS \
      ADMIN_PASS CHAT_ADMIN_PASS FILES_ADMIN_PASS ARCHIVE_ADMIN_PASS ARCHIVE_AUDIT_PASS KEYCLOAK_CLIENT_SECRET SSL_PASS OFFICE_JWT_SECRET

exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
