MYSQL_HOST="localhost"
MYSQL_USER="grommunio"
MYSQL_PASS=$(randpw)
MYSQL_DB="grommunio"

set_mysql_param(){

  writelog "Dialog: mysql configuration"
  dialog --no-mouse --colors --backtitle "grommunio Setup" --title "MariaDB/MySQL database credentials" --ok-label "Submit" \
         --form "Enter the database credentials." 0 0 0   \
         "Host:    " 1 1 "${MYSQL_HOST}"         1 17 25 0 \
         "User:    " 2 1 "${MYSQL_USER}"         2 17 25 0 \
         "Password:" 3 1 "${MYSQL_PASS}"         3 17 25 0 \
         "Database:" 4 1 "${MYSQL_DB}"           4 17 25 0 2>"${TMPF}"
  dialog_exit $?

}

writelog "Dialog: mysql installation type"
MYSQL_INSTALL_TYPE=$(dialog --no-mouse --colors --backtitle "grommunio Setup" --title "grommunio Setup: Database" \
                           --menu "Choose database setup type" 0 0 0 \
                           "1" "Create database locally (default)" \
                           "2" "Connect to existing database (advanced users)" 3>&1 1>&2 2>&3)
dialog_exit $?

writelog "Selected MySQL installation type: ${MYSQL_INSTALL_TYPE}"

RETCMD=1
if [ "${MYSQL_INSTALL_TYPE}" = "2" ]; then
  while [ ${RETCMD} -ne 0 ]; do
    set_mysql_param "Existing database"
    MYSQL_HOST=$(sed -n '1{p;q}' "${TMPF}")
    MYSQL_USER=$(sed -n '2{p;q}' "${TMPF}")
    MYSQL_PASS=$(sed -n '3{p;q}' "${TMPF}")
    MYSQL_DB=$(sed -n '4{p;q}' "${TMPF}")
    if [ -n "${MYSQL_HOST}" ] && [ -n "${MYSQL_USER}" ] && [ -z "${MYSQL_PASS}" ] && [ -n "${MYSQL_DB}" ]; then
      echo "show tables;" | mysql -h"${MYSQL_HOST}" -u"${MYSQL_USER}" "${MYSQL_DB}" >/dev/null 2>&1
      writelog "mysql -h${MYSQL_HOST} -u${MYSQL_USER} ${MYSQL_DB}"
    elif [ -n "${MYSQL_HOST}" ] && [ -n "${MYSQL_USER}" ] && [ -n "${MYSQL_PASS}" ] && [ -n "${MYSQL_DB}" ]; then
      echo "show tables;" | mysql -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "${MYSQL_DB}" >/dev/null 2>&1
      writelog "mysql -h${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB}"
    else
      failonme 1
    fi
    RETCMD=$?
    if [ ${RETCMD} -ne 0 ]; then
      dialog --no-mouse --clear --colors --backtitle "grommunio Setup" --title "MySQL database credentials" --msgbox 'No connection could be established with the database using the provided credentials. Verify that the credentials are correct and that a connection to the database is possible from this system.' 0 0
      dialog_exit $?
    fi
  done
else
  while [ ${RETCMD} -ne 0 ]; do
    set_mysql_param "Create database"
    MYSQL_HOST=$(sed -n '1{p;q}' "${TMPF}")
    MYSQL_USER=$(sed -n '2{p;q}' "${TMPF}")
    MYSQL_PASS=$(sed -n '3{p;q}' "${TMPF}")
    MYSQL_DB=$(sed -n '4{p;q}' "${TMPF}")
    if [ -n "${MYSQL_HOST}" ] && [ -n "${MYSQL_USER}" ] && [ -n "${MYSQL_PASS}" ] && [ -n "${MYSQL_DB}" ]; then
      echo "drop database if exists ${MYSQL_DB}; create database ${MYSQL_DB}; grant all on ${MYSQL_DB}.* to '${MYSQL_USER}'@'${MYSQL_HOST}' identified by '${MYSQL_PASS}';" | mysql >/dev/null 2>&1
    else
      failonme 1
    fi
    RETCMD=$?
    if [ ${RETCMD} -ne 0 ]; then
      dialog --no-mouse --clear --colors --backtitle "grommunio Setup" --title "MySQL connection failed" --msgbox 'Could not set up the database. Make sure it is reachable and re-run the creation process.' 0 0
      dialog_exit $?
    fi
  done
fi