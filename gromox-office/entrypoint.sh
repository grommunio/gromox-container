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
#Choose Install type, 0 for self signed, 2 to provide certificate and 3 for letsencrypt.
SSL_INSTALL_TYPE=0

SSL_COUNTRY="XX"
SSL_STATE="XX"
SSL_LOCALITY="X"
SSL_ORG="grommunio Appliance"
SSL_OU="IT"
SSL_EMAIL="admin@${DOMAIN}"
SSL_DAYS=30
SSL_PASS=grommunio

. "/home/common/ssl_setup"
mkdir /etc/grommunio-common/ssl
RETCMD=1
if [ "${SSL_INSTALL_TYPE}" = "0" ]; then
  clear
  if ! selfcert; then
  touch ssle
  fi
elif [ "${SSL_INSTALL_TYPE}" = "2" ]; then
  choose_ssl_selfprovided
  fullca
  SSL_BUNDLE=/home/ssl/grommox.pem
  SSL_KEY=/home/ssl/grommox.pem
  while [ ${RETCMD} -ne 0 ]; do
    owncert
    RETCMD=$?
  done
elif [ "${SSL_INSTALL_TYPE}" = "3" ]; then
  choose_ssl_letsencrypt
  #this should containe the domain to signed by certbot
  SSL_DOMAINS=$FQDN

  #This should contain the email
  SSL_EMAIL=email@$FQDN
  letsencrypt
fi

[ -e "/etc/grommunio-common/ssl" ] || mkdir -p "/etc/grommunio-common/ssl"

systemctl enable nginx.service saslauthd.service >>"${LOGFILE}" 2>&1 

. "/home/scripts/firewall.sh"

systemctl restart nginx.service saslauthd.service >>"${LOGFILE}" 2>&1 

if [[ $INSTALLVALUE == *"files"* ]] ; then

    echo "drop database if exists ${FILES_MYSQL_DB}; \
          create database ${FILES_MYSQL_DB};" | mysql -h"${FILES_MYSQL_HOST}" -u"${FILES_MYSQL_USER}" -p"${FILES_MYSQL_PASS}" "${FILES_MYSQL_DB}" >/dev/null 2>&1

cp /home/config/config.php /usr/share/grommunio-files/config/config.php 

 pushd /usr/share/grommunio-files
    rm -rf data/admin >>"${LOGFILE}" 2>&1
    sudo -u grofiles ./occ -q -n maintenance:install --database=mysql --database-name=${FILES_MYSQL_DB} --database-user=${FILES_MYSQL_USER} --database-pass=${FILES_MYSQL_PASS} --admin-user=admin --admin-pass="${FILES_ADMIN_PASS}" --data-dir=/var/lib/grommunio-files/data >>"${LOGFILE}" 2>&1
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
    sudo -u grofiles ./occ -q -n theming:config disable-user-theming true >>"${LOGFILE}" 2>&1
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

  systemctl enable grommunio-files-cron.service >>"${LOGFILE}" 2>&1
  systemctl enable grommunio-files-cron.timer >>"${LOGFILE}" 2>&1
  systemctl start grommunio-files-cron.timer >>"${LOGFILE}" 2>&1

#  jq '.fileWebAddress |= "https://'${FQDN}'/files"' /tmp/config.json > /tmp/config-new.json
#  mv /tmp/config-new.json /tmp/config.json
fi

if [[ $INSTALLVALUE == *"office"* ]] ; then

    echo "drop database if exists ${OFFICE_MYSQL_DB}; \
          create database ${OFFICE_MYSQL_DB};" | mysql -h"${OFFICE_MYSQL_HOST}" -u"${OFFICE_MYSQL_USER}" -p"${OFFICE_MYSQL_PASS}" "${OFFICE_MYSQL_DB}" >/dev/null 2>&1

  sed -i -e "/^CREATE DATABASE/d" -e "/^USE/d" /usr/libexec/grommunio-office/server/schema/mysql/createdb.sql
  mysql -h"${OFFICE_MYSQL_HOST}" -u"${OFFICE_MYSQL_USER}" -p"${OFFICE_MYSQL_PASS}" "${OFFICE_MYSQL_DB}" < /usr/libexec/grommunio-office/server/schema/mysql/createdb.sql

  jq '.services.CoAuthoring.sql.dbHost |= "'${OFFICE_MYSQL_HOST}'" | .services.CoAuthoring.sql.dbName |= "'${OFFICE_MYSQL_DB}'" | .services.CoAuthoring.sql.dbUser |= "'${OFFICE_MYSQL_USER}'" | .services.CoAuthoring.sql.dbPass |= "'${OFFICE_MYSQL_PASS}'"' /etc/grommunio-office/default.json > /tmp/default.json
  mv /tmp/default.json /etc/grommunio-office/default.json

  systemctl enable rabbitmq-server.service >>"${LOGFILE}" 2>&1
  systemctl start rabbitmq-server.service >>"${LOGFILE}" 2>&1
  systemctl start ds-themegen.service ds-fontgen.service  >>"${LOGFILE}" 2>&1
  systemctl enable ds-converter.service ds-docservice.service >>"${LOGFILE}" 2>&1
  systemctl start ds-converter.service ds-docservice.service >>"${LOGFILE}" 2>&1
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
