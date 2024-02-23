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
#INSTALLVALUE="core, chat, files, office, archive"
INSTALLVALUE="archive"

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
#cat > /etc/grommunio-admin-common/nginx.d/web-config.conf <<EOF
#location /config.json {
#  alias /etc/grommunio-admin-common/config.json;
#}
#EOF


#systemctl enable redis@grommunio.service gromox-delivery.service gromox-event.service \
#  gromox-http.service gromox-imap.service gromox-midb.service gromox-pop3.service \
#  gromox-delivery-queue.service gromox-timer.service gromox-zcore.service grommunio-antispam.service \
#  php-fpm.service nginx.service grommunio-admin-api.service saslauthd.service mariadb >>"${LOGFILE}" 2>&1

# Domain and X500
#for SERVICE in http midb zcore imap pop3 smtp delivery ; do
#  setconf /etc/gromox/${SERVICE}.cfg default_domain "${DOMAIN}"
#done
#for CFG in midb.cfg zcore.cfg exmdb_local.cfg exmdb_provider.cfg exchange_emsmdb.cfg exchange_nsp.cfg ; do
#  setconf "/etc/gromox/${CFG}" x500_org_name "${X500}"
#done

{
  firewall-cmd --add-service=https --zone=public --permanent
  firewall-cmd --add-port=25/tcp --zone=public --permanent
  firewall-cmd --add-port=80/tcp --zone=public --permanent
  firewall-cmd --add-port=110/tcp --zone=public --permanent
  firewall-cmd --add-port=143/tcp --zone=public --permanent
  firewall-cmd --add-port=587/tcp --zone=public --permanent
  firewall-cmd --add-port=993/tcp --zone=public --permanent
  firewall-cmd --add-port=995/tcp --zone=public --permanent
  firewall-cmd --add-port=8080/tcp --zone=public --permanent
  firewall-cmd --add-port=8443/tcp --zone=public --permanent
  firewall-cmd --reload
} >>"${LOGFILE}" 2>&1

systemctl restart saslauthd.service >>"${LOGFILE}" 2>&1
# redis@grommunio.service nginx.service php-fpm.service gromox-delivery.service \
#  gromox-event.service gromox-http.service gromox-imap.service gromox-midb.service \
#  gromox-pop3.service gromox-delivery-queue.service gromox-timer.service gromox-zcore.service \
#  grommunio-admin-api.service saslauthd.service grommunio-antispam.service >>"${LOGFILE}" 2>&1

cp /home/config/certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 
chown gromox:gromox /etc/grommunio-common/ssl/*

if [[ $INSTALLVALUE == *"archive"* ]] ; then

    echo "drop database if exists ${ARCHIVE_MYSQL_DB}; \
          create database ${ARCHIVE_MYSQL_DB};" | mysql -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" -p"${ARCHIVE_MYSQL_PASS}" "${ARCHIVE_MYSQL_DB}" >/dev/null 2>&1

  mysql -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" -p"${ARCHIVE_MYSQL_PASS}" "${ARCHIVE_MYSQL_DB}" < /usr/share/grommunio-archive/db-mysql.sql

  sed -e "s#MYHOSTNAME#${FQDN}#g" -e "s#MYSMTP#${DOMAIN}#g" -e "s/MYSQL_HOSTNAME/${ARCHIVE_MYSQL_HOST}/" -e "s/MYSQL_DATABASE/${ARCHIVE_MYSQL_DB}/" -e "s/MYSQL_PASSWORD/${ARCHIVE_MYSQL_PASS}/" -e "s/MYSQL_USERNAME/${ARCHIVE_MYSQL_USER}/" /etc/grommunio-archive/config-site.dist.php > /etc/grommunio-archive/config-site.php

  #echo "/(.*)/   prepend X-Envelope-To: \$1" > /etc/postfix/grommunio-archiver-envelope.cf
  #postconf -e "smtpd_recipient_restrictions=permit_sasl_authenticated,permit_mynetworks,check_recipient_access pcre:/etc/postfix/grommunio-archiver-envelope.cf,reject_unknown_recipient_domain,reject_non_fqdn_hostname,reject_non_fqdn_sender,reject_non_fqdn_recipient,reject_unauth_destination,reject_unauth_pipelining" # set this up on gromox

  #postconf -e "always_bcc=archive@${FQDN}" # set this up on gromox
  #echo "archive@${FQDN} smtp:[127.0.0.1]:2693" > /etc/postfix/transport # set this up on gromox
  #postmap /etc/postfix/transport # set this up on gromox

  mv /etc/grommunio-archive/grommunio-archive.conf.dist /etc/grommunio-archive/grommunio-archive.conf
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqluser "${ARCHIVE_MYSQL_USER}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqlpwd "${ARCHIVE_MYSQL_PASS}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqldb "${ARCHIVE_MYSQL_DB}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqlhost "${ARCHIVE_MYSQL_HOST}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf listen_addr 0.0.0.0 0

  php /etc/grommunio-archive/sphinx.conf.dist > /etc/sphinx/sphinx.conf
  sed -i -e "s/MYSQL_HOSTNAME/${ARCHIVE_MYSQL_HOST}/" -e "s/MYSQL_DATABASE/${ARCHIVE_MYSQL_DB}/" -e "s/MYSQL_PASSWORD/${ARCHIVE_MYSQL_PASS}/" -e "s/MYSQL_USERNAME/${ARCHIVE_MYSQL_USER}/" /etc/sphinx/sphinx.conf
  chown groarchive:sphinx /etc/sphinx/sphinx.conf
  chmod 644 /etc/sphinx/sphinx.conf
  chown groarchive:sphinx /var/lib/grommunio-archive/sphinx/ -R
  chmod 775 /var/lib/grommunio-archive/sphinx/
  sudo -u groarchive indexer --all

  < /dev/urandom head -c 56 > /etc/grommunio-archive/grommunio-archive.key

  #systemctl enable searchd.service grommunio-archive-smtp.service grommunio-archive.service postfix.service >>"${LOGFILE}" 2>&1
  #systemctl restart searchd.service grommunio-archive-smtp.service grommunio-archive.service postfix.service >>"${LOGFILE}" 2>&1
  
  systemctl enable searchd.service grommunio-archive-smtp.service grommunio-archive.service >>"${LOGFILE}" 2>&1
  systemctl restart searchd.service grommunio-archive-smtp.service grommunio-archive.service >>"${LOGFILE}" 2>&1

  #jq '.archiveWebAddress |= "https://'${FQDN}'/archive"' /tmp/config.json > /tmp/config-new.json
  #mv /tmp/config-new.json /tmp/config.json

fi
#mv /tmp/config.json /etc/grommunio-admin-common/config.json
systemctl enable nginx >>"${LOGFILE}" 2>&1
setup_done

exit 0
