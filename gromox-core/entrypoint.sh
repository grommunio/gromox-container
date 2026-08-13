#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2021 grommunio GmbH
#
# One-time gromox-core initialisation (first start, or FORCE_RECONFIG=true):
# certificates, admin password, chat database and admin account.
# Everything that can be re-applied on every start lives in configure.sh.

. /home/common/helpers
. /home/common/ssl_setup

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') init: $*" | tee -a "${LOGFILE}"; }

memory_check()
{
  local HAVE
  HAVE=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  if [ -n "${HAVE}" ] && [ "${HAVE}" -lt 4000000 ]; then
    log "WARNING: only $((HAVE/1024)) MB RAM available, grommunio recommends at least 4096 MB"
  fi
}
memory_check

# ── X500 organisation id (persisted in the gromox config volume) ──
X500_FILE="/etc/gromox/.x500_org"
if [ -n "${X500}" ]; then
  echo "${X500}" > "${X500_FILE}"
elif [ -f "${X500_FILE}" ]; then
  X500="$(cat "${X500_FILE}")"
else
  X500="i$(printf "%llx" "$(date +%s)")"
  echo "${X500}" > "${X500_FILE}"
fi

# ── TLS certificate (shared with archive/office via the cert volume) ─
mkdir -p /etc/grommunio-common/ssl
if [ "${SSL_INSTALL_TYPE}" = "2" ]; then
  SSL_DOMAINS="${FQDN},autodiscover.${DOMAIN}"
  if [ -n "${MAIL_DOMAINS}" ]; then
    SSL_DOMAINS="${SSL_DOMAINS},${MAIL_DOMAINS}"
  fi
  SSL_EMAIL="${SSL_EMAIL:-admin@${DOMAIN}}"
  letsencrypt
elif [ "${SSL_INSTALL_TYPE}" = "3" ]; then
  if ! owncert; then
    log "ERROR: SSL_INSTALL_TYPE=3 requires SSL_BUNDLE and SSL_KEY pointing to readable files inside the container"
    exit 1
  fi
else
  if [ -s "${SSL_BUNDLE_T}" ] && [ -s "${SSL_KEY_T}" ]; then
    log "Keeping existing certificate ${SSL_BUNDLE_T}"
  else
    log "Generating certificate for ${FQDN} from the built-in CA"
    selfcert
  fi
fi

# ── grommunio admin password ──────────────────────────────────────
# (configure.sh has already written the API's database configuration)
if ! grommunio-admin passwd --password "${ADMIN_PASS}" >>"${LOGFILE}" 2>&1; then
  log "ERROR: setting the grommunio admin password failed, see ${LOGFILE}"
  exit 1
fi

# ── grommunio-chat ────────────────────────────────────────────────
if [ "${ENABLE_CHAT}" = "true" ] && [ -f "${CHAT_CONFIG}" ]; then
  log "Setting up grommunio-chat"
  echo "CREATE DATABASE IF NOT EXISTS \`${CHAT_MYSQL_DB}\`;" \
    | mariadb -h"${CHAT_MYSQL_HOST}" -u"${CHAT_MYSQL_USER}" -p"${CHAT_MYSQL_PASS}" >>"${LOGFILE}" 2>&1 \
    || log "WARNING: could not create chat database ${CHAT_MYSQL_DB} on ${CHAT_MYSQL_HOST}"

  # DataSource/SiteURL are maintained by configure.sh (already applied before
  # this point on every start); here only the system admin account is created.
  chown -R grochat:grochat "/etc/grommunio-chat/" "/var/log/grommunio-chat" "/var/lib/grommunio-chat/" 2>/dev/null
  chown -R grochat:grochat /usr/share/grommunio-chat/logs /usr/share/grommunio-chat/config 2>/dev/null

  # Temporarily start chat in the background to create the system admin.
  # It resolves i18n/ relative to its working directory, hence the cd.
  rm -f /var/tmp/grommunio-chat_local.socket
  su -s /bin/bash -c "cd /usr/share/grommunio-chat && exec /usr/bin/grommunio-chat --config ${CHAT_CONFIG}" grochat >>"${LOGFILE}" 2>&1 &
  CHAT_PID=$!
  for n in $(seq 1 60) ; do
    [ -S /var/tmp/grommunio-chat_local.socket ] && break
    kill -0 ${CHAT_PID} 2>/dev/null || break
    sleep 2
  done
  if [ -S /var/tmp/grommunio-chat_local.socket ]; then
    ( cd /usr/share/grommunio-chat && \
      MMCTL_LOCAL_SOCKET_PATH=/var/tmp/grommunio-chat_local.socket bin/grommunio-chat-ctl --local user create \
        --email admin@localhost --username admin --password "${CHAT_ADMIN_PASS}" --system-admin ) >>"${LOGFILE}" 2>&1 \
      || log "chat admin user already exists or could not be created, see ${LOGFILE}"
  else
    log "WARNING: grommunio-chat did not come up during initialisation; admin user not created"
  fi
  kill ${CHAT_PID} 2>/dev/null || true
  wait ${CHAT_PID} 2>/dev/null || true
  rm -f /var/tmp/grommunio-chat_local.socket
fi

# Ensure gromox owns the user mailbox tree
chown -R gromox:gromox /var/lib/gromox/user /var/lib/gromox/domain 2>/dev/null
chmod -R 0770 /var/lib/gromox/user /var/lib/gromox/domain 2>/dev/null

if [ ! -s "${SSL_BUNDLE_T}" ] || [ ! -s "${SSL_KEY_T}" ]; then
  log "ERROR: no TLS certificate was produced"
  exit 1
fi
log "grommunio Setup has completed. Admin UI: https://${FQDN}:8443 (admin / ADMIN_PASS)"
exit 0
