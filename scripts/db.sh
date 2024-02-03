#!/bin/sh

HAS_TABLES=$(mysql -u ${MYSQL_USER} -h ${MYSQL_HOST} -p"${MYSQL_PASS}" -D ${MYSQL_DB} --execute="SELECT CASE COUNT(*) WHEN '0' THEN 'false' ELSE 'true' END AS contents FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema = '${MYSQL_DB}';")


if [[ $HAS_TABLES =~ "false" ]]; then
	echo 'Gromox DB is not populated, populating it...' >>"${LOGFILE}" 2>&1
	
	#Configure gromox to speak to the DB
	touch /etc/gromox/mysql_adaptor.cfg
	echo 'mysql_username="${MYSQL_USER}"' >> /etc/gromox/mysql_adaptor.cfg
	echo 'mysql_password="${MYSQL_PASS}"' >> /etc/gromox/mysql_adaptor.cfg
	echo 'mysql_dbname="${MYSQL_DB}"' >> /etc/gromox/mysql_adaptor.cfg
	echo 'mysql_host="${MYSQL_HOST}"' >> /etc/gromox/mysql_adaptor.cfg

	gromox-dbop -C >>"${LOGFILE}" 2>&1
elif [[ $CLEAR_DBS -eq 1 ]]; then
	echo 'Creating new gromox DB...' >>"${LOGFILE}" 2>&1
	echo "${MYSQL_ROOT_PASS}" > /home/gromox_root_pass 2>&1
      echo "drop database if exists ${MYSQL_DB}; \
      	    create user '${MYSQL_USER}'@'${MYSQL_HOST}' identified by '${MYSQL_PASS}'; \
	    create database ${MYSQL_DB}; grant all on ${MYSQL_DB}.* to '${MYSQL_USER}'@'${MYSQL_HOST}' identified by '${MYSQL_PASS}';" | mysql -h "${MYSQL_HOST}" -u root -p$(cat /home/gromox_root_pass) >>"${LOGFILE}" 2>&1 
else
	echo 'Gromox DB is popoulated. Skipping' >>"${LOGFILE}" 2>&1
fi

