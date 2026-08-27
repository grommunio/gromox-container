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
  # The schema ships the built-in accounts admin@local / auditor@local with
  # well-known passwords; replace them with ARCHIVE_ADMIN_PASS / ARCHIVE_AUDIT_PASS.
  sed -e "s#grommunioArchiveAdmin#${ARCHIVE_ADMIN_PASS//#/\\#}#g" \
      -e "s#grommunioArchiveAuditor#${ARCHIVE_AUDIT_PASS//#/\\#}#g" \
      /usr/share/grommunio-archive/db-mysql.sql | mysql_archive "${ARCHIVE_MYSQL_DB}" >>"${LOGFILE}" 2>&1 \
    || log "WARNING: importing the archive schema failed, see ${LOGFILE}"
else
  log "Archive database already populated"
fi

# ── Encryption key (never regenerate: the store is unreadable without it) ──
KEY=/etc/grommunio-archive/grommunio-archive.key
if [ ! -s "${KEY}" ]; then
  log "Generating archive encryption key"
  head -c 56 /dev/urandom > "${KEY}"
fi
chown root:groarchive "${KEY}"
chmod 0640 "${KEY}"

# ── Initial full-text index ───────────────────────────────────────
if [ ! -s /var/lib/grommunio-archive/sphinx/main1.sph ]; then
  log "Building initial sphinx indexes"
  sudo -u groarchive indexer --config /etc/sphinx/sphinx.conf --all >>"${LOGFILE}" 2>&1 \
    || log "WARNING: initial indexer run failed, see ${LOGFILE}"
fi

exit 0
