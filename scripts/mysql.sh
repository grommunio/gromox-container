MYSQL_HOST="localhost"
MYSQL_USER="grommunio"
MYSQL_PASS=Lu3s3WmFxXghtLwJnuqN
MYSQL_DB="grommunio"

CHAT_ADMIN_PASS=grommunio
FILES_ADMIN_PASS=grommunio
ADMIN_PASS=grommunio

    if [ -n "${MYSQL_HOST}" ] && [ -n "${MYSQL_USER}" ] && [ -n "${MYSQL_PASS}" ] && [ -n "${MYSQL_DB}" ]; then
      echo "drop database if exists ${MYSQL_DB}; create database ${MYSQL_DB}; grant all on ${MYSQL_DB}.* to '${MYSQL_USER}'@'${MYSQL_HOST}' identified by '${MYSQL_PASS}';" | mysql >/dev/null 2>&1
    else
      failonme 1
    fi