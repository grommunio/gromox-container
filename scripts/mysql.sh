MYSQL_HOST="localhost"
MYSQL_USER="grommunio"
MYSQL_PASS=Lu3s3WmFxXghtLwJnuqN
MYSQL_DB="grommunio"

CHAT_ADMIN_PASS=
FILES_ADMIN_PASS=
ADMIN_PASS=

CHAT_MYSQL_HOST=$(sed -n '1{p;q}' "${TMPF}")
CHAT_MYSQL_USER=$(sed -n '2{p;q}' "${TMPF}")
CHAT_MYSQL_PASS=$(sed -n '3{p;q}' "${TMPF}")
CHAT_MYSQL_DB=$(sed -n '4{p;q}' "${TMPF}")

FILES_MYSQL_HOST=$(sed -n '1{p;q}' "${TMPF}")
FILES_MYSQL_USER=$(sed -n '2{p;q}' "${TMPF}")
FILES_MYSQL_PASS=$(sed -n '3{p;q}' "${TMPF}")
FILES_MYSQL_DB=$(sed -n '4{p;q}' "${TMPF}")

ARCHIVE_MYSQL_HOST=$(sed -n '1{p;q}' "${TMPF}")
ARCHIVE_MYSQL_USER=$(sed -n '2{p;q}' "${TMPF}")
ARCHIVE_MYSQL_PASS=$(sed -n '3{p;q}' "${TMPF}")
ARCHIVE_MYSQL_DB=$(sed -n '4{p;q}' "${TMPF}")

OFFICE_MYSQL_HOST=$(sed -n '1{p;q}' "${TMPF}")
OFFICE_MYSQL_USER=$(sed -n '2{p;q}' "${TMPF}")
OFFICE_MYSQL_PASS=$(sed -n '3{p;q}' "${TMPF}")
OFFICE_MYSQL_DB=$(sed -n '4{p;q}' "${TMPF}")

    if [ -n "${MYSQL_HOST}" ] && [ -n "${MYSQL_USER}" ] && [ -n "${MYSQL_PASS}" ] && [ -n "${MYSQL_DB}" ]; then
      echo "drop database if exists ${MYSQL_DB}; create database ${MYSQL_DB}; grant all on ${MYSQL_DB}.* to '${MYSQL_USER}'@'${MYSQL_HOST}' identified by '${MYSQL_PASS}';" | mysql >/dev/null 2>&1
    else
      failonme 1
    fi
  done
fi