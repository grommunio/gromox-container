#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2021 grommunio GmbH
# Interactive grommunio setup

DATADIR="${0%/*}"
if [ "${DATADIR}" = "$0" ]; then
	DATADIR="/usr/share/grommunio-setup"
else
	DATADIR="$(readlink -f "$0")"
	DATADIR="${DATADIR%/*}"
	DATADIR="$(readlink -f "${DATADIR}")"
fi
LOGFILE="/var/log/grommunio-setup.log"
if ! test -e "$LOGFILE"; then
	true >"$LOGFILE"
	chmod 0600 "$LOGFILE"
fi
# shellcheck source=common/helpers
. "${DATADIR}/common/helpers"
# shellcheck source=common/dialogs
. "${DATADIR}/common/dialogs"
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
  writelog "Memory check"
  memory_notice $((HAVE/1024)) $((ASK/1024))

}

memory_check

unset MYSQL_DB
unset MYSQL_HOST
unset MYSQL_USER
unset MYSQL_PASS
unset CHAT_MYSQL_DB
unset CHAT_MYSQL_HOST
unset CHAT_MYSQL_USER
unset CHAT_MYSQL_PASS
unset CHAT_ADMIN_PASS
unset FILES_MYSQL_DB
unset FILES_MYSQL_HOST
unset FILES_MYSQL_USER
unset FILES_MYSQL_PASS
unset FILES_ADMIN_PASS
unset ARCHIVE_MYSQL_DB
unset ARCHIVE_MYSQL_HOST
unset ARCHIVE_MYSQL_USER
unset ARCHIVE_MYSQL_PASS
unset OFFICE_MYSQL_DB
unset OFFICE_MYSQL_HOST
unset OFFICE_MYSQL_USER
unset OFFICE_MYSQL_PASS
unset ADMIN_PASS
unset FQDN
unset DOMAIN
unset X500
unset SSL_BUNDLE
unset SSL_KEY
unset REPO_USER
unset REPO_PASS
unset REPO_PATH

get_features

set_repo() {

  writelog "Dialog: repository"
  dialog --no-mouse --colors --backtitle "grommunio Setup" --title "Repository configuration" --ok-label "Submit" \
         --form "\nIf you have a subscription, enter your credentials here.\n\nLeave empty for community (unsupported) repositories." 0 0 0 \
  "Subscription username:    " 1 1 "${REPO_USER}"         1 25 25 0 \
  "Subscription password:    " 2 1 "${REPO_PASS}"         2 25 25 0 2>"${TMPF}"
  dialog_exit $?

}

set_repo
REPO_USER=$(sed -n '1{p;q}' "${TMPF}")
REPO_PASS=$(sed -n '2{p;q}' "${TMPF}")
writelog "Installation / update of packages"
# shellcheck source=common/repo
PACKAGES="gromox grommunio-admin-api grommunio-admin-web grommunio-antispam \
  grommunio-common grommunio-web grommunio-sync grommunio-dav \
  mariadb php-fpm cyrus-sasl-saslauthd cyrus-sasl-plain postfix jq"
PACKAGES="$PACKAGES $FT_PACKAGES"
. "${DATADIR}/common/repo"
setup_repo

chmod +x scripts/mysql.sh
sh mysql.sh

dialog_adminpass

set_fqdn()

ORIGFQDN=$(set_fqdn)
FQDN="${ORIGFQDN,,}"


set_maildomain(){

  DFL=$(hostname -d)
  if [ -z "${DFL}" ]; then
    DFL="${FQDN}"
  fi

}

ORIGDOMAIN=$(set_maildomain)
DOMAIN=${ORIGDOMAIN,,}

while [[ ${DOMAIN} =~ / ]] ; do
  ORIGDOMAIN=$(set_maildomain)
  DOMAIN=${ORIGDOMAIN,,}
done

RELAYHOST=$(get_relayhost)

X500="i$(printf "%llx" "$(date +%s)")"

[ -e "/etc/grommunio-common/ssl" ] || mkdir -p "/etc/grommunio-common/ssl"

# Configure config.json of admin-web
cat > /etc/grommunio-admin-common/nginx.d/web-config.conf <<EOF
location /config.json {
  alias /etc/grommunio-admin-common/config.json;
}
EOF


echo "{ \"mailWebAddress\": \"https://${FQDN}/web\", \"rspamdWebAddress\": \"https://${FQDN}:8443/antispam/\" }" | jq > /tmp/config.json

if [ "$FT_CHAT" == "true" ] ; then

  systemctl stop grommunio-chat
  CHAT_MYSQL_HOST="localhost"
  CHAT_MYSQL_USER="grochat"
  CHAT_MYSQL_PASS=$(randpw)
  CHAT_MYSQL_DB="grochat"
  CHAT_CONFIG="/etc/grommunio-chat/config.json"
  set_chat_mysql_param
  if [ "${CHAT_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${CHAT_MYSQL_DB}; \
          create database ${CHAT_MYSQL_DB}; \
          grant all on ${CHAT_MYSQL_DB}.* to '${CHAT_MYSQL_USER}'@'${CHAT_MYSQL_HOST}' identified by '${CHAT_MYSQL_PASS}';" | mysql >/dev/null 2>&1
  else
    echo "drop database if exists ${CHAT_MYSQL_DB}; \
          create database ${CHAT_MYSQL_DB};" | mysql -h"${CHAT_MYSQL_HOST}" -u"${CHAT_MYSQL_USER}" -p"${CHAT_MYSQL_PASS}" "${CHAT_MYSQL_DB}" >/dev/null 2>&1
  fi

  CHAT_DB_CON="${CHAT_MYSQL_USER}:${CHAT_MYSQL_PASS}@tcp\(${CHAT_MYSQL_HOST}:3306\)\/${CHAT_MYSQL_DB}?charset=utf8mb4,utf8\&readTimeout=30s\&writeTimeout=30s"
  sed -i 's#^.*"DataSource":.*#        "DataSource": "'${CHAT_DB_CON}'",#g' "${CHAT_CONFIG}"
  sed -i 's#^.*"DriverName": "postgres".*#        "DriverName": "mysql",#g' "${CHAT_CONFIG}"
  sed -i 's#^.*"EnableAPIUserDeletion":.*#        "EnableAPIUserDeletion": true,#g' "${CHAT_CONFIG}"
  sed -i 's|"SiteURL": "",|"SiteURL": "https://'${FQDN}'/chat",|g' "${CHAT_CONFIG}"
  touch "/var/log/grommunio-chat/mattermost.log"
  chown -R grochat:grochat "/etc/grommunio-chat/" "/usr/share/grommunio-chat/logs" "/usr/share/grommunio-chat/config" "/var/log/grommunio-chat" "/var/lib/grommunio-chat/"
  chmod 644 ${CHAT_CONFIG}
  systemctl enable grommunio-chat
  systemctl restart grommunio-chat
  dialog_chat_adminpass
  # wait for the grommunio-chat unix socket, sometimes a second restart required for bind (db population)
  if ! [ -e "/var/tmp/grommunio-chat_local.socket" ] ; then
    systemctl restart grommunio-chat
    for n in $(seq 1 10) ; do
      [ -e "/var/tmp/grommunio-chat_local.socket" ] && break
      sleep 3
    done
  fi
  pushd /usr/share/grommunio-chat/ || return
    MMCTL_LOCAL_SOCKET_PATH=/var/tmp/grommunio-chat_local.socket bin/grommunio-chat-ctl --local user create --email admin@localhost --username admin --password "${CHAT_ADMIN_PASS}" --system-admin >>"${LOGFILE}" 2>&1
  popd || return

  if [ "${SSL_INSTALL_TYPE}" = "0" ] || [ "${SSL_INSTALL_TYPE}" = "1" ] ; then

cp config/chat.yaml /etc/grommunio-admin-api/conf.d/chat.yaml

  fi

  chmod 640 ${CHAT_CONFIG}
  jq '.chatWebAddress |= "https://'${FQDN}'/chat"' /tmp/config.json > /tmp/config-new.json
  mv /tmp/config-new.json /tmp/config.json

fi

if [ "$FT_MEET" == "true" ] ; then
  writelog "Config feature meet: Starting to setup meet."

  . "${DATADIR}/parts/grommunio-meet.sh"

  jq '.videoWebAddress |= "https://'${FQDN}'/meet"' /tmp/config.json > /tmp/config-new.json
  mv /tmp/config-new.json /tmp/config.json

fi

progress 0
zypper install -y mariadb php-fpm cyrus-sasl-saslauthd cyrus-sasl-plain postfix postfix-mysql >>"${LOGFILE}" 2>&1

progress 10
systemctl enable redis@grommunio.service gromox-delivery.service gromox-event.service \
  gromox-http.service gromox-imap.service gromox-midb.service gromox-pop3.service \
  gromox-delivery-queue.service gromox-timer.service gromox-zcore.service grommunio-antispam.service \
  php-fpm.service nginx.service grommunio-admin-api.service saslauthd.service mariadb >>"${LOGFILE}" 2>&1

progress 20
systemctl start mariadb >>"${LOGFILE}" 2>&1

writelog "Config stage: put php files into place"
if [ -d /etc/php8 ]; then
  if [ -e "/etc/php8/fpm/php-fpm.conf.default" ] ; then
    mv /etc/php8/fpm/php-fpm.conf.default /etc/php8/fpm/php-fpm.conf
  fi
  cp -f /usr/share/gromox/fpm-gromox.conf.sample /etc/php8/fpm/php-fpm.d/gromox.conf
elif [ -d /etc/php7 ]; then
  if [ -e "/etc/php7/fpm/php-fpm.conf.default" ] ; then
    mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
  fi
  cp -f /usr/share/gromox/fpm-gromox.conf.sample /etc/php7/fpm/php-fpm.d/gromox.conf
fi
setconf /etc/gromox/http.cfg listen_port 10080
setconf /etc/gromox/http.cfg http_support_ssl true
setconf /etc/gromox/http.cfg listen_ssl_port 10443
setconf /etc/gromox/http.cfg host_id ${FQDN}

setconf /etc/gromox/smtp.cfg listen_port 24

writelog "Config stage: pam config"
progress 30
cp /etc/pam.d/smtp /etc/pam.d/smtp.save
cp config/smtp /etc/pam.d/smtp

writelog "Config stage: database creation"
progress 40
echo "create database grommunio; grant all on grommunio.* to 'grommunio'@'localhost' identified by '${MYSQL_PASS}';" | mysql
echo "# Do not delete this file unless you know what you do!" > /etc/grommunio-common/setup_done

writelog "Config stage: database configuration"
setconf /etc/gromox/mysql_adaptor.cfg mysql_username "${MYSQL_USER}"
setconf /etc/gromox/mysql_adaptor.cfg mysql_password "${MYSQL_PASS}"
setconf /etc/gromox/mysql_adaptor.cfg mysql_dbname "${MYSQL_DB}"
if [ "$MYSQL_INSTALL_TYPE" = 1 ]; then
setconf /etc/gromox/mysql_adaptor.cfg schema_upgrade "host:${FQDN}"
fi

cp -f /etc/gromox/mysql_adaptor.cfg /etc/gromox/adaptor.cfg >>"${LOGFILE}" 2>&1

writelog "Config stage: autodiscover configuration"
progress 50
cp config/autodiscover.ini /etc/gromox/autodiscover.ini 

writelog "Config stage: database initialization"
gromox-dbop -C >>"${LOGFILE}" 2>&1

cp config/database.yaml /etc/grommunio-admin-api/conf.d/database.yaml

writelog "Config stage: admin password set"
progress 60
grommunio-admin passwd --password "${ADMIN_PASS}" >>"${LOGFILE}" 2>&1

rspamadm pw -p "${ADMIN_PASS}" | sed -e 's#^#password = "#' -e 's#$#";#' > /etc/grommunio-antispam/local.d/worker-controller.inc

writelog "Config stage: gromox tls configuration"
setconf /etc/gromox/http.cfg http_certificate_path "${SSL_BUNDLE_T}"
setconf /etc/gromox/http.cfg http_private_key_path "${SSL_KEY_T}"

setconf /etc/gromox/imap.cfg imap_support_starttls true
setconf /etc/gromox/imap.cfg listen_ssl_port 993
setconf /etc/gromox/imap.cfg imap_certificate_path "${SSL_BUNDLE_T}"
setconf /etc/gromox/imap.cfg imap_private_key_path "${SSL_KEY_T}"

setconf /etc/gromox/pop3.cfg pop3_support_stls true
setconf /etc/gromox/pop3.cfg listen_ssl_port 995
setconf /etc/gromox/pop3.cfg pop3_certificate_path "${SSL_BUNDLE_T}"
setconf /etc/gromox/pop3.cfg pop3_private_key_path "${SSL_KEY_T}"

cp config/certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 
ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf
chown gromox:gromox /etc/grommunio-common/ssl/*

# Domain and X500
writelog "Config stage: gromox domain and x500 configuration"
for SERVICE in http midb zcore imap pop3 smtp delivery ; do
  setconf /etc/gromox/${SERVICE}.cfg default_domain "${DOMAIN}"
done
for CFG in midb.cfg zcore.cfg exmdb_local.cfg exmdb_provider.cfg exchange_emsmdb.cfg exchange_nsp.cfg ; do
  setconf "/etc/gromox/${CFG}" x500_org_name "${X500}"
done

writelog "Config stage: postfix configuration"
progress 80

cp config/mailbox/virtual-mailbox-domain.cf /etc/postfix/grommunio-virtual-mailbox-domains.cf 

cp config/mailbox/virtual-mailbox-alias-maps.cf /etc/postfix/grommunio-virtual-mailbox-alias-maps.cf 

cp config/mailbox/virtual-mailbox-maps.cf /etc/postfix/grommunio-virtual-mailbox-maps.cf 
sh scripts/postconf.sh

writelog "Config stage: postfix enable and restart"
systemctl enable postfix.service >>"${LOGFILE}" 2>&1
systemctl restart postfix.service >>"${LOGFILE}" 2>&1

systemctl enable grommunio-fetchmail.timer >>"${LOGFILE}" 2>&1
systemctl start grommunio-fetchmail.timer >>"${LOGFILE}" 2>&1

writelog "Config stage: open required firewall ports"
sh scripts/firewall.sh

progress 90
writelog "Config stage: restart all required services"
systemctl restart redis@grommunio.service nginx.service php-fpm.service gromox-delivery.service \
  gromox-event.service gromox-http.service gromox-imap.service gromox-midb.service \
  gromox-pop3.service gromox-delivery-queue.service gromox-timer.service gromox-zcore.service \
  grommunio-admin-api.service saslauthd.service grommunio-antispam.service >>"${LOGFILE}" 2>&1

if [ "$FT_FILES" == "true" ] ; then

  FILES_MYSQL_HOST="localhost"
  FILES_MYSQL_USER="grofiles"
  FILES_MYSQL_PASS=$(randpw)
  FILES_MYSQL_DB="grofiles"
  set_files_mysql_param
  if [ "${FILES_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${FILES_MYSQL_DB}; \
          create database ${FILES_MYSQL_DB}; \
          grant all on ${FILES_MYSQL_DB}.* to '${FILES_MYSQL_USER}'@'${FILES_MYSQL_HOST}' identified by '${FILES_MYSQL_PASS}';" | mysql >/dev/null 2>&1
  else
    echo "drop database if exists ${FILES_MYSQL_DB}; \
          create database ${FILES_MYSQL_DB};" | mysql -h"${FILES_MYSQL_HOST}" -u"${FILES_MYSQL_USER}" -p"${FILES_MYSQL_PASS}" "${FILES_MYSQL_DB}" >/dev/null 2>&1
  fi
  dialog_files_adminpass

cp config/config.php /usr/share/grommunio-files/config/config.php 

chmod +x pushd.sh
sh pushd.sh

  systemctl enable grommunio-files-cron.service >>"${LOGFILE}" 2>&1
  systemctl enable grommunio-files-cron.timer >>"${LOGFILE}" 2>&1
  systemctl start grommunio-files-cron.timer >>"${LOGFILE}" 2>&1

  jq '.fileWebAddress |= "https://'${FQDN}'/files"' /tmp/config.json > /tmp/config-new.json
  mv /tmp/config-new.json /tmp/config.json

fi

if [ "$FT_OFFICE" == "true" ] ; then
  writelog "Config stage: install office"
  OFFICE_MYSQL_HOST="localhost"
  OFFICE_MYSQL_USER="groffice"
  OFFICE_MYSQL_PASS=$(randpw)
  OFFICE_MYSQL_DB="groffice"
  set_office_mysql_param
  if [ "${OFFICE_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${OFFICE_MYSQL_DB}; \
          create database ${OFFICE_MYSQL_DB}; \
          grant all on ${OFFICE_MYSQL_DB}.* to '${OFFICE_MYSQL_USER}'@'${OFFICE_MYSQL_HOST}' identified by '${OFFICE_MYSQL_PASS}';" | mysql >/dev/null 2>&1
  else
    echo "drop database if exists ${OFFICE_MYSQL_DB}; \
          create database ${OFFICE_MYSQL_DB};" | mysql -h"${OFFICE_MYSQL_HOST}" -u"${OFFICE_MYSQL_USER}" -p"${OFFICE_MYSQL_PASS}" "${OFFICE_MYSQL_DB}" >/dev/null 2>&1
  fi

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

if [ "$FT_ARCHIVE" == "true" ] ; then
  writelog "Config stage: install archive"

  ARCHIVE_MYSQL_HOST="localhost"
  ARCHIVE_MYSQL_USER="groarchive"
  ARCHIVE_MYSQL_PASS=$(randpw)
  ARCHIVE_MYSQL_DB="groarchive"
  set_archive_mysql_param
  if [ "${ARCHIVE_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${ARCHIVE_MYSQL_DB}; \
          create database ${ARCHIVE_MYSQL_DB}; \
          grant all on ${ARCHIVE_MYSQL_DB}.* to '${ARCHIVE_MYSQL_USER}'@'${ARCHIVE_MYSQL_HOST}' identified by '${ARCHIVE_MYSQL_PASS}';" | mysql >/dev/null 2>&1
  else
    echo "drop database if exists ${ARCHIVE_MYSQL_DB}; \
          create database ${ARCHIVE_MYSQL_DB};" | mysql -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" -p"${ARCHIVE_MYSQL_PASS}" "${ARCHIVE_MYSQL_DB}" >/dev/null 2>&1
  fi

  mysql -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" -p"${ARCHIVE_MYSQL_PASS}" "${ARCHIVE_MYSQL_DB}" < /usr/share/grommunio-archive/db-mysql.sql

  sed -e "s#MYHOSTNAME#${FQDN}#g" -e "s#MYSMTP#${DOMAIN}#g" -e "s/MYSQL_HOSTNAME/${ARCHIVE_MYSQL_HOST}/" -e "s/MYSQL_DATABASE/${ARCHIVE_MYSQL_DB}/" -e "s/MYSQL_PASSWORD/${ARCHIVE_MYSQL_PASS}/" -e "s/MYSQL_USERNAME/${ARCHIVE_MYSQL_USER}/" /etc/grommunio-archive/config-site.dist.php > /etc/grommunio-archive/config-site.php

  echo "/(.*)/   prepend X-Envelope-To: \$1" > /etc/postfix/grommunio-archiver-envelope.cf
  postconf -e "smtpd_recipient_restrictions=permit_sasl_authenticated,permit_mynetworks,check_recipient_access pcre:/etc/postfix/grommunio-archiver-envelope.cf,reject_unknown_recipient_domain,reject_non_fqdn_hostname,reject_non_fqdn_sender,reject_non_fqdn_recipient,reject_unauth_destination,reject_unauth_pipelining"

  postconf -e "always_bcc=archive@${FQDN}"
  echo "archive@${FQDN} smtp:[127.0.0.1]:2693" > /etc/postfix/transport
  postmap /etc/postfix/transport

  mv /etc/grommunio-archive/grommunio-archive.conf.dist /etc/grommunio-archive/grommunio-archive.conf
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqluser "${ARCHIVE_MYSQL_USER}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqlpwd "${ARCHIVE_MYSQL_PASS}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqldb "${ARCHIVE_MYSQL_DB}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf listen_addr 0.0.0.0 0

  php /etc/grommunio-archive/sphinx.conf.dist > /etc/sphinx/sphinx.conf

  sed -i -e "s/MYSQL_HOSTNAME/${ARCHIVE_MYSQL_HOST}/" -e "s/MYSQL_DATABASE/${ARCHIVE_MYSQL_DB}/" -e "s/MYSQL_PASSWORD/${ARCHIVE_MYSQL_PASS}/" -e "s/MYSQL_USERNAME/${ARCHIVE_MYSQL_USER}/" /etc/sphinx/sphinx.conf
  chown groarchive:sphinx /etc/sphinx/sphinx.conf
  chmod 644 /etc/sphinx/sphinx.conf
  chown groarchive:sphinx /var/lib/grommunio-archive/sphinx/ -R
  chmod 775 /var/lib/grommunio-archive/sphinx/
  sudo -u groarchive indexer --all

  < /dev/urandom head -c 56 > /etc/grommunio-archive/grommunio-archive.key

  writelog "Config stage: archive+postfix enable and restart"
  systemctl enable searchd.service grommunio-archive-smtp.service grommunio-archive.service postfix.service >>"${LOGFILE}" 2>&1
  systemctl restart searchd.service grommunio-archive-smtp.service grommunio-archive.service postfix.service >>"${LOGFILE}" 2>&1

  jq '.archiveWebAddress |= "https://'${FQDN}'/archive"' /tmp/config.json > /tmp/config-new.json
  mv /tmp/config-new.json /tmp/config.json
fi

mv /tmp/config.json /etc/grommunio-admin-common/config.json
systemctl restart grommunio-admin-api.service

progress 100
writelog "Config stage: completed"
setup_done

exit 0