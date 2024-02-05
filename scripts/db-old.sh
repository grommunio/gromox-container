#!/bin/sh
LOGFILE="/var/log/grommunio-setup.log"
MYSQL_HOST="localhost"
MYSQL_USER="grommunio"
MYSQL_PASS="Lu3s3WmFxXghtLwJnuqN"
MYSQL_DB="grommunio"

CHAT_ADMIN_PASS=grommunio
FILES_ADMIN_PASS=grommunio
ADMIN_PASS=grommunio

    if [ -n "${MYSQL_HOST}" ] && [ -n "${MYSQL_USER}" ] && [ -n "${MYSQL_PASS}" ] && [ -n "${MYSQL_DB}" ]; then
      echo "drop database if exists ${MYSQL_DB}; \
      	    create user '${MYSQL_USER}'@'${MYSQL_HOST}' identified by '${MYSQL_PASS}'; \
	     create database ${MYSQL_DB}; grant all on ${MYSQL_DB}.* to '${MYSQL_USER}'@'${MYSQL_HOST}' identified by '${MYSQL_PASS}';" | mysql >/dev/null 2>&1
    else
      failonme 1
    fi

CHAT_MYSQL_HOST="localhost"
  CHAT_MYSQL_USER="grochat"
  CHAT_MYSQL_PASS="grommunio"
  CHAT_MYSQL_DB="grochat"
  CHAT_CONFIG="/etc/grommunio-chat/config.json"

  if [ "${CHAT_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${CHAT_MYSQL_DB}; \
          create database ${CHAT_MYSQL_DB}; \
      	  create user '${CHAT_MYSQL_USER}'@'${CHAT_MYSQL_HOST}' identified by '${CHAT_MYSQL_PASS}'; \
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

FILES_MYSQL_HOST="localhost"
  FILES_MYSQL_USER="grofiles"
  FILES_MYSQL_PASS="grommunio"
  FILES_MYSQL_DB="grofiles"
  if [ "${FILES_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${FILES_MYSQL_DB}; \
          create database ${FILES_MYSQL_DB}; \
      	  create user '${FILES_MYSQL_USER}'@'${FILES_MYSQL_HOST}' identified by '${FILES_MYSQL_PASS}'; \
          grant all on ${FILES_MYSQL_DB}.* to '${FILES_MYSQL_USER}'@'${FILES_MYSQL_HOST}' identified by '${FILES_MYSQL_PASS}';" | mysql >/dev/null 2>&1
  else
    echo "drop database if exists ${FILES_MYSQL_DB}; \
          create database ${FILES_MYSQL_DB};" | mysql -h"${FILES_MYSQL_HOST}" -u"${FILES_MYSQL_USER}" -p"${FILES_MYSQL_PASS}" "${FILES_MYSQL_DB}" >/dev/null 2>&1
  fi

OFFICE_MYSQL_HOST="localhost"
  OFFICE_MYSQL_USER="groffice"
  OFFICE_MYSQL_PASS="grommunio"
  OFFICE_MYSQL_DB="groffice"
  if [ "${OFFICE_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${OFFICE_MYSQL_DB}; \
          create database ${OFFICE_MYSQL_DB}; \
          create user '${OFFICE_MYSQL_USER}'@'${OFFICE_MYSQL_HOST}' identified by '${OFFICE_MYSQL_PASS}'; \
          grant all on ${OFFICE_MYSQL_DB}.* to '${OFFICE_MYSQL_USER}'@'${OFFICE_MYSQL_HOST}' identified by '${OFFICE_MYSQL_PASS}';" | mysql >/dev/null 2>&1
  else
    echo "drop database if exists ${OFFICE_MYSQL_DB}; \
          create database ${OFFICE_MYSQL_DB};" | mysql -h"${OFFICE_MYSQL_HOST}" -u"${OFFICE_MYSQL_USER}" -p"${OFFICE_MYSQL_PASS}" "${OFFICE_MYSQL_DB}" >/dev/null 2>&1
  fi

  sed -i -e "/^CREATE DATABASE/d" -e "/^USE/d" /usr/libexec/grommunio-office/server/schema/mysql/createdb.sql
  mysql -h"${OFFICE_MYSQL_HOST}" -u"${OFFICE_MYSQL_USER}" -p"${OFFICE_MYSQL_PASS}" "${OFFICE_MYSQL_DB}" < /usr/libexec/grommunio-office/server/schema/mysql/createdb.sql

  jq '.services.CoAuthoring.sql.dbHost |= "'${OFFICE_MYSQL_HOST}'" | .services.CoAuthoring.sql.dbName |= "'${OFFICE_MYSQL_DB}'" | .services.CoAuthoring.sql.dbUser |= "'${OFFICE_MYSQL_USER}'" | .services.CoAuthoring.sql.dbPass |= "'${OFFICE_MYSQL_PASS}'"' /etc/grommunio-office/default.json > /tmp/default.json
  mv /tmp/default.json /etc/grommunio-office/default.json

  ARCHIVE_MYSQL_HOST="localhost"
  ARCHIVE_MYSQL_USER="groarchive"
  ARCHIVE_MYSQL_PASS="grommunio"
  ARCHIVE_MYSQL_DB="groarchive"

  if [ "${ARCHIVE_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${ARCHIVE_MYSQL_DB}; \
          create database ${ARCHIVE_MYSQL_DB}; \
          create user '${ARCHIVE_MYSQL_USER}'@'${ARCHIVE_MYSQL_HOST}' identified by '${ARCHIVE_MYSQL_PASS}'; \
          grant all on ${ARCHIVE_MYSQL_DB}.* to '${ARCHIVE_MYSQL_USER}'@'${ARCHIVE_MYSQL_HOST}' identified by '${ARCHIVE_MYSQL_PASS}';" | mysql >/dev/null 2>&1
  else
    echo "drop database if exists ${ARCHIVE_MYSQL_DB}; \
          create database ${ARCHIVE_MYSQL_DB};" | mysql -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" -p"${ARCHIVE_MYSQL_PASS}" "${ARCHIVE_MYSQL_DB}" >/dev/null 2>&1
  fi

  mysql -h"${ARCHIVE_MYSQL_HOST}" -u"${ARCHIVE_MYSQL_USER}" -p"${ARCHIVE_MYSQL_PASS}" "${ARCHIVE_MYSQL_DB}" < /usr/share/grommunio-archive/db-mysql.sql

  sed -e "s#MYHOSTNAME#${FQDN}#g" -e "s#MYSMTP#${DOMAIN}#g" -e "s/MYSQL_HOSTNAME/${ARCHIVE_MYSQL_HOST}/" -e "s/MYSQL_DATABASE/${ARCHIVE_MYSQL_DB}/" -e "s/MYSQL_PASSWORD/${ARCHIVE_MYSQL_PASS}/" -e "s/MYSQL_USERNAME/${ARCHIVE_MYSQL_USER}/" /etc/grommunio-archive/config-site.dist.php > /etc/grommunio-archive/config-site.php

 mv /etc/grommunio-archive/grommunio-archive.conf.dist /etc/grommunio-archive/grommunio-archive.conf
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqluser "${ARCHIVE_MYSQL_USER}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqlpwd "${ARCHIVE_MYSQL_PASS}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf mysqldb "${ARCHIVE_MYSQL_DB}" 0
  setconf /etc/grommunio-archive/grommunio-archive.conf listen_addr 0.0.0.0 0
  sed -i -e "s/MYSQL_HOSTNAME/${ARCHIVE_MYSQL_HOST}/" -e "s/MYSQL_DATABASE/${ARCHIVE_MYSQL_DB}/" -e "s/MYSQL_PASSWORD/${ARCHIVE_MYSQL_PASS}/" -e "s/MYSQL_USERNAME/${ARCHIVE_MYSQL_USER}/" /etc/sphinx/sphinx.conf
  chown groarchive:sphinx /etc/sphinx/sphinx.conf

  gromox-dbop -C >>"${LOGFILE}" 2>&1
  grommunio-admin passwd --password "${ADMIN_PASS}" >>"${LOGFILE}" 2>&1
