#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2021 grommunio GmbH
#
# gromox-office initialisation (grommunio Files + Office). Every step checks
# the persistent state (files_data volume, databases) and is skipped when
# already done, so this is safe to run on every start.

. /home/common/helpers

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') init: $*" | tee -a "${LOGFILE}"; }
occ() { ( cd /usr/share/grommunio-files && sudo -u grofiles ./occ -n "$@" ); }

# ── grommunio Files ───────────────────────────────────────────────
if [ "${ENABLE_FILES}" = "true" ]; then
  echo "CREATE DATABASE IF NOT EXISTS \`${FILES_MYSQL_DB}\`;" \
    | MYSQL_PWD="${FILES_MYSQL_PASS}" mariadb -h"${FILES_MYSQL_HOST}" -u"${FILES_MYSQL_USER}" >>"${LOGFILE}" 2>&1 || true

  INSTALLED=$(occ status --output=json 2>/dev/null | jq -r '.installed' 2>/dev/null)
  if [ "${INSTALLED}" = "true" ]; then
    log "grommunio Files already installed"
  else
    HAS_TABLES=$(MYSQL_PWD="${FILES_MYSQL_PASS}" mariadb -h"${FILES_MYSQL_HOST}" -u"${FILES_MYSQL_USER}" -N -s -e \
      "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${FILES_MYSQL_DB}' AND table_name='oc_appconfig';" 2>>"${LOGFILE}")
    if [ "${HAS_TABLES:-0}" != "0" ]; then
      log "WARNING: Files database ${FILES_MYSQL_DB} is populated but config.php is missing: not re-installing to avoid data loss. Restore /var/lib/grommunio-files/config/config.php or drop the database."
    else
      log "Installing grommunio Files"
      cp -f /home/config/config.php /usr/share/grommunio-files/config/config.php
      chown grofiles:grofiles /usr/share/grommunio-files/config/config.php
      chmod 0640 /usr/share/grommunio-files/config/config.php
      rm -rf /var/lib/grommunio-files/data/admin >>"${LOGFILE}" 2>&1
      occ maintenance:install --database=mysql --database-host="${FILES_MYSQL_HOST}" --database-name="${FILES_MYSQL_DB}" \
          --database-user="${FILES_MYSQL_USER}" --database-pass="${FILES_MYSQL_PASS}" \
          --admin-user=admin --admin-pass="${FILES_ADMIN_PASS}" --data-dir=/var/lib/grommunio-files/data >>"${LOGFILE}" 2>&1 \
        || log "WARNING: grommunio Files installation failed, see ${LOGFILE}"
      occ -q app:enable user_external >>"${LOGFILE}" 2>&1
      occ -q app:enable onlyoffice >>"${LOGFILE}" 2>&1
      occ -q theming:config name 'grommunio Files' >>"${LOGFILE}" 2>&1
      occ -q theming:config logo /usr/share/grommunio-files/logo.svg >>"${LOGFILE}" 2>&1
      occ -q theming:config logoheader /usr/share/grommunio-files/logo.svg >>"${LOGFILE}" 2>&1
      occ -q theming:config favicon /usr/share/grommunio-files/favicon.svg >>"${LOGFILE}" 2>&1
      occ -q theming:config background /usr/share/grommunio-files/background.jpg >>"${LOGFILE}" 2>&1
      occ -q theming:config slogan 'filesync & sharing' >>"${LOGFILE}" 2>&1
      occ -q theming:config url 'https://grommunio.com' >>"${LOGFILE}" 2>&1
      occ -q theming:config color '#0072B0' >>"${LOGFILE}" 2>&1
    fi
  fi
fi

# ── grommunio Office ──────────────────────────────────────────────
if [ "${ENABLE_OFFICE}" = "true" ]; then
  echo "CREATE DATABASE IF NOT EXISTS \`${OFFICE_MYSQL_DB}\`;" \
    | MYSQL_PWD="${OFFICE_MYSQL_PASS}" mariadb -h"${OFFICE_MYSQL_HOST}" -u"${OFFICE_MYSQL_USER}" >>"${LOGFILE}" 2>&1 || true
  HAS_TABLES=$(MYSQL_PWD="${OFFICE_MYSQL_PASS}" mariadb -h"${OFFICE_MYSQL_HOST}" -u"${OFFICE_MYSQL_USER}" -N -s -e \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${OFFICE_MYSQL_DB}' AND table_name='doc_changes';" 2>>"${LOGFILE}")
  if [ "${HAS_TABLES:-0}" = "0" ]; then
    log "Populating Office database ${OFFICE_MYSQL_DB}"
    sed -e "/^CREATE DATABASE/d" -e "/^USE/d" /usr/libexec/grommunio-office/server/schema/mysql/createdb.sql \
      | MYSQL_PWD="${OFFICE_MYSQL_PASS}" mariadb -h"${OFFICE_MYSQL_HOST}" -u"${OFFICE_MYSQL_USER}" "${OFFICE_MYSQL_DB}" >>"${LOGFILE}" 2>&1 \
      || log "WARNING: importing the Office schema failed, see ${LOGFILE}"
  fi

  # Fonts/themes are generated into the image layer: redo it once per
  # container instance (lost on recreate, kept across restarts).
  STAMP=/usr/libexec/grommunio-office/.fonts-generated
  if [ ! -e "${STAMP}" ]; then
    log "Generating Office fonts and themes (takes a while; fonts first, themes depend on them)"
    LD_LIBRARY_PATH=/usr/libexec/grommunio-office/server/FileConverter/bin \
      /usr/libexec/grommunio-office/server/tools/allfontsgen \
      --input="/usr/share/fonts" \
      --allfonts-web="/usr/libexec/grommunio-office/sdkjs/common/AllFonts.js" \
      --allfonts="/usr/libexec/grommunio-office/server/FileConverter/bin/AllFonts.js" \
      --images="/usr/libexec/grommunio-office/sdkjs/common/Images" \
      --selection="/usr/libexec/grommunio-office/server/FileConverter/bin/font_selection.bin" \
      --output-web="/usr/libexec/grommunio-office/fonts" \
      --use-system=true >>"${LOGFILE}" 2>&1 || true
    for variant in "" "--postfix=ios --params=280,224" "--postfix=android --params=280,224"; do
      # shellcheck disable=SC2086
      LD_LIBRARY_PATH=/usr/libexec/grommunio-office/server/FileConverter/bin \
        /usr/libexec/grommunio-office/server/tools/allthemesgen \
        --converter-dir="/usr/libexec/grommunio-office/server/FileConverter/bin" \
        --src="/usr/libexec/grommunio-office/sdkjs/slide/themes" \
        --output="/usr/libexec/grommunio-office/sdkjs/common/Images" ${variant} >>"${LOGFILE}" 2>&1 || true
    done
    LD_LIBRARY_PATH=/usr/libexec/grommunio-office/server/FileConverter/bin \
      /usr/libexec/grommunio-office/server/FileConverter/bin/x2t -create-js-cache >>"${LOGFILE}" 2>&1 || true
    touch "${STAMP}"
  fi
fi

exit 0
