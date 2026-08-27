#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2021 grommunio GmbH
# Interactive grommunio setup

DATADIR="${0%/*}"
if [ "${DATADIR}" = "$0" ]; then
	DATADIR="/home"
else
	DATADIR="$(readlink -f "$0")"
	DATADIR="${DATADIR%/*}"
	DATADIR="$(readlink -f "${DATADIR}")"
fi
if ! test -e "$LOGFILE"; then
	true >"$LOGFILE"
	chmod 0600 "$LOGFILE"
fi
# shellcheck source=common/helpers
. "${DATADIR}/common/helpers"
TMPF=$(mktemp /tmp/grommunio-setup.XXXXXXXX)

memory_check()
{

  local HAVE=$(perl -lne 'print $1 if m{^MemTotal:\s*(\d+)}i' </proc/meminfo)
  # Install the threshold a little lower than what we ask, to account for
  # FW/OS (Vbox with 4194304 KB ends up with MemTotal of about 4020752 KB)
  local THRES=4000000
  local ASK=4096000
  if [ -z "${HAVE}" ] || [ "${HAVE}" -ge "${THRES}" ]; then
    return 0
  fi
  memory_notice $((HAVE/1024)) $((ASK/1024))

}

memory_check

# Set repository credentials directly
# shellcheck source=common/repo
INSTALLVALUE="files, office"

X500="i$(printf "%llx" "$(date +%s)")"

. "/home/common/ssl_setup"
RETCMD=1
if [ "${SSL_INSTALL_TYPE}" = "0" ]; then
  clear
  if ! selfcert; then
  touch ssle
  fi
fi

cp /home/config/certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf
#chown gromox:gromox /etc/grommunio-common/ssl/*

if [ -d /etc/php8 ]; then
  if [ -e "/etc/php8/fpm/php-fpm.conf.default" ] ; then
    mv /etc/php8/fpm/php-fpm.conf.default /etc/php8/fpm/php-fpm.conf
  fi
elif [ -d /etc/php7 ]; then
  if [ -e "/etc/php7/fpm/php-fpm.conf.default" ] ; then
    mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
  fi
fi

if [[ $ENABLE_FILES = true ]] ; then
    . /home/vars/files_db.env
    echo "drop database if exists ${MARIADB_DATABASE}; \
          create database ${MARIADB_DATABASE};" | mysql -h"${MARIADB_HOST}" -u"${MARIADB_HOST}" -p"${MARIADB_PASSWORD}" "${MARIADB_DATABASE}" >/dev/null 2>&1

    sed -i -e 's/memory_limit = 128M/memory_limit = 512M/' /etc/php8/cli/php.ini

    cp /home/config/config.php /usr/share/grommunio-files/config/config.php

 pushd /usr/share/grommunio-files
    rm -rf data/admin >>"${LOGFILE}" 2>&1

    sudo -u grofiles ./occ -q -n maintenance:install --database=mysql --database-host=${MARIADB_HOST} --database-name=${MARIADB_DATABASE} --database-user=${MARIADB_HOST} --database-pass=${MARIADB_PASSWORD} --admin-user=admin --admin-pass="${FILES_ADMIN_PASS}" --data-dir=/var/lib/grommunio-files/data >>"${LOGFILE}" 2>&1
    unset MARIADB_HOST MARIADB_ROOT_PASSWORD MARIADB_DATABASE MARIADB_USER MARIADB_PASSWORD

    sudo -u grofiles ./occ -q -n config:system:set trusted_domains 1 --value="${FQDN}" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set trusted_domains 2 --value="${DOMAIN}" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set trusted_domains 3 --value="mail.${DOMAIN}" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n app:enable user_external >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set user_backends 0 arguments 0 --value="https://${FQDN}/dav" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set user_backends 0 class --value='\OCA\UserExternal\BasicAuth' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n app:enable onlyoffice >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set integrity.check.disabled --type boolean --value true >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config name 'grommunio Files' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config logo /usr/share/grommunio-files/logo.png >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config logoheader /usr/share/grommunio-files/logo.png >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config favicon /usr/share/grommunio-files/favicon.svg >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config background /usr/share/grommunio-files/background.jpg >>"${LOGFILE}" 2>&1
#    sudo -u grofiles ./occ -q -n theming:config disable-user-theming true >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config slogan 'filesync & sharing' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config url 'https://grommunio.com' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n theming:config color '#0072B0' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_from_address --value='admin' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_smtpmode --value='sendmail' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_sendmailmode --value='smtp' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_domain --value="${DOMAIN}" >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_smtphost --value='localhost' >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n config:system:set mail_smtpport --value='25' >>"${LOGFILE}" 2>&1
  popd || return

#  jq '.fileWebAddress |= "https://'${FQDN}'/files"' /tmp/config.json > /tmp/config-new.json
#  mv /tmp/config-new.json /tmp/config.json
fi

if [[ $ENABLE_OFFICE = true ]] ; then
  . /home/vars/office_db.env
    echo "drop database if exists ${MARIADB_DATABASE}; \
          create database ${MARIADB_DATABASE};" | mysql -h"${MARIADB_HOST}" -u"${MARIADB_USER}" -p"${MARIADB_PASSWORD}" "${MARIADB_DATABASE}" >/dev/null 2>&1

  sed -i -e "/^CREATE DATABASE/d" -e "/^USE/d" /usr/libexec/grommunio-office/server/schema/mysql/createdb.sql
  mysql -h"${MARIADB_HOST}" -u"${MARIADB_USER}" -p"${MARIADB_PASSWORD}" "${MARIADB_DATABASE}" < /usr/libexec/grommunio-office/server/schema/mysql/createdb.sql
  unset MARIADB_HOST MARIADB_ROOT_PASSWORD MARIADB_DATABASE MARIADB_USER MARIADB_PASSWORD

  jq '.services.CoAuthoring.sql.dbHost |= "'${MARIADB_HOST}'" | .services.CoAuthoring.sql.dbName |= "'${MARIADB_DATABASE}'" | .services.CoAuthoring.sql.dbUser |= "'${MARIADB_USER}'" | .services.CoAuthoring.sql.dbPass |= "'${MARIADB_PASSWORD}'"' /etc/grommunio-office/default.json > /tmp/default.json
  mv /tmp/default.json /etc/grommunio-office/default.json

  # Run oneshot theme/font generators directly
  LD_LIBRARY_PATH=/usr/libexec/grommunio-office/server/FileConverter/bin \
    /usr/libexec/grommunio-office/server/tools/allthemesgen \
    --converter-dir="/usr/libexec/grommunio-office/server/FileConverter/bin" \
    --src="/usr/libexec/grommunio-office/sdkjs/slide/themes" \
    --output="/usr/libexec/grommunio-office/sdkjs/common/Images" >>"${LOGFILE}" 2>&1 || true
  LD_LIBRARY_PATH=/usr/libexec/grommunio-office/server/FileConverter/bin \
    /usr/libexec/grommunio-office/server/tools/allfontsgen \
    --input="/usr/share/fonts" \
    --allfonts-web="/usr/libexec/grommunio-office/sdkjs/common/AllFonts.js" \
    --allfonts="/usr/libexec/grommunio-office/server/FileConverter/bin/AllFonts.js" \
    --images="/usr/libexec/grommunio-office/sdkjs/common/Images" \
    --selection="/usr/libexec/grommunio-office/server/FileConverter/bin/font_selection.bin" \
    --output-web="/usr/libexec/grommunio-office/fonts" \
    --use-system=true >>"${LOGFILE}" 2>&1 || true

  pushd /usr/share/grommunio-files || return
    sudo -u grofiles ./occ -q -n config:system:set --type boolean --value="true" csrf.disabled
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice DocumentServerUrl --value="https://${FQDN}/office/"
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice DocumentServerInternalUrl --value="https://${FQDN}/office/"
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice StorageUrl --value="https://${FQDN}/files/"
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice customizationChat --value=false
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice customizationCompactHeader --value=true
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice customizationFeedback --value=false
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice customizationToolbarNoTabs --value=true
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice preview --value=false
    sudo -u grofiles ./occ -q -n config:app:set onlyoffice sameTab --value=true
  popd || return
fi

#mv /tmp/config.json /etc/grommunio-admin-common/config.json
setup_done

exit 0
