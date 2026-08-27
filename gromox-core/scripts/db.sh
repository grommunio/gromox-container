#!/bin/sh
# Load variables from configuration file
. /home/vars/gromox_db.env

HAS_TABLES=$(mysql -u ${MARIADB_USER} -h ${MARIADB_HOST} -p"${MARIADB_PASSWORD}" -D ${MARIADB_DATABASE} --execute="SELECT CASE COUNT(*) WHEN '0' THEN 'false' ELSE 'true' END AS contents FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema = '${MARIADB_DATABASE}';")

echo "HAS_TABLES=$HAS_TABLES"  >>"$LOGFILE" 2>&1

rm -f /etc/gromox/mysql_adaptor.cfg
touch /etc/gromox/mysql_adaptor.cfg
echo "mysql_username=$MARIADB_USER" >> /etc/gromox/mysql_adaptor.cfg
echo "mysql_password=$MARIADB_PASSWORD" >> /etc/gromox/mysql_adaptor.cfg
echo "mysql_dbname=$MARIADB_DATABASE" >> /etc/gromox/mysql_adaptor.cfg
echo "mysql_host=$MARIADB_HOST" >> /etc/gromox/mysql_adaptor.cfg

if [[ $HAS_TABLES =~ "false" ]]; then
	echo 'Gromox DB is not populated, populating it...' >>"$LOGFILE" 2>&1
	gromox-dbop -C >>"$LOGFILE" 2>&1
elif [[ $CLEAR_DBS = true ]]; then
	echo 'Creating new gromox DB...' >>"$LOGFILE" 2>&1
	echo "${MARIADB_ROOT_PASSWORD}" > /home/gromox_root_pass 2>&1
    echo "drop database if exists ${MARIADB_DATABASE}; \
	drop user if exists ${MARIADB_USER}; \
	create user '${MARIADB_USER}'@'%' identified by '${MARIADB_PASSWORD}'; \
	    create database ${MARIADB_DATABASE}; grant all on ${MARIADB_DATABASE}.* to '${MARIADB_USER}'@'%' identified by '${MARIADB_PASSWORD}';" | mysql -h "${MARIADB_HOST}" -u root -p$(cat /home/gromox_root_pass) >>"$LOGFILE" 2>&1 
	rm /home/gromox_root_pass
	gromox-dbop -C >>"$LOGFILE" 2>&1
else
	echo 'Gromox DB is popoulated. Skipping' >>"$LOGFILE" 2>&1
fi

