CHAT_MYSQL_HOST="localhost"
  CHAT_MYSQL_USER="grochat"
  CHAT_MYSQL_PASS=grommunio
  CHAT_MYSQL_DB="grochat"
  CHAT_CONFIG="/etc/grommunio-chat/config.json"

  if [ "${CHAT_MYSQL_HOST}" == "localhost" ] ; then
    echo "drop database if exists ${CHAT_MYSQL_DB}; \
          create database ${CHAT_MYSQL_DB}; \
          grant all on ${CHAT_MYSQL_DB}.* to '${CHAT_MYSQL_USER}'@'${CHAT_MYSQL_HOST}' identified by '${CHAT_MYSQL_PASS}';" | mysql >/dev/null 2>&1
  else
    echo "drop database if exists ${CHAT_MYSQL_DB}; \
          create database ${CHAT_MYSQL_DB};" | mysql -h"${CHAT_MYSQL_HOST}" -u"${CHAT_MYSQL_USER}" -p"${CHAT_MYSQL_PASS}" "${CHAT_MYSQL_DB}" >/dev/null 2>&1
  fi