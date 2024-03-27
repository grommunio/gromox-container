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
INSTALLVALUE="archive"

X500="i$(printf "%llx" "$(date +%s)")"
#Choose Install type, 0 for self signed, 2 to provide certificate and 3 for letsencrypt.
#SSL_INSTALL_TYPE=0

#SSL_COUNTRY="XX"
#SSL_STATE="XX"
#SSL_LOCALITY="X"
#SSL_ORG="grommunio Appliance"
#SSL_OU="IT"
#SSL_EMAIL="admin@${DOMAIN}"
#SSL_DAYS=30
#SSL_PASS=grommunio

. "/home/common/ssl_setup"
RETCMD=1
if [ "${SSL_INSTALL_TYPE}" = "0" ]; then
  clear
  if ! selfcert; then
  touch ssle
  fi

writelog "Config stage: put php files into place"
if [ -d /etc/php8 ]; then
  if [ -e "/etc/php8/fpm/php-fpm.conf.default" ] ; then
    mv /etc/php8/fpm/php-fpm.conf.default /etc/php8/fpm/php-fpm.conf
  fi
elif [ -d /etc/php7 ]; then
  if [ -e "/etc/php7/fpm/php-fpm.conf.default" ] ; then
    mv /etc/php7/fpm/php-fpm.conf.default /etc/php7/fpm/php-fpm.conf
  fi
fi

systemctl enable firewalld.service >>"${LOGFILE}" 2>&1
systemctl start firewalld.service >>"${LOGFILE}" 2>&1

. "/home/scripts/firewall.sh"

systemctl restart saslauthd.service >>"${LOGFILE}" 2>&1

cp /home/config/certificate.conf /etc/grommunio-common/nginx/ssl_certificate.conf 
chown gromox:gromox /etc/grommunio-common/ssl/*

if [[ $INSTALLVALUE == *"archive"* ]] ; then

    echo "drop database if exists ${ARCHIVE_MYSQL_DB}; \
          create database ${ARCHIVE_MYSQL_DB};" | mysql -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" -p"${ARCHIVE_MYSQL_PASS}" "${ARCHIVE_MYSQL_DB}" >/dev/null 2>&1

  mysql -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" -p"${ARCHIVE_MYSQL_PASS}" "${ARCHIVE_MYSQL_DB}" < /usr/share/grommunio-archive/db-mysql.sql

  sed -e "s#MYHOSTNAME#${FQDN}#g" -e "s#MYSMTP#${DOMAIN}#g" -e "s/MYSQL_HOSTNAME/${ARCHIVE_MYSQL_HOST}/" -e "s/MYSQL_DATABASE/${ARCHIVE_MYSQL_DB}/" -e "s/MYSQL_PASSWORD/${ARCHIVE_MYSQL_PASS}/" -e "s/MYSQL_USERNAME/${ARCHIVE_MYSQL_USER}/" /etc/grommunio-archive/config-site.dist.php > /etc/grommunio-archive/config-site.php

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

  systemctl enable searchd.service grommunio-archive-smtp.service grommunio-archive.service >>"${LOGFILE}" 2>&1
  systemctl restart searchd.service grommunio-archive-smtp.service grommunio-archive.service >>"${LOGFILE}" 2>&1

fi
systemctl enable nginx.service php-fpm.service >>"${LOGFILE}" 2>&1
systemctl start nginx.service php-fpm.service >>"${LOGFILE}" 2>&1
setup_done

exit 0
