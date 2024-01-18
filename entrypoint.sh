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
LOGFILE="/var/log/grommunio-setup.log"
if ! test -e "$LOGFILE"; then
	true >"$LOGFILE"
	chmod 0600 "$LOGFILE"
fi
# shellcheck source=common/dialogs
. "${DATADIR}/common/install-option"
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

# Set repository credentials directly
REPO_USER="your_repo_user"
REPO_PASS="your_repo_password"
# shellcheck source=common/repo
INSTALLVALUE="core, chat, files, office, archive"
PACKAGES="gromox grommunio-admin-api grommunio-admin-web grommunio-antispam \
  grommunio-common grommunio-web grommunio-sync grommunio-dav \
  mariadb php-fpm cyrus-sasl-saslauthd cyrus-sasl-plain postfix jq"
PACKAGES="$PACKAGES $FT_PACKAGES"
. "${DATADIR}/common/repo"
setup_repo

ORIGFQDN="localhost"
FQDN="${ORIGFQDN}"


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

# Configure config.json of admin-web
cat > /etc/grommunio-admin-common/nginx.d/web-config.conf <<EOF
location /config.json {
  alias /etc/grommunio-admin-common/config.json;
}
EOF


echo "{ \"mailWebAddress\": \"https://${FQDN}/web\", \"rspamdWebAddress\": \"https://${FQDN}:8443/antispam/\" }" | jq > /tmp/config.json

if [[ $INSTALLVALUE == *"chat"* ]] ; then
  systemctl stop grommunio-chat
  chmod +x /home/scripts/chat.sh
  . /home/scripts/chat.sh
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

cp /home/config/chat.yaml /etc/grommunio-admin-api/conf.d/chat.yaml

  fi

  chmod 640 ${CHAT_CONFIG}
  jq '.chatWebAddress |= "https://'${FQDN}'/chat"' /tmp/config.json > /tmp/config-new.json
  mv /tmp/config-new.json /tmp/config.json

fi

zypper install -y mariadb vim php-fpm cyrus-sasl-saslauthd cyrus-sasl-plain postfix postfix-mysql >>"${LOGFILE}" 2>&1

systemctl enable redis@grommunio.service gromox-delivery.service gromox-event.service \
  gromox-http.service gromox-imap.service gromox-midb.service gromox-pop3.service \
  gromox-delivery-queue.service gromox-timer.service gromox-zcore.service grommunio-antispam.service \
  php-fpm.service nginx.service grommunio-admin-api.service saslauthd.service mariadb >>"${LOGFILE}" 2>&1

systemctl start mariadb >>"${LOGFILE}" 2>&1
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

cp /etc/pam.d/smtp /etc/pam.d/smtp.save
cp /home/config/smtp /etc/pam.d/smtp

echo "create database grommunio; grant all on grommunio.* to 'grommunio'@'localhost' identified by 'grommunio';" | mysql
echo "# Do not delete this file unless you know what you do!" > /etc/grommunio-common/setup_done

chmod +x /home/scripts/mysql.sh
. /home/scripts/mysql.sh

setconf /etc/gromox/mysql_adaptor.cfg mysql_username "${MYSQL_USER}"
setconf /etc/gromox/mysql_adaptor.cfg mysql_password "${MYSQL_PASS}"
setconf /etc/gromox/mysql_adaptor.cfg mysql_dbname "${MYSQL_DB}"
if [ "$MYSQL_INSTALL_TYPE" = 1 ]; then
setconf /etc/gromox/mysql_adaptor.cfg schema_upgrade "host:${FQDN}"
fi

cp -f /etc/gromox/mysql_adaptor.cfg /etc/gromox/adaptor.cfg >>"${LOGFILE}" 2>&1


cp /home/config/autodiscover.ini /etc/gromox/autodiscover.ini 
gromox-dbop -C >>"${LOGFILE}" 2>&1

cp /home/config/database.yaml /etc/grommunio-admin-api/conf.d/database.yaml

grommunio-admin passwd --password "${ADMIN_PASS}" >>"${LOGFILE}" 2>&1

rspamadm pw -p "${ADMIN_PASS}" | sed -e 's#^#password = "#' -e 's#$#";#' > /etc/grommunio-antispam/local.d/worker-controller.inc

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

cp /home/config/certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 
ln -s /etc/grommunio-common/nginx/ssl_certificate.conf /etc/grommunio-admin-common/nginx-ssl.conf
chown gromox:gromox /etc/grommunio-common/ssl/*

# Domain and X500
for SERVICE in http midb zcore imap pop3 smtp delivery ; do
  setconf /etc/gromox/${SERVICE}.cfg default_domain "${DOMAIN}"
done
for CFG in midb.cfg zcore.cfg exmdb_local.cfg exmdb_provider.cfg exchange_emsmdb.cfg exchange_nsp.cfg ; do
  setconf "/etc/gromox/${CFG}" x500_org_name "${X500}"
done

cp /home/config/mailbox/virtual-mailbox-domain.cf /etc/postfix/grommunio-virtual-mailbox-domains.cf 

cp /home/config/mailbox/virtual-mailbox-alias-maps.cf /etc/postfix/grommunio-virtual-mailbox-alias-maps.cf 

cp /home/config/mailbox/virtual-mailbox-maps.cf /etc/postfix/grommunio-virtual-mailbox-maps.cf 
sh /home/scripts/postconf.sh

systemctl enable postfix.service >>"${LOGFILE}" 2>&1
systemctl restart postfix.service >>"${LOGFILE}" 2>&1

systemctl enable grommunio-fetchmail.timer >>"${LOGFILE}" 2>&1
systemctl start grommunio-fetchmail.timer >>"${LOGFILE}" 2>&1

chmod +x /home/scripts/firewall.sh
sh /home/scripts/firewall.sh

systemctl restart redis@grommunio.service nginx.service php-fpm.service gromox-delivery.service \
  gromox-event.service gromox-http.service gromox-imap.service gromox-midb.service \
  gromox-pop3.service gromox-delivery-queue.service gromox-timer.service gromox-zcore.service \
  grommunio-admin-api.service saslauthd.service grommunio-antispam.service >>"${LOGFILE}" 2>&1

if [[ $INSTALLVALUE == *"files"* ]] ; then

  chmod +x /home/scripts/files.sh
. /home/scripts/files.sh

cp /home/config/config.php /usr/share/grommunio-files/config/config.php 

chmod +x /home/scripts/pushd.sh
sh /home/scripts/pushd.sh

  systemctl enable grommunio-files-cron.service >>"${LOGFILE}" 2>&1
  systemctl enable grommunio-files-cron.timer >>"${LOGFILE}" 2>&1
  systemctl start grommunio-files-cron.timer >>"${LOGFILE}" 2>&1

  jq '.fileWebAddress |= "https://'${FQDN}'/files"' /tmp/config.json > /tmp/config-new.json
  mv /tmp/config-new.json /tmp/config.json

fi

if [[ $INSTALLVALUE == *"office"* ]] ; then
chmod +x /home/scripts/office.sh
. /home/scripts/office.sh

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

if [[ $INSTALLVALUE == *"archive"* ]] ; then

chmod +x /home/scripts/archive.sh
. /home/scripts/archive.sh

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

  systemctl enable searchd.service grommunio-archive-smtp.service grommunio-archive.service postfix.service >>"${LOGFILE}" 2>&1
  systemctl restart searchd.service grommunio-archive-smtp.service grommunio-archive.service postfix.service >>"${LOGFILE}" 2>&1

  jq '.archiveWebAddress |= "https://'${FQDN}'/archive"' /tmp/config.json > /tmp/config-new.json
  mv /tmp/config-new.json /tmp/config.json
fi

mv /tmp/config.json /etc/grommunio-admin-common/config.json
systemctl restart grommunio-admin-api.service

setup_done

exit 0