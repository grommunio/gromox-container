ARCHIVE_MYSQL_HOST="localhost"
  ARCHIVE_MYSQL_USER="groarchive"
  ARCHIVE_MYSQL_PASS=grommunio
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