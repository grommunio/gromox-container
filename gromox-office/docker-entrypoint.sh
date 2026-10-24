#!/bin/bash
# gromox-office container entrypoint (grommunio Files + grommunio Office).
#
#   1. environment defaults, runtime directories
#   2. wait for the shared certificate (written by gromox-core) and the DBs
#   3. configure.sh: idempotent configuration, applied on EVERY start
#   4. entrypoint.sh: initialisation that is skipped when already done
#      (Files installation, Office schema, font/theme generation)
#   5. exec supervisord as PID 1
# Files' occ needs Redis (configured as memcache), so a temporary redis is
# started for steps 3 and 4.
set -e

export LOGFILE="${LOGFILE:-/var/log/grommunio-setup.log}"
export ENABLE_FILES="${ENABLE_FILES:-false}"
export ENABLE_OFFICE="${ENABLE_OFFICE:-false}"
export FILES_MYSQL_HOST="${FILES_MYSQL_HOST:-files-db}"
export FILES_MYSQL_USER="${FILES_MYSQL_USER:-grofiles}"
export FILES_MYSQL_DB="${FILES_MYSQL_DB:-grofiles}"
export OFFICE_MYSQL_HOST="${OFFICE_MYSQL_HOST:-office-db}"
export OFFICE_MYSQL_USER="${OFFICE_MYSQL_USER:-groffice}"
export OFFICE_MYSQL_DB="${OFFICE_MYSQL_DB:-groffice}"
export CORE_HOST="${CORE_HOST:-gromox-core}"
export TRUSTED_PROXIES="${TRUSTED_PROXIES:-172.28.0.0/24 fd00:1::/64}"

for v in FQDN DOMAIN; do
  if [ -z "${!v:-}" ]; then
    echo "ERROR: ${v} is not set (check var.env / var.local.env)" >&2
    exit 1
  fi
done
if [ "${ENABLE_FILES}" = "true" ] && { [ -z "${FILES_MYSQL_PASS:-}" ] || [ -z "${FILES_ADMIN_PASS:-}" ]; }; then
  echo "ERROR: ENABLE_FILES=true requires FILES_MYSQL_PASS and FILES_ADMIN_PASS" >&2
  exit 1
fi
if [ "${ENABLE_OFFICE}" = "true" ] && [ -z "${OFFICE_MYSQL_PASS:-}" ]; then
  echo "ERROR: ENABLE_OFFICE=true requires OFFICE_MYSQL_PASS" >&2
  exit 1
fi

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
install -d -m 0755 -o redis -g redis /run/redis
install -d -m 0755 -o rabbitmq -g rabbitmq /run/rabbitmq

. /home/common/ssl_setup
wait_for_shared_cert

wait_for_db() {
  local host="$1" user="$2" pass="$3" i
  echo "Waiting for database ${host}..."
  for i in $(seq 1 60); do
    MYSQL_PWD="${pass}" mariadb -u "${user}" -h "${host}" -e "SELECT 1" >/dev/null 2>&1 && return 0
    echo "  attempt $i/60 - retrying in 2s..."
    sleep 2
  done
  echo "ERROR: database ${host} is not reachable" >&2
  return 1
}
[ "${ENABLE_FILES}" = "true" ]  && wait_for_db "${FILES_MYSQL_HOST}" "${FILES_MYSQL_USER}" "${FILES_MYSQL_PASS}"
[ "${ENABLE_OFFICE}" = "true" ] && wait_for_db "${OFFICE_MYSQL_HOST}" "${OFFICE_MYSQL_USER}" "${OFFICE_MYSQL_PASS}"

# Shared secret between Files and the document server (persisted with the office data)
install -d -m 0750 -o groffice -g groffice /var/lib/grommunio-office
if [ "${ENABLE_OFFICE}" = "true" ]; then
  if [ ! -s /var/lib/grommunio-office/.jwt_secret ]; then
    head -c 48 /dev/urandom | base64 | tr -d '/+=\n' > /var/lib/grommunio-office/.jwt_secret
    chmod 0600 /var/lib/grommunio-office/.jwt_secret
  fi
  export OFFICE_JWT_SECRET
  OFFICE_JWT_SECRET=$(cat /var/lib/grommunio-office/.jwt_secret)
fi

# Temporary redis for occ (Files uses Redis for memcache/locking)
REDIS_PID=""
if [ "${ENABLE_FILES}" = "true" ]; then
  sudo -u redis /usr/sbin/redis-server /etc/redis/grommunio.conf --daemonize no >/dev/null 2>&1 &
  REDIS_PID=$!
  for i in $(seq 1 30); do
    redis-cli -h 127.0.0.1 ping >/dev/null 2>&1 && break
    sleep 1
  done
fi

/home/entrypoint.sh
/home/configure.sh

if [ -n "${REDIS_PID}" ]; then
  redis-cli -h 127.0.0.1 shutdown nosave >/dev/null 2>&1 || kill "${REDIS_PID}" 2>/dev/null || true
  wait "${REDIS_PID}" 2>/dev/null || true
fi

# Secrets are only needed by the scripts above; do not hand them to every
# supervised process (they would be visible in /proc/*/environ).
unset MYSQL_PASS MYSQL_ROOT_PASS CHAT_MYSQL_PASS FILES_MYSQL_PASS OFFICE_MYSQL_PASS ARCHIVE_MYSQL_PASS \
      ADMIN_PASS CHAT_ADMIN_PASS FILES_ADMIN_PASS ARCHIVE_ADMIN_PASS ARCHIVE_AUDIT_PASS KEYCLOAK_CLIENT_SECRET SSL_PASS OFFICE_JWT_SECRET

exec /usr/local/bin/supervisord -n -c /etc/supervisord.conf
