#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2021 grommunio GmbH
#
# gromox-archive initialisation. Every step checks the persistent state
# (archive_config / archive_data volumes, database) and is skipped when it
# has already been done, so this is safe to run on every start.

. /home/common/helpers

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') init: $*" | tee -a "${LOGFILE}"; }

mysql_archive() {
  MYSQL_PWD="${ARCHIVE_MYSQL_PASS}" mariadb -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" "$@"
}

# ── Database schema ───────────────────────────────────────────────
echo "CREATE DATABASE IF NOT EXISTS \`${ARCHIVE_MYSQL_DB}\`;" | mysql_archive >>"${LOGFILE}" 2>&1 || true
HAS_META=$(mysql_archive -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${ARCHIVE_MYSQL_DB}' AND table_name='metadata';" 2>>"${LOGFILE}")
if [ "${HAS_META:-0}" = "0" ]; then
  log "Populating archive database ${ARCHIVE_MYSQL_DB}"
  # (the passwords are set from the environment right after the import)
  cat /usr/share/grommunio-archive/db-mysql.sql | mysql_archive "${ARCHIVE_MYSQL_DB}" >>"${LOGFILE}" 2>&1 \
    || log "WARNING: importing the archive schema failed, see ${LOGFILE}"
else
  log "Archive database already populated"
fi

# ── Built-in accounts admin@local / auditor@local ─────────────────
# The schema seeds them with well-known passwords; follow the environment on
# every start (like the grommunio admin password / rspamd UI password).
mysql_archive "${ARCHIVE_MYSQL_DB}" >>"${LOGFILE}" 2>&1 <<EOF || log "WARNING: could not set the archive built-in account passwords"
UPDATE user SET password=ENCRYPT('$(sql_esc "${ARCHIVE_ADMIN_PASS}")', CONCAT('\$1\$', SUBSTRING(MD5(RAND()),1,8))) WHERE username='admin' AND domain='local';
UPDATE user SET password=ENCRYPT('$(sql_esc "${ARCHIVE_AUDIT_PASS}")', CONCAT('\$1\$', SUBSTRING(MD5(RAND()),1,8))) WHERE username='auditor' AND domain='local';
EOF

# ── Encryption key (never regenerate: the store is unreadable without it) ──
# Stored with the mail store on the archive_data volume (configure.sh links
# /etc/grommunio-archive/grommunio-archive.key to it).
KEY=/var/lib/grommunio-archive/grommunio-archive.key
if [ ! -s "${KEY}" ]; then
  HAS_MAIL=$(mysql_archive -N -s -e "SELECT COUNT(*) FROM \`${ARCHIVE_MYSQL_DB}\`.metadata;" 2>/dev/null || echo 0)
  if [ "${HAS_MAIL:-0}" != "0" ] && [ "${ARCHIVE_NEW_KEY:-false}" != "true" ]; then
    log "ERROR: the archive database references ${HAS_MAIL} archived mails but ${KEY} is missing."
    log "       Restore the key from the previous deployment (see README: Upgrading) or set ARCHIVE_NEW_KEY=true to start a new store."
    exit 1
  fi
  log "Generating archive encryption key"
  head -c 56 /dev/urandom > "${KEY}"
fi
chown root:groarchive "${KEY}"
chmod 0640 "${KEY}"
ln -sfn "${KEY}" /etc/grommunio-archive/grommunio-archive.key

# ── Initial full-text index ───────────────────────────────────────
if [ ! -s /var/lib/grommunio-archive/sphinx/main1.sph ]; then
  log "Building initial sphinx indexes"
  sudo -u groarchive indexer --config /etc/sphinx/sphinx.conf --all >>"${LOGFILE}" 2>&1 \
    || log "WARNING: initial indexer run failed, see ${LOGFILE}"
fi

exit 0
