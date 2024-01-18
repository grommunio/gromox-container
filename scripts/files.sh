FILES_MYSQL_HOST="localhost"
  FILES_MYSQL_USER="grofiles"
  FILES_MYSQL_PASS=grommunio
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