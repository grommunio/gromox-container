OFFICE_MYSQL_HOST="localhost"
  OFFICE_MYSQL_USER="groffice"
  OFFICE_MYSQL_PASS=grommunio
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